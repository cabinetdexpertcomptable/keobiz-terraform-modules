# ============================================
# Required Variables
# ============================================

variable "function_name" {
  description = "Name of the Lambda function (will be suffixed with workspace name)"
  type        = string
}

variable "handler" {
  description = "Function entrypoint (e.g., 'index.handler' for Node.js, 'main.handler' for Python)"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = <<EOS
Lambda runtime. Common values:
- nodejs20.x, nodejs18.x (recommended)
- python3.11, python3.12
- java17, java21
- dotnet6, dotnet8
- provided.al2023 (custom runtime)
EOS
  type        = string
  default     = "nodejs20.x"
}

# ============================================
# Deployment Configuration
# ============================================

variable "package_type" {
  description = "Lambda deployment package type: 'Zip' or 'Image'"
  type        = string
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be 'Zip' or 'Image'"
  }
}

variable "filename" {
  description = "Path to the Lambda deployment package (ZIP file). Used when s3_bucket is not set"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the Lambda deployment package"
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "S3 object version of the Lambda deployment package"
  type        = string
  default     = null
}

variable "image_uri" {
  description = "ECR image URI for container-based Lambda (required when package_type = 'Image')"
  type        = string
  default     = null
}

variable "layers" {
  description = "List of Lambda Layer ARNs to attach"
  type        = list(string)
  default     = []
}

# ============================================
# Performance & Resources
# ============================================

variable "memory_size" {
  description = <<EOS
Amount of memory in MB. Also affects CPU allocation:
- 128-3008 MB: Proportional CPU
- 1769 MB: 1 vCPU
- 10240 MB: 6 vCPU
EOS
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Function timeout in seconds (max 900 = 15 minutes)"
  type        = number
  default     = 30
}

variable "reserved_concurrency" {
  description = "Reserved concurrent executions. Use -1 for unreserved"
  type        = number
  default     = -1
}

variable "provisioned_concurrency" {
  description = "Provisioned concurrent executions (reduces cold starts, has cost)"
  type        = number
  default     = 0
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage (/tmp) in MB. Range: 512-10240"
  type        = number
  default     = 512
}

# ============================================
# Environment & Secrets
# ============================================

variable "env_vars" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "ssm_parameters" {
  description = <<EOS
Map of environment variable names to SSM Parameter paths.
Example: { "DB_PASSWORD" = "/myapp/db/password" }
EOS
  type        = map(string)
  default     = {}
}

variable "secrets_arns" {
  description = "List of Secrets Manager secret ARNs the function needs access to"
  type        = list(string)
  default     = []
}

# ============================================
# Networking (VPC)
# ============================================

variable "vpc_subnet_ids" {
  description = "List of subnet IDs for VPC configuration. Set to null for non-VPC Lambda"
  type        = list(string)
  default     = null
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for VPC configuration"
  type        = list(string)
  default     = []
}

# ============================================
# IAM & Permissions
# ============================================

variable "policy_arns" {
  description = "List of IAM policy ARNs to attach to the Lambda execution role"
  type        = list(string)
  default     = []
}

variable "inline_policy" {
  description = "Inline IAM policy JSON document for custom permissions"
  type        = string
  default     = null
}

# ============================================
# Datadog Integration
# ============================================

variable "enable_datadog" {
  description = "Enable Datadog integration (adds layers and environment variables)"
  type        = bool
  default     = true
}

variable "datadog_api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Datadog API key"
  type        = string
  default     = ""
}

variable "datadog_site" {
  description = "Datadog site (datadoghq.eu for EU, datadoghq.com for US)"
  type        = string
  default     = "datadoghq.eu"
}

variable "datadog_trace_enabled" {
  description = "Enable Datadog APM tracing"
  type        = bool
  default     = true
}

variable "datadog_logs_enabled" {
  description = "Send logs to Datadog via the extension"
  type        = bool
  default     = true
}

variable "datadog_capture_payload" {
  description = "Capture Lambda request/response payloads in Datadog"
  type        = bool
  default     = false
}

# ============================================
# Observability
# ============================================

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

# ============================================
# Versioning & Aliases
# ============================================

variable "publish_version" {
  description = "Whether to publish a new version on each deployment"
  type        = bool
  default     = true
}

variable "create_alias" {
  description = "Create a Lambda alias pointing to the latest version"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Name of the Lambda alias (e.g., 'live', 'prod')"
  type        = string
  default     = "live"
}

variable "app_version" {
  description = "Application version (used for Datadog DD_VERSION)"
  type        = string
  default     = "1.0.0"
}

# ============================================
# Error Handling
# ============================================

variable "dead_letter_target_arn" {
  description = "ARN of SQS queue or SNS topic for failed invocations"
  type        = string
  default     = null
}

# ============================================
# Scheduling (EventBridge)
# ============================================

variable "enable_scheduling" {
  description = "Enable EventBridge schedule for this Lambda"
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = <<EOS
Schedule expression: rate(5 minutes), cron(0 9 * * ? *), or at(2024-01-01T00:00:00)
See: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-scheduled-rule-pattern.html
EOS
  type        = string
  default     = "rate(1 hour)"
}

variable "schedule_timezone" {
  description = "Timezone for cron expressions (e.g., 'Europe/Paris')"
  type        = string
  default     = "Europe/Paris"
}

variable "schedule_input" {
  description = "JSON input to pass to the Lambda when triggered by schedule"
  type        = string
  default     = "{}"
}

variable "schedule_flexible_window" {
  description = "Flexible time window in minutes (0 = exact time)"
  type        = number
  default     = 0
}

# ============================================
# API Gateway
# ============================================

variable "enable_api_gateway" {
  description = "Create an HTTP API Gateway to expose the Lambda"
  type        = bool
  default     = false
}

variable "api_gateway_routes" {
  description = <<EOS
List of API Gateway routes. Example:
[
  { method = "GET", path = "/users" },
  { method = "POST", path = "/users" },
  { method = "ANY", path = "/{proxy+}" }  # Catch-all
]
EOS
  type = list(object({
    method = string
    path   = string
  }))
  default = [
    { method = "ANY", path = "/{proxy+}" }
  ]
}

variable "api_gateway_cors_origins" {
  description = "Allowed origins for CORS. Use ['*'] for all origins"
  type        = list(string)
  default     = ["*"]
}

variable "api_gateway_cors_methods" {
  description = "Allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
}

variable "api_gateway_authorization" {
  description = "Authorization type: NONE, JWT, AWS_IAM"
  type        = string
  default     = "NONE"
}

variable "api_gateway_authorizer_id" {
  description = "ID of an existing API Gateway authorizer (if using JWT or custom)"
  type        = string
  default     = null
}

# ============================================
# Metadata
# ============================================

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

