# ============================================
# Dynamic Lambda Project (Node.js)
# ============================================
# Build and deploy automatically discovers all
# functions in the functions/ directory.
# ============================================

.PHONY: help install test build clean generate-config deploy-dev deploy-staging deploy-prod

REF := $(shell git rev-parse --short HEAD 2>/dev/null || echo "local")
S3_BUCKET := keobiz-lambda-packages
S3_PREFIX := dynamic-project

help:
	@echo "Dynamic Lambda Project (Node.js)"
	@echo ""
	@echo "Adding a new function:"
	@echo "  1. Create functions/my-func/config.json"
	@echo "  2. Create functions/my-func/index.js"
	@echo "  3. Create functions/my-func/package.json"
	@echo "  4. Run: make deploy-dev"
	@echo ""
	@echo "Commands:"
	@echo "  make install      - Install dev dependencies"
	@echo "  make test         - Run tests"
	@echo "  make build        - Build all Lambda packages (auto-discovery)"
	@echo "  make clean        - Clean build artifacts"
	@echo ""
	@echo "  make generate-config  - Generate Terraform config from functions"
	@echo "  make deploy-dev       - Build + Deploy to dev"
	@echo "  make deploy-staging   - Build + Deploy to staging"
	@echo "  make deploy-prod      - Build + Deploy to production"
	@echo ""
	@echo "Functions discovered:"
	@find functions -maxdepth 2 -name "config.json" -exec dirname {} \; | xargs -I {} basename {}

install:
	npm ci

test:
	npm test

lint:
	npm run lint

clean:
	rm -rf build/
	rm -f *-lambda-*.zip
	rm -rf node_modules/
	find functions -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true

# ============================================
# Build (auto-discovers all functions)
# ============================================

build:
	rm -rf build/ *-lambda-*.zip
	@chmod +x scripts/build.sh
	./scripts/build.sh $(REF)

# ============================================
# Generate Terraform config
# ============================================

generate-config:
	@python3 scripts/generate-tf-config.py > infra/terraform/functions.auto.tfvars.json
	@echo "Generated: infra/terraform/functions.auto.tfvars.json"
	@cat infra/terraform/functions.auto.tfvars.json

# ============================================
# Upload to S3
# ============================================

upload: build
	@chmod +x scripts/upload.sh
	./scripts/upload.sh $(REF) $(S3_BUCKET) $(S3_PREFIX)

# ============================================
# Deploy
# ============================================

tf-init:
	cd infra/terraform && terraform init

deploy-dev: upload generate-config
	cd infra/terraform && \
		terraform workspace select dev || terraform workspace new dev && \
		terraform apply -var "lambda_package_version=$(REF)" -var-file=dev.tfvars -auto-approve

deploy-staging: upload generate-config
	cd infra/terraform && \
		terraform workspace select staging || terraform workspace new staging && \
		terraform apply -var "lambda_package_version=$(REF)" -var-file=staging.tfvars -auto-approve

deploy-prod: upload generate-config
	cd infra/terraform && \
		terraform workspace select production || terraform workspace new production && \
		terraform apply -var "lambda_package_version=$(REF)" -var-file=production.tfvars -auto-approve

# ============================================
# List functions
# ============================================

list-functions:
	@echo "Discovered functions:"
	@find functions -maxdepth 2 -name "config.json" -exec dirname {} \; | while read dir; do \
		name=$$(basename $$dir); \
		desc=$$(cat $$dir/config.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))"); \
		echo "  - $$name: $$desc"; \
	done
