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

data "aws_iam_role" "ecs_task_execution_role" {
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
    var.logs == "cloudwatch" ?
    {
      logDriver : "awslogs",
      options : {
        awslogs-group : aws_cloudwatch_log_group.service_log.name,
        awslogs-region : "eu-central-1",
        awslogs-stream-prefix : "ecs"
      }
    } :
    {
      logDriver : "awsfirelens",
      options : {
        Name : "datadog",
        apikey : var.datadog_api_key,
        Host : "http-intake.logs.datadoghq.eu",
        TLS : "on",
        provider : "ecs",
        dd_service : var.service_name,
        dd_source : var.datadog_log_source,
        dd_message_key : "log",
        dd_tags : join(",", [for k, v in var.tags : format("%s:%s", k, v)])
      }
    }
  )

  firelensOptions = (
    var.logs_json ?
    {
      enable-ecs-log-metadata : "true", # must be string
      config-file-type : "file",
      config-file-value : "/fluent-bit/configs/parse-json.conf"
    } :
    {
      enable-ecs-log-metadata : "true" # must be string
    }
  )

  fluentbit_task = (
    var.logs == "cloudwatch" ?
    [] :
    [{
      essential : true,
      image : "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable",
      name : "log_router",
      firelensConfiguration : {
        type : "fluentbit",
        options : local.firelensOptions
      },
      // below are defaults to avoid updating resources for nothing 
      mountPoints  = [],
      portMappings = [],
      volumesFrom  = [],
      environment  = [],
      user         = "0",
      cpu          = 0
    }]
  )

  datadog_agent_task = (
    var.enable_datadog_agent ?
    [{
      name : "datadog-agent",
      image : var.datadog_agent_image_tag,
      memory : 256,
      cpu : 0,
      environment : [
        { name : "DD_API_KEY", value : var.datadog_api_key },
        { name : "DD_SITE", value : "datadoghq.eu" },
        { name : "ECS_FARGATE", value : "true" },
        { name : "DD_TAGS", value : join(" ", [for k, v in var.tags : format("%s:%s", k, v)]) },
        { name : "DD_APM_ENABLED", value : tostring(var.enable_datadog_agent_apm) },
        { name : "DD_APM_IGNORE_RESOURCES", value : join(",", var.datadog_apm_ignore_ressources) },
        { name : "DD_APM_NON_LOCAL_TRAFFIC", value : tostring(var.enable_datadog_non_local_apm) },
        { name : "DD_ENV", value : lower(terraform.workspace) },
        { name : "DD_LOGS_INJECTION", value : tostring(var.enable_datadog_logs_injection) },
        { name : "DD_SERVICE", value : var.service_name }
      ],
      logConfiguration : var.collect_datadog_agent_logs ? {
        logDriver : "awsfirelens",
        options : {
          Name : "datadog",
          apikey : var.datadog_api_key,
          Host : "http-intake.logs.datadoghq.eu",
          TLS : "on",
          provider : "ecs",
          dd_service : var.service_name,
          dd_source : var.datadog_source,
          dd_message_key : "log",
          dd_tags : join(",", [for k, v in var.tags : format("%s:%s", k, v)])
        }
      } : null
    }] :
    []
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
  name                = "${var.service_name}-${terraform.workspace}-task-execution-role"
  assume_role_policy  = file("${path.module}/policies/assume/ecs-tasks.json")
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

# resource "aws_iam_role_policy" "read-task-secrets" {
#   name   = "${var.service_name}-${terraform.workspace}-secrets"
#   role   = aws_iam_role.execution_role.id
#   policy = templatefile("${path.module}/policies/read-task-secrets.tftpl", { region : local.region, account_id : local.account_id, ssm_parameters : values(var.secrets) })
# }

# task definition
resource "aws_ecs_task_definition" "task" {
  family                   = "${var.service_name}-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = "${data.aws_iam_role.ecs_task_execution_role.arn}"
  task_role_arn            = "arn:aws:iam::931338600976:role/test-role-ecs"

  cpu    = var.cpu
  memory = var.mem

  container_definitions = jsonencode(
    flatten(
      [local.main_task, local.fluentbit_task, local.datadog_agent_task]
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
      var.additional_security_groups[*]
    )
    subnets = var.task_subnets
  }

  health_check_grace_period_seconds =  var.healthcheck_grace_period

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.target-group-lb.arn
    container_name   = var.service_name
    container_port   = var.port
  }

  propagate_tags = "SERVICE"
  tags           = var.tags
}


resource "aws_service_discovery_service" "name" {
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
