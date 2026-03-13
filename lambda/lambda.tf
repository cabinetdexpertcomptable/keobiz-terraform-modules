# ============================================
# Lambda Function Module
# ============================================
# This module creates a Lambda function with:
# - CloudWatch Logs
# - Datadog integration (optional)
# - VPC configuration (optional)
# - Environment variables and secrets
# ============================================

locals {
  account_id    = data.aws_caller_identity.current.account_id
  region        = data.aws_region.current.name
  function_name = "${var.function_name}-${terraform.workspace}"

  # Datadog layer ARNs by runtime (eu-west-1 region)
  # Update versions periodically: https://docs.datadoghq.com/serverless/libraries_integrations/extension/
  datadog_layers = {
    "python3.9"  = "arn:aws:lambda:${local.region}:464622532012:layer:Datadog-Python39:96"
    "python3.10" = "arn:aws:lambda:${local.region}:464622532012:layer:Datadog-Python310:96"
    "python3.11" = "arn:aws:lambda:${local.region}:464622532012:layer:Datadog-Python311:96"
    "python3.12" = "arn:aws:lambda:${local.region}:464622532012:layer:Datadog-Python312:96"
    "nodejs18.x" = "arn:aws:lambda:${local.region}:464622532012:layer:Datadog-Node18-x:115"
    "nodejs20.x" = "arn:aws:lambda:${local.region}:464622532012:layer:Datadog-Node20-x:115"
  }

  datadog_extension_layer = "arn:aws:lambda:${local.region}:464622532012:layer:Datadog-Extension:62"

  # Build layers list: user layers + Datadog layers (if enabled)
  all_layers = var.package_type == "Zip" ? concat(
    var.layers,
    var.enable_datadog ? [
      lookup(local.datadog_layers, var.runtime, ""),
      local.datadog_extension_layer
    ] : []
  ) : []

  # Handler: wrap with Datadog if enabled
  # Node.js uses /opt/nodejs/node_modules/datadog-lambda-js/handler.handler
  # Python uses datadog_lambda.handler.handler
  is_nodejs = startswith(var.runtime, "nodejs")
  datadog_handler = local.is_nodejs ? "/opt/nodejs/node_modules/datadog-lambda-js/handler.handler" : "datadog_lambda.handler.handler"
  effective_handler = var.enable_datadog && var.package_type == "Zip" ? local.datadog_handler : var.handler

  # Datadog environment variables
  datadog_env_vars = var.enable_datadog ? {
    DD_API_KEY_SECRET_ARN      = var.datadog_api_key_secret_arn
    DD_SITE                    = var.datadog_site
    DD_SERVICE                 = var.function_name
    DD_ENV                     = lower(terraform.workspace)
    DD_VERSION                 = var.app_version
    DD_LAMBDA_HANDLER          = var.handler
    DD_TRACE_ENABLED           = tostring(var.datadog_trace_enabled)
    DD_LOGS_ENABLED            = tostring(var.datadog_logs_enabled)
    DD_SERVERLESS_LOGS_ENABLED = tostring(var.datadog_logs_enabled)
    DD_CAPTURE_LAMBDA_PAYLOAD  = tostring(var.datadog_capture_payload)
    DD_TAGS                    = join(",", [for k, v in var.tags : "${k}:${v}"])
  } : {}

  # Merge all environment variables
  all_env_vars = merge(
    var.env_vars,
    local.datadog_env_vars
  )
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================
# CloudWatch Log Group
# ============================================
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ============================================
# Lambda Function
# ============================================
resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = var.description
  role          = aws_iam_role.lambda.arn

  # Package type: Zip or Image
  package_type = var.package_type

  # For ZIP deployment
  runtime          = var.package_type == "Zip" ? var.runtime : null
  handler          = var.package_type == "Zip" ? local.effective_handler : null
  filename         = var.package_type == "Zip" && var.s3_bucket == null ? var.filename : null
  source_code_hash = var.package_type == "Zip" && var.s3_bucket == null && var.filename != null ? filebase64sha256(var.filename) : null

  # For S3 deployment
  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version

  # For Container Image deployment
  image_uri = var.package_type == "Image" ? var.image_uri : null

  # Performance settings
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrency

  # Layers (only for Zip)
  layers = var.package_type == "Zip" ? local.all_layers : null

  # Environment variables
  dynamic "environment" {
    for_each = length(local.all_env_vars) > 0 ? [1] : []
    content {
      variables = local.all_env_vars
    }
  }

  # VPC configuration (optional)
  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  # Tracing (X-Ray)
  dynamic "tracing_config" {
    for_each = var.enable_xray ? [1] : []
    content {
      mode = "Active"
    }
  }

  # Ephemeral storage (default 512MB, max 10GB)
  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size > 512 ? [1] : []
    content {
      size = var.ephemeral_storage_size
    }
  }

  # Dead letter queue
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  publish = var.publish_version

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy_attachment.lambda_xray
  ]
}

# ============================================
# Provisioned Concurrency (optional)
# ============================================
resource "aws_lambda_provisioned_concurrency_config" "this" {
  count = var.provisioned_concurrency > 0 ? 1 : 0

  function_name                     = aws_lambda_function.this.function_name
  provisioned_concurrent_executions = var.provisioned_concurrency
  qualifier                         = aws_lambda_function.this.version
}

# ============================================
# Lambda Alias (optional)
# ============================================
resource "aws_lambda_alias" "this" {
  count = var.create_alias ? 1 : 0

  name             = var.alias_name
  description      = "Alias for ${local.function_name}"
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}

