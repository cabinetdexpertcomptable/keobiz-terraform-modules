# ============================================
# Dynamic Lambda Functions
# ============================================
# Creates Lambda functions dynamically based on
# the config.json files in functions/ directory.
#
# Adding a new function:
# 1. Create functions/my-func/config.json
# 2. Create functions/my-func/handler.py
# 3. Run: python scripts/generate-tf-config.py > infra/terraform/functions.auto.tfvars.json
# 4. Deploy!
# ============================================

locals {
  # Shared environment variables for all functions
  shared_env_vars = {
    ENVIRONMENT = terraform.workspace
    LOG_LEVEL   = terraform.workspace == "production" ? "INFO" : "DEBUG"
  }
  
  # Helper to get value for current environment (with fallback)
  get_env_value = { for name, config in var.functions : name => {
    memory_size = try(
      config.memory_size[terraform.workspace],
      config.memory_size["dev"],
      256
    )
    timeout = try(
      config.timeout[terraform.workspace],
      config.timeout["dev"],
      30
    )
    reserved_concurrency = try(
      config.reserved_concurrency[terraform.workspace],
      config.reserved_concurrency,
      -1
    )
  }}
}

# ============================================
# Lambda Functions (one per config)
# ============================================

module "lambda" {
  source   = "github.com/cabinetdexpertcomptable/keobiz-terraform-modules//lambda"
  for_each = var.functions

  function_name = "${local.project_name}-${each.value.name}"
  description   = each.value.description
  handler       = each.value.handler
  runtime       = each.value.runtime

  # Package from S3
  s3_bucket = var.s3_bucket
  s3_key    = "${var.s3_prefix}/${each.value.name}-lambda-${var.lambda_package_version}.zip"

  # Performance (environment-specific)
  memory_size          = local.get_env_value[each.key].memory_size
  timeout              = local.get_env_value[each.key].timeout
  reserved_concurrency = local.get_env_value[each.key].reserved_concurrency

  # Environment variables
  env_vars = merge(local.shared_env_vars, each.value.env_vars)

  # Datadog
  enable_datadog             = true
  datadog_api_key_secret_arn = data.aws_secretsmanager_secret.datadog_api_key.arn

  # API Gateway (if enabled in config)
  enable_api_gateway   = each.value.enable_api_gateway
  api_gateway_routes   = each.value.api_routes
  api_gateway_cors_origins = terraform.workspace == "production" ? ["https://app.keobiz.com"] : ["*"]

  # Scheduling disabled at module level (we create schedules separately)
  enable_scheduling = false

  # Versioning
  app_version     = var.lambda_package_version
  publish_version = true

  # Tags
  tags = merge(local.tags, each.value.tags)
}

# ============================================
# SQS Queues (for functions with enable_sqs=true)
# ============================================

resource "aws_sqs_queue" "function_queue" {
  for_each = { for name, config in var.functions : name => config if config.enable_sqs }

  name                       = "${local.project_name}-${each.key}-${terraform.workspace}"
  visibility_timeout_seconds = local.get_env_value[each.key].timeout * 6
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.function_dlq[each.key].arn
    maxReceiveCount     = 3
  })

  tags = merge(local.tags, { Function = each.key })
}

resource "aws_sqs_queue" "function_dlq" {
  for_each = { for name, config in var.functions : name => config if config.enable_sqs }

  name                      = "${local.project_name}-${each.key}-dlq-${terraform.workspace}"
  message_retention_seconds = 1209600

  tags = merge(local.tags, { Function = each.key })
}

# SQS -> Lambda trigger
resource "aws_lambda_event_source_mapping" "sqs" {
  for_each = { for name, config in var.functions : name => config if config.enable_sqs }

  event_source_arn                   = aws_sqs_queue.function_queue[each.key].arn
  function_name                      = module.lambda[each.key].function_arn
  batch_size                         = each.value.sqs_batch_size
  maximum_batching_window_in_seconds = each.value.sqs_batch_window
  function_response_types            = ["ReportBatchItemFailures"]
}

# IAM for SQS access
resource "aws_iam_role_policy" "sqs_access" {
  for_each = { for name, config in var.functions : name => config if config.enable_sqs }

  name = "sqs-access"
  role = module.lambda[each.key].role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = [aws_sqs_queue.function_queue[each.key].arn]
    }]
  })
}

