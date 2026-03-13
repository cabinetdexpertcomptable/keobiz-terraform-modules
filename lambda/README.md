# Lambda Terraform Module

Reusable Terraform module for deploying AWS Lambda functions with:
- **Datadog integration** (APM, logs, tracing)
- **EventBridge scheduling** (cron jobs)
- **HTTP API Gateway** (REST endpoints)
- **VPC configuration** (private network access)
- **Secrets management** (SSM Parameters, Secrets Manager)

## Usage

### Minimal Example (ZIP deployment)

```hcl
module "my_lambda" {
  source = "../keobiz-terraform-modules/lambda"

  function_name = "my-function"
  # Uses nodejs20.x and index.handler by default
  filename      = "${path.module}/lambda.zip"

  tags = {
    Project = "my-project"
  }
}
```

### With Datadog Integration

```hcl
module "my_lambda" {
  source = "../keobiz-terraform-modules/lambda"

  function_name = "my-function"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/lambda.zip"

  # Datadog configuration
  enable_datadog             = true
  datadog_api_key_secret_arn = "arn:aws:secretsmanager:eu-west-1:123456789:secret:datadog/api-key"
  datadog_site               = "datadoghq.eu"
  datadog_trace_enabled      = true
  datadog_logs_enabled       = true

  tags = {
    Project = "my-project"
  }
}
```

### Scheduled Lambda (Cron Job)

```hcl
module "daily_job" {
  source = "../keobiz-terraform-modules/lambda"

  function_name = "daily-cleanup"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/lambda.zip"
  timeout       = 300

  # Schedule configuration
  enable_scheduling   = true
  schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM
  schedule_timezone   = "Europe/Paris"
  schedule_input      = jsonencode({ task = "cleanup" })

  tags = {
    Project = "my-project"
  }
}
```

### Lambda with API Gateway

```hcl
module "api_lambda" {
  source = "../keobiz-terraform-modules/lambda"

  function_name = "my-api"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/lambda.zip"

  # API Gateway configuration
  enable_api_gateway = true
  api_gateway_routes = [
    { method = "GET", path = "/users" },
    { method = "POST", path = "/users" },
    { method = "GET", path = "/users/{id}" },
  ]
  api_gateway_cors_origins = ["https://myapp.com"]

  tags = {
    Project = "my-project"
  }
}

output "api_url" {
  value = module.api_lambda.api_gateway_url
}
```

### Lambda in VPC

```hcl
module "vpc_lambda" {
  source = "../keobiz-terraform-modules/lambda"

  function_name = "private-db-access"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/lambda.zip"

  # VPC configuration
  vpc_subnet_ids         = ["subnet-xxx", "subnet-yyy"]
  vpc_security_group_ids = ["sg-xxx"]

  tags = {
    Project = "my-project"
  }
}
```

### Container Image Lambda

```hcl
module "container_lambda" {
  source = "../keobiz-terraform-modules/lambda"

  function_name = "ml-inference"
  package_type  = "Image"
  image_uri     = "123456789.dkr.ecr.eu-west-1.amazonaws.com/my-lambda:latest"

  memory_size = 2048
  timeout     = 60

  # Datadog via environment variables (no layers for container)
  enable_datadog = false
  env_vars = {
    DD_API_KEY = "xxx"
    DD_SITE    = "datadoghq.eu"
  }

  tags = {
    Project = "my-project"
  }
}
```

### With Custom IAM Permissions

```hcl
module "s3_lambda" {
  source = "../keobiz-terraform-modules/lambda"

  function_name = "s3-processor"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/lambda.zip"

  # Attach existing policies
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

  # Or use inline policy
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = ["arn:aws:s3:::my-bucket/*"]
    }]
  })

  tags = {
    Project = "my-project"
  }
}
```

### Using Python Runtime

```hcl
module "python_lambda" {
  source = "../keobiz-terraform-modules/lambda"

  function_name = "python-function"
  handler       = "main.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/lambda.zip"

  tags = {
    Project = "my-project"
  }
}
```

## Variables

### Required

| Name | Description | Type |
|------|-------------|------|
| `function_name` | Name of the Lambda function | `string` |

### Deployment

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `package_type` | `Zip` or `Image` | `string` | `"Zip"` |
| `handler` | Function entrypoint | `string` | `"index.handler"` |
| `runtime` | Lambda runtime | `string` | `"nodejs20.x"` |
| `filename` | Path to ZIP file | `string` | `null` |
| `image_uri` | ECR image URI (for Image) | `string` | `null` |
| `layers` | Additional Lambda Layer ARNs | `list(string)` | `[]` |

### Performance

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `memory_size` | Memory in MB (128-10240) | `number` | `256` |
| `timeout` | Timeout in seconds (max 900) | `number` | `30` |
| `reserved_concurrency` | Reserved concurrent executions | `number` | `-1` |
| `provisioned_concurrency` | Provisioned concurrency | `number` | `0` |

### Datadog

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_datadog` | Enable Datadog integration | `bool` | `true` |
| `datadog_api_key_secret_arn` | Secrets Manager ARN for DD API key | `string` | `""` |
| `datadog_site` | Datadog site (datadoghq.eu/datadoghq.com) | `string` | `"datadoghq.eu"` |
| `datadog_trace_enabled` | Enable APM tracing | `bool` | `true` |
| `datadog_logs_enabled` | Send logs to Datadog | `bool` | `true` |

### Scheduling

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_scheduling` | Enable EventBridge schedule | `bool` | `false` |
| `schedule_expression` | rate() or cron() expression | `string` | `"rate(1 hour)"` |
| `schedule_timezone` | Timezone for cron | `string` | `"Europe/Paris"` |
| `schedule_input` | JSON input for scheduled invocations | `string` | `"{}"` |

### API Gateway

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_api_gateway` | Create HTTP API Gateway | `bool` | `false` |
| `api_gateway_routes` | List of routes | `list(object)` | `[{method="ANY", path="/{proxy+}"}]` |
| `api_gateway_cors_origins` | CORS allowed origins | `list(string)` | `["*"]` |

### Networking

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `vpc_subnet_ids` | VPC subnet IDs | `list(string)` | `null` |
| `vpc_security_group_ids` | VPC security group IDs | `list(string)` | `[]` |

## Outputs

| Name | Description |
|------|-------------|
| `function_name` | Lambda function name |
| `function_arn` | Lambda function ARN |
| `invoke_arn` | ARN for API Gateway invocation |
| `role_arn` | IAM execution role ARN |
| `log_group_name` | CloudWatch Log Group name |
| `api_gateway_url` | API Gateway URL (if enabled) |
| `schedule_arn` | EventBridge schedule ARN (if enabled) |

## File Structure

```
lambda/
├── lambda.tf           # Main Lambda resource
├── iam.tf              # IAM roles and policies
├── variables.tf        # Input variables
├── outputs.tf          # Output values
├── scheduling.tf       # EventBridge scheduler
├── api-gateway.tf      # HTTP API Gateway
├── policies/
│   ├── assume/
│   │   └── lambda.json
│   └── read-ssm-parameters.tftpl
└── README.md
```

## Step Functions

Step Functions workflows should be declared **at the project level**, not in this module. A state machine typically orchestrates multiple Lambdas, so it belongs alongside the Lambda module invocations. See `lambda-dynamic-example/infra/terraform/step-functions.tf` for a complete example.

## Notes

1. **Datadog layers** are automatically added when `enable_datadog = true` and `package_type = "Zip"`
2. **terraform.workspace** is used for environment naming (function name becomes `{name}-{workspace}`)
3. **VPC Lambda** requires NAT Gateway for internet access (Datadog, external APIs)
4. **Container images** don't support layers; configure Datadog via environment variables instead

