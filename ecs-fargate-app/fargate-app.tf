locals {
  # ecs_cluster_id is in arn format
  cluster_name         = reverse(split("/", var.ecs_cluster_id))[0]
  account_id           = data.aws_caller_identity.current.account_id
  region               = data.aws_region.current.name
  needs_execution_role = (length(var.secrets) > 0 ? true : false)
}

resource "aws_cloudwatch_log_group" "service_log" {
  name              = "/ecs/${local.cluster_name}/${var.service_name}_task"
  retention_in_days = 5
  tags              = var.tags
}

data "aws_iam_role" "ecs_role" {
  name = "ecsTaskExecutionRole"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {

  mappings = var.ports == [] ? (var.port == 0 ? [] : [var.port]) : var.ports

  main_task = [{
    essential : true,
    cpu : 0,
    image : var.image,
    name : var.service_name,
    networkMode : "awsvpc",
    mountPoints : [],
    ulimits : (
      var.docker_ulimits == [] ?
      null :
      var.docker_ulimits
    ),
    portMappings : [
      for p in local.mappings : { containerPort : p, hostPort : p, protocol : "tcp" }
    ],
    command : var.command,
    environment : [
      for k, v in var.env_vars : { name : k, value : v }
    ],
    secrets : [
      for env_var, ssm_path in var.secrets : { name : env_var, valueFrom : format("arn:aws:ssm:%s:%s:parameter%s", local.region, local.account_id, ssm_path) }
    ],
    logConfiguration : local.logConf
  }]

  logConf = (
    {
      logDriver : "awslogs",
      options : {
        awslogs-group : aws_cloudwatch_log_group.service_log[0].name,
        awslogs-region : "eu-central-1",
        awslogs-stream-prefix : "ecs"
      }
    }
  )
}

resource "aws_iam_role" "task_role" {
  name               = "${var.service_name}-${terraform.workspace}"
  assume_role_policy = file("${path.module}/policies/assume/ecs-tasks.json")
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "custom_policy" {
  # The "for_each" value depends on resource attributes that cannot be determined until apply,
  # so Terraform cannot predict how many instances will be created.
  # To work around this, use the -target argument to first apply only the resources that the for_each depends on.
  for_each   = toset(var.task_role_policies_arn)
  role       = aws_iam_role.task_role.name
  policy_arn = each.value
}

resource "aws_iam_role" "execution_role" {
  count               = (local.needs_execution_role ? 1 : 0)
  name                = "${var.service_name}-${terraform.workspace}-task-execution-role"
  assume_role_policy  = file("${path.module}/policies/assume/ecs-tasks.json")
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

resource "aws_iam_role_policy" "read-task-secrets" {
  count  = (length(var.secrets) > 0 ? 1 : 0)
  name   = "${var.service_name}-${terraform.workspace}-secrets"
  role   = aws_iam_role.execution_role[0].id
  policy = templatefile("${path.module}/policies/read-task-secrets.tftpl", { region : local.region, account_id : local.account_id, ssm_parameters : values(var.secrets) })
}

# task definition
resource "aws_ecs_task_definition" "task" {
  depends_on = [aws_security_group.lb_to_service] # via ENI

  family                   = "${var.service_name}-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = local.needs_execution_role ? aws_iam_role.execution_role[0].arn : data.aws_iam_role.ecs_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  cpu    = var.cpu
  memory = var.mem

  container_definitions = jsonencode(
    flatten(
      [local.main_task]
    )
  )

  tags = var.tags
}

# service definition
resource "aws_ecs_service" "service" {
  count            = var.task_definition_only == true ? 0 : 1
  name             = var.service_name
  cluster          = var.ecs_cluster_id
  task_definition  = aws_ecs_task_definition.task.arn
  desired_count    = var.desired_tasks
  launch_type      = "FARGATE"
  platform_version = var.platform_version

  network_configuration {
    security_groups = concat(
      aws_security_group.lb_to_service[*].id,
      aws_security_group.lb_priv_to_service[*].id,
      var.additional_security_groups[*]
    )
    subnets = var.task_subnets
  }

  health_check_grace_period_seconds = (var.enable_public_lb || var.enable_private_lb) ? var.healthcheck_grace_period : null

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }

  propagate_tags = "APP"
  tags           = var.tags
}


resource "aws_service_discovery_service" "name" {
  count = var.enable_local_discovery ? 1 : 0
  name  = var.local_discovery_service_name

  dns_config {
    namespace_id = var.discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    # reuse lb healtch check path & co. cf https://www.terraform.io/docs/providers/aws/r/service_discovery_service.html#health_check_config-1
    failure_threshold = 1
  }
}

resource "aws_alb_target_group" "target-group-lb" {
  name_prefix = "task-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.healthcheck_path
    interval            = var.healthcheck_interval
    timeout             = var.healthcheck_timeout
    matcher             = var.healthcheck_matcher
    unhealthy_threshold = var.healthcheck_unhealthy_threshold
  }

  deregistration_delay = var.deregistration_delay
}
