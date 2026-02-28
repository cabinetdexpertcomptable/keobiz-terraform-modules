# ============================================
# Outputs
# ============================================

output "functions" {
  description = "Map of deployed Lambda functions"
  value = {
    for name, _ in var.functions : name => {
      function_name    = module.lambda[name].function_name
      function_arn     = module.lambda[name].function_arn
      log_group        = module.lambda[name].log_group_name
      api_gateway_url  = module.lambda[name].api_gateway_url
    }
  }
}

output "sqs_queues" {
  description = "SQS queue URLs for functions with SQS enabled"
  value = {
    for name, config in var.functions : name => {
      queue_url = aws_sqs_queue.function_queue[name].url
      dlq_url   = aws_sqs_queue.function_dlq[name].url
    } if config.enable_sqs
  }
}

output "schedules" {
  description = "EventBridge schedules"
  value = {
    for k, v in local.enabled_schedules : k => {
      arn        = aws_scheduler_schedule.function_schedule[k].arn
      expression = v.expression
    }
  }
}

# Convenience outputs
output "api_urls" {
  description = "API Gateway URLs for functions with API enabled"
  value = {
    for name, config in var.functions : name => module.lambda[name].api_gateway_url
    if config.enable_api_gateway
  }
}

