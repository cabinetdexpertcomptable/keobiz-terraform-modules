# ============================================
# EventBridge Scheduler
# ============================================
# Creates a schedule to invoke the Lambda function at specified intervals
# Supports: rate(), cron(), and at() expressions
# ============================================

# IAM Role for EventBridge Scheduler
resource "aws_iam_role" "scheduler" {
  count = var.enable_scheduling ? 1 : 0

  name = "${local.function_name}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  count = var.enable_scheduling ? 1 : 0

  name = "invoke-lambda"
  role = aws_iam_role.scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = [
        aws_lambda_function.this.arn,
        "${aws_lambda_function.this.arn}:*"
      ]
    }]
  })
}

# EventBridge Schedule
resource "aws_scheduler_schedule" "this" {
  count = var.enable_scheduling ? 1 : 0

  name        = "${local.function_name}-schedule"
  group_name  = "default"
  description = "Schedule for ${local.function_name}"

  flexible_time_window {
    mode                      = var.schedule_flexible_window > 0 ? "FLEXIBLE" : "OFF"
    maximum_window_in_minutes = var.schedule_flexible_window > 0 ? var.schedule_flexible_window : null
  }

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.scheduler[0].arn

    input = var.schedule_input

    retry_policy {
      maximum_retry_attempts       = 3
      maximum_event_age_in_seconds = 3600
    }
  }
}

# ============================================
# Alternative: CloudWatch Event Rule (Legacy)
# ============================================
# Uncomment if you prefer CloudWatch Events over EventBridge Scheduler
# Note: EventBridge Scheduler is recommended for new projects
#
# resource "aws_cloudwatch_event_rule" "this" {
#   count = var.enable_scheduling ? 1 : 0
#
#   name                = "${local.function_name}-rule"
#   description         = "Schedule for ${local.function_name}"
#   schedule_expression = var.schedule_expression
#
#   tags = var.tags
# }
#
# resource "aws_cloudwatch_event_target" "this" {
#   count = var.enable_scheduling ? 1 : 0
#
#   rule      = aws_cloudwatch_event_rule.this[0].name
#   target_id = "invoke-lambda"
#   arn       = aws_lambda_function.this.arn
#   input     = var.schedule_input
# }
#
# resource "aws_lambda_permission" "eventbridge" {
#   count = var.enable_scheduling ? 1 : 0
#
#   statement_id  = "AllowEventBridgeInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.this.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.this[0].arn
# }

