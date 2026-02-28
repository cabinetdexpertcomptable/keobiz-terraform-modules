# ============================================
# HTTP API Gateway
# ============================================
# Creates an HTTP API Gateway to expose the Lambda function
# HTTP API is simpler and cheaper than REST API
# ============================================

# HTTP API
resource "aws_apigatewayv2_api" "this" {
  count = var.enable_api_gateway ? 1 : 0

  name          = "${local.function_name}-api"
  protocol_type = "HTTP"
  description   = "HTTP API for ${local.function_name}"

  cors_configuration {
    allow_origins     = var.api_gateway_cors_origins
    allow_methods     = var.api_gateway_cors_methods
    allow_headers     = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
    expose_headers    = ["Content-Type"]
    allow_credentials = false
    max_age           = 300
  }

  tags = var.tags
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "this" {
  count = var.enable_api_gateway ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "this" {
  count = var.enable_api_gateway ? length(var.api_gateway_routes) : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "${var.api_gateway_routes[count.index].method} ${var.api_gateway_routes[count.index].path}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"

  authorization_type = var.api_gateway_authorization
  authorizer_id      = var.api_gateway_authorization != "NONE" ? var.api_gateway_authorizer_id : null
}

# Stage (auto-deploy)
resource "aws_apigatewayv2_stage" "this" {
  count = var.enable_api_gateway ? 1 : 0

  api_id      = aws_apigatewayv2_api.this[0].id
  name        = terraform.workspace
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway[0].arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      path             = "$context.path"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      latency          = "$context.responseLatency"
    })
  }

  tags = var.tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  count = var.enable_api_gateway ? 1 : 0

  name              = "/aws/apigateway/${local.function_name}-api"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  count = var.enable_api_gateway ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this[0].execution_arn}/*/*"
}

# ============================================
# Optional: Custom Domain
# ============================================
# Uncomment and configure if you need a custom domain
#
# variable "custom_domain" {
#   description = "Custom domain for the API (e.g., api.mycompany.com)"
#   type        = string
#   default     = null
# }
#
# variable "certificate_arn" {
#   description = "ACM certificate ARN for the custom domain"
#   type        = string
#   default     = null
# }
#
# resource "aws_apigatewayv2_domain_name" "this" {
#   count = var.enable_api_gateway && var.custom_domain != null ? 1 : 0
#
#   domain_name = var.custom_domain
#
#   domain_name_configuration {
#     certificate_arn = var.certificate_arn
#     endpoint_type   = "REGIONAL"
#     security_policy = "TLS_1_2"
#   }
#
#   tags = var.tags
# }
#
# resource "aws_apigatewayv2_api_mapping" "this" {
#   count = var.enable_api_gateway && var.custom_domain != null ? 1 : 0
#
#   api_id      = aws_apigatewayv2_api.this[0].id
#   domain_name = aws_apigatewayv2_domain_name.this[0].id
#   stage       = aws_apigatewayv2_stage.this[0].id
# }

