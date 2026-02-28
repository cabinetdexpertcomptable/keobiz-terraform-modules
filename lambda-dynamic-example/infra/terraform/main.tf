provider "aws" {
  region = "eu-central-1"
}

terraform {
  required_version = "= 1.4.6"

  backend "s3" {
    bucket         = "keobiz-terraform-state"
    key            = "dynamic-lambda-project.tfstate"
    encrypt        = true
    region         = "eu-central-1"
    dynamodb_table = "keobiz-terraform-state-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.1.0"
    }
  }
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "keobiz-terraform-state"
    key    = "env:/${terraform.workspace}/base.tfstate"
    region = "eu-central-1"
  }
}

locals {
  project_name = "dynamic-lambda"
  environment  = terraform.workspace
  
  tags = {
    Environment = terraform.workspace
    Project     = local.project_name
    ManagedBy   = "terraform"
  }
}

# Datadog API key
data "aws_secretsmanager_secret" "datadog_api_key" {
  name = "datadog/api-key"
}

