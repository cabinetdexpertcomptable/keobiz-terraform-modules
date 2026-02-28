#!/usr/bin/env python3
"""
Generate Terraform configuration JSON from function configs.

This script reads all config.json files from functions/ and outputs
a combined JSON that Terraform can read with jsondecode(file(...)).

Usage:
    python scripts/generate-tf-config.py > infra/terraform/functions.auto.tfvars.json
"""

import json
import os
from pathlib import Path


def main():
    project_dir = Path(__file__).parent.parent
    functions_dir = project_dir / "functions"
    
    functions = {}
    
    # Find all config.json files
    for config_file in functions_dir.glob("*/config.json"):
        func_name = config_file.parent.name
        
        with open(config_file) as f:
            config = json.load(f)
        
        functions[func_name] = config
    
    # Output as Terraform-compatible JSON
    output = {
        "functions": functions
    }
    
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()

