# ============================================
# IAM Role for Lambda Execution
# ============================================

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-role"
  assume_role_policy = file("${path.module}/policies/assume/lambda.json")
  tags               = var.tags
}

# ============================================
# Basic Execution Role (CloudWatch Logs)
# ============================================
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================
# VPC Access (if Lambda is in VPC)
# ============================================
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = var.vpc_subnet_ids != null ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ============================================
# X-Ray Tracing (if enabled)
# ============================================
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count = var.enable_xray ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# ============================================
# Custom Policy Attachments
# ============================================
resource "aws_iam_role_policy_attachment" "custom" {
  for_each = toset(var.policy_arns)

  role       = aws_iam_role.lambda.name
  policy_arn = each.value
}

# ============================================
# Secrets Manager Access (for Datadog API key and app secrets)
# ============================================
resource "aws_iam_role_policy" "secrets_access" {
  count = var.enable_datadog || length(var.secrets_arns) > 0 ? 1 : 0

  name = "${local.function_name}-secrets-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = concat(
          var.enable_datadog && var.datadog_api_key_secret_arn != "" ? [var.datadog_api_key_secret_arn] : [],
          var.secrets_arns
        )
      }
    ]
  })
}

# ============================================
# SSM Parameter Store Access (for secrets via SSM)
# ============================================
resource "aws_iam_role_policy" "ssm_access" {
  count = length(var.ssm_parameters) > 0 ? 1 : 0

  name = "${local.function_name}-ssm-access"
  role = aws_iam_role.lambda.id

  policy = templatefile("${path.module}/policies/read-ssm-parameters.tftpl", {
    region         = local.region
    account_id     = local.account_id
    ssm_parameters = values(var.ssm_parameters)
  })
}

# ============================================
# Inline Policy (for custom permissions)
# ============================================
resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy != null ? 1 : 0

  name   = "${local.function_name}-inline-policy"
  role   = aws_iam_role.lambda.id
  policy = var.inline_policy
}

# ============================================
# Dead Letter Queue Access (if configured)
# ============================================
resource "aws_iam_role_policy" "dlq_access" {
  count = var.dead_letter_target_arn != null ? 1 : 0

  name = "${local.function_name}-dlq-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sns:Publish"
        ]
        Resource = [var.dead_letter_target_arn]
      }
    ]
  })
}

