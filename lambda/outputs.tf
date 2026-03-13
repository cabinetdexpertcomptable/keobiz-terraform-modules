# ============================================
# Lambda Function Outputs
# ============================================

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN to be used for invoking Lambda from API Gateway"
  value       = aws_lambda_function.this.invoke_arn
}

output "function_version" {
  description = "Latest published version of the Lambda function"
  value       = aws_lambda_function.this.version
}

output "qualified_arn" {
  description = "Qualified ARN (includes version)"
  value       = aws_lambda_function.this.qualified_arn
}

# ============================================
# IAM Outputs
# ============================================

output "role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda.name
}

# ============================================
# CloudWatch Outputs
# ============================================

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

# ============================================
# Alias Outputs (conditional)
# ============================================

output "alias_arn" {
  description = "ARN of the Lambda alias (if created)"
  value       = var.create_alias ? aws_lambda_alias.this[0].arn : null
}

output "alias_invoke_arn" {
  description = "Invoke ARN of the Lambda alias (if created)"
  value       = var.create_alias ? aws_lambda_alias.this[0].invoke_arn : null
}

# ============================================
# API Gateway Outputs (conditional)
# ============================================

output "api_gateway_url" {
  description = "URL of the API Gateway endpoint (if created)"
  value       = var.enable_api_gateway ? aws_apigatewayv2_stage.this[0].invoke_url : null
}

output "api_gateway_id" {
  description = "ID of the API Gateway (if created)"
  value       = var.enable_api_gateway ? aws_apigatewayv2_api.this[0].id : null
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway (if created)"
  value       = var.enable_api_gateway ? aws_apigatewayv2_api.this[0].execution_arn : null
}

# ============================================
# EventBridge Scheduler Outputs (conditional)
# ============================================

output "schedule_arn" {
  description = "ARN of the EventBridge schedule (if created)"
  value       = var.enable_scheduling ? aws_scheduler_schedule.this[0].arn : null
}

output "schedule_name" {
  description = "Name of the EventBridge schedule (if created)"
  value       = var.enable_scheduling ? aws_scheduler_schedule.this[0].name : null
}

