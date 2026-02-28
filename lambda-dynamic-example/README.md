# Dynamic Lambda Project

**Zero-config Lambda deployment** - Add functions just by creating folders!

## How It Works

```
functions/
├── api/
│   ├── config.json    ← Configuration (memory, timeout, routes, etc.)
│   ├── handler.py     ← Your code
│   └── requirements.txt
├── processor/
│   ├── config.json
│   ├── handler.py
│   └── requirements.txt
└── NEW-FUNCTION/      ← Just create this folder...
    ├── config.json    ← ...with a config.json
    └── handler.py     ← ...and a handler.py
                       → CI/CD handles everything else!
```

## Adding a New Function

**Step 1**: Create folder and config

```bash
mkdir functions/my-new-function
```

**Step 2**: Create `config.json`:

```json
{
  "name": "my-new-function",
  "description": "Does something cool",
  "handler": "handler.handler",
  "runtime": "python3.11",
  "memory_size": { "dev": 256, "staging": 256, "production": 512 },
  "timeout": { "dev": 30, "staging": 30, "production": 60 },
  "enable_api_gateway": true,
  "api_routes": [
    { "method": "GET", "path": "/my-endpoint" }
  ],
  "enable_scheduling": false,
  "schedules": [],
  "enable_sqs": false,
  "env_vars": {},
  "tags": { "Function": "my-new-function" }
}
```

**Step 3**: Create `handler.py`:

```python
from shared.utils import get_logger, json_response

logger = get_logger(__name__)

def handler(event, context):
    logger.info("Hello from my new function!")
    return json_response(200, {"message": "It works!"})
```

**Step 4**: Push to deploy!

```bash
git add functions/my-new-function/
git commit -m "Add my-new-function"
git push
```

**That's it!** The CI/CD will:
1. Auto-discover your new function
2. Build a ZIP package for it
3. Create the Lambda + any API Gateway/SQS/Schedules

## config.json Reference

```json
{
  "name": "function-name",
  "description": "What this function does",
  "handler": "handler.handler",
  "runtime": "python3.11",
  
  "memory_size": {
    "dev": 256,
    "staging": 512,
    "production": 1024
  },
  
  "timeout": {
    "dev": 30,
    "staging": 60,
    "production": 300
  },
  
  "reserved_concurrency": -1,
  
  "enable_api_gateway": true,
  "api_routes": [
    { "method": "GET", "path": "/users" },
    { "method": "POST", "path": "/users" }
  ],
  
  "enable_scheduling": true,
  "schedules": [
    {
      "name": "daily-job",
      "description": "Runs every day at 2 AM",
      "expression": "cron(0 2 * * ? *)",
      "input": { "task": "cleanup" },
      "enabled": { "dev": true, "staging": true, "production": true }
    }
  ],
  
  "enable_sqs": false,
  "sqs_batch_size": 10,
  "sqs_batch_window": 30,
  
  "env_vars": {
    "CUSTOM_VAR": "value"
  },
  
  "tags": {
    "Function": "my-function"
  }
}
```

## Project Structure

```
lambda-dynamic-example/
├── .github/workflows/       # CI/CD (same for all functions!)
│   ├── dev.yml
│   ├── staging.yml
│   └── production.yml
│
├── functions/               # Your Lambda functions
│   ├── api/
│   │   ├── config.json
│   │   └── handler.py
│   ├── processor/
│   └── scheduler/
│
├── shared/                  # Shared code (auto-included in all)
│   ├── utils.py
│   └── config.py
│
├── scripts/
│   ├── build.sh            # Auto-discovers & builds all functions
│   ├── upload.sh           # Uploads all ZIPs to S3
│   └── generate-tf-config.py
│
├── infra/terraform/
│   ├── main.tf
│   ├── lambdas.tf          # Dynamic! Uses for_each
│   └── schedules.tf        # Dynamic! Uses for_each
│
└── Makefile
```

## Commands

```bash
# List discovered functions
make list-functions

# Build all (auto-discovery)
make build

# Deploy
make deploy-dev
make deploy-staging
make deploy-prod
```

## How the Magic Works

### 1. Build Script (`scripts/build.sh`)

Finds all `config.json` files and builds a ZIP for each:

```bash
find functions -name "config.json" | for each -> build ZIP
```

### 2. Terraform (`lambdas.tf`)

Uses `for_each` to create resources dynamically:

```hcl
module "lambda" {
  for_each = var.functions  # From functions.auto.tfvars.json
  
  function_name = each.value.name
  memory_size   = each.value.memory_size[terraform.workspace]
  # ... etc
}
```

### 3. Config Generator (`scripts/generate-tf-config.py`)

Reads all `config.json` files and outputs a single Terraform variable file:

```
functions/api/config.json      ]
functions/processor/config.json] → functions.auto.tfvars.json
functions/scheduler/config.json]
```

## Comparison: Before vs After

### Before (Manual)

Adding a function required editing:
- `.github/workflows/dev.yml` (add build step)
- `.github/workflows/staging.yml` (add build step)
- `.github/workflows/production.yml` (add build step)
- `infra/terraform/new-function.tf` (new file)
- `Makefile` (add build target)

### After (Dynamic)

Adding a function requires:
- Create `functions/my-func/config.json`
- Create `functions/my-func/handler.py`
- `git push`

**CI/CD and Terraform handle everything automatically!**

## Tips

### Function-Specific Dependencies

Add them to `functions/my-func/requirements.txt`:

```
# functions/processor/requirements.txt
pandas>=2.0.0
```

### Disable a Schedule Per Environment

In `config.json`:

```json
"schedules": [{
  "name": "heavy-sync",
  "expression": "rate(5 minutes)",
  "enabled": {
    "dev": false,      // Disabled in dev
    "staging": true,
    "production": true
  }
}]
```

### Different Memory Per Environment

```json
"memory_size": {
  "dev": 256,
  "staging": 512,
  "production": 2048
}
```

