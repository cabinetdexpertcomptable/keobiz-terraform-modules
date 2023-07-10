data "aws_iam_role" "autoscale" {
  name = "AWSServiceRoleForApplicationAutoScaling_ECSService"
}

resource "aws_appautoscaling_target" "ecs_service" {
  count      = var.enable_autoscale ? 1 : 0
  depends_on = [aws_ecs_service.service]

  max_capacity = var.autoscale_max_tasks
  min_capacity = var.autoscale_min_tasks
  resource_id        = "service/${local.cluster_name}/${var.service_name}"
  role_arn           = data.aws_iam_role.autoscale.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  count = var.enable_autoscale ? 1 : 0

  name               = "track-cpu-${var.service_name}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.autoscale_cpu_target

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
