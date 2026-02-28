# ============================================
# Dynamic EventBridge Schedules
# ============================================
# Creates schedules based on the schedules array
# in each function's config.json
# ============================================

locals {
  # Flatten all schedules from all functions into a single map
  all_schedules = merge([
    for func_name, config in var.functions : {
      for schedule in config.schedules : "${func_name}-${schedule.name}" => {
        function_name = func_name
        schedule_name = schedule.name
        description   = schedule.description
        expression    = schedule.expression
        input         = schedule.input
        enabled       = try(schedule.enabled[terraform.workspace], true)
      }
    } if config.enable_scheduling
  ]...)
  
  # Filter to only enabled schedules
  enabled_schedules = { for k, v in local.all_schedules : k => v if v.enabled }
}

# IAM Role for Scheduler
resource "aws_iam_role" "scheduler" {
  count = length(local.enabled_schedules) > 0 ? 1 : 0

  name = "${local.project_name}-scheduler-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  count = length(local.enabled_schedules) > 0 ? 1 : 0

  name = "invoke-lambdas"
  role = aws_iam_role.scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = [for name, config in var.functions : module.lambda[name].function_arn if config.enable_scheduling]
    }]
  })
}

# Create schedules
resource "aws_scheduler_schedule" "function_schedule" {
  for_each = local.enabled_schedules

  name        = "${local.project_name}-${each.key}-${terraform.workspace}"
  group_name  = "default"
  description = each.value.description

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = each.value.expression
  schedule_expression_timezone = "Europe/Paris"

  target {
    arn      = module.lambda[each.value.function_name].function_arn
    role_arn = aws_iam_role.scheduler[0].arn
    input    = jsonencode(each.value.input)

    retry_policy {
      maximum_retry_attempts       = 3
      maximum_event_age_in_seconds = 3600
    }
  }
}

