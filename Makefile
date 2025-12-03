.PHONY: help lint-chart test-chart deploy-namespaces status sync-all

help:
	@echo "Available targets:"
	@echo ""
	@echo "Testing & Validation:"
	@echo "  lint-chart                      - Lint the Helm chart"
	@echo "  test-chart SERVICE=name         - Test Helm template for a service (dev)"
	@echo "  test-chart-staging SERVICE=name - Test Helm template for a service (staging)"
	@echo "  test-chart-prod SERVICE=name    - Test Helm template for a service (prod)"
	@echo ""
	@echo "Initial Setup:"
	@echo "  deploy-namespaces               - Create all namespaces"
	@echo "  create-acr-secrets              - Create ACR pull secrets in ALL namespaces"
	@echo "  create-acr-secret-dev           - Create ACR pull secret in dev only"
	@echo "  create-acr-secret-staging       - Create ACR pull secret in staging only"
	@echo "  create-acr-secret-prod          - Create ACR pull secret in prod only"
	@echo ""
	@echo "Phased Deployment (use in order):"
	@echo "  deploy-dev                      - Deploy to DEV environment"
	@echo "  deploy-staging                  - Deploy to STAGING environment"
	@echo "  deploy-prod                     - Deploy to PRODUCTION environment"
	@echo ""
	@echo "Monitoring:"
	@echo "  status                          - Show status of all applications"
	@echo "  status-dev                      - Show status of dev environment"
	@echo "  status-staging                  - Show status of staging environment"
	@echo "  status-prod                     - Show status of prod environment"
	@echo ""
	@echo "Cleanup:"
	@echo "  delete-dev                      - Delete dev ApplicationSet"
	@echo "  delete-staging                  - Delete staging ApplicationSet"
	@echo "  delete-prod                     - Delete prod ApplicationSet"

lint-chart:
	@echo "Linting Helm chart..."
	helm lint helm/rideshare-microservice

test-chart:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Error: SERVICE variable is required. Usage: make test-chart SERVICE=rideshare-rider-service"; \
		exit 1; \
	fi
	@echo "Testing Helm chart for $(SERVICE) in dev environment..."
	helm template $(SERVICE) helm/rideshare-microservice \
		-f values/$(SERVICE).yaml \
		-f values/dev/common.yaml

test-chart-staging:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Error: SERVICE variable is required. Usage: make test-chart-staging SERVICE=rideshare-rider-service"; \
		exit 1; \
	fi
	@echo "Testing Helm chart for $(SERVICE) in staging environment..."
	helm template $(SERVICE) helm/rideshare-microservice \
		-f values/$(SERVICE).yaml \
		-f values/staging/common.yaml

test-chart-prod:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Error: SERVICE variable is required. Usage: make test-chart-prod SERVICE=rideshare-rider-service"; \
		exit 1; \
	fi
	@echo "Testing Helm chart for $(SERVICE) in production environment..."
	helm template $(SERVICE) helm/rideshare-microservice \
		-f values/$(SERVICE).yaml \
		-f values/prod/common.yaml

deploy-namespaces:
	@echo "Creating namespaces..."
	kubectl apply -f argocd/namespaces.yaml

# Phase 1: Deploy to DEV
deploy-dev:
	@echo "====================================="
	@echo "Deploying to DEV environment"
	@echo "====================================="
	@kubectl apply -f argocd/rideshare-applicationset-dev.yaml
	@echo ""
	@echo "✅ Dev ApplicationSet deployed!"
	@echo "Monitor with: make status-dev"

# Phase 2: Deploy to STAGING
deploy-staging:
	@echo "====================================="
	@echo "Deploying to STAGING environment"
	@echo "====================================="
	@echo "⚠️  WARNING: Ensure dev is fully tested before proceeding!"
	@read -p "Continue with staging deployment? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@kubectl apply -f argocd/rideshare-applicationset-staging.yaml
	@echo ""
	@echo "✅ Staging ApplicationSet deployed!"
	@echo "Monitor with: make status-staging"

# Phase 3: Deploy to PRODUCTION
deploy-prod:
	@echo "====================================="
	@echo "Deploying to PRODUCTION environment"
	@echo "====================================="
	@echo "⚠️  WARNING: This will deploy to PRODUCTION!"
	@echo "⚠️  Ensure staging is fully tested and approved!"
	@read -p "Are you ABSOLUTELY sure? [yes/NO] " confirm && [ "$$confirm" = "yes" ] || exit 1
	@kubectl apply -f argocd/rideshare-applicationset-prod.yaml
	@echo ""
	@echo "✅ Production ApplicationSet deployed!"
	@echo "⚠️  Note: Production requires MANUAL sync for each application"
	@echo "Sync with: argocd app sync <app-name>-prod"
	@echo "Monitor with: make status-prod"

status:
	@echo "====================================="
	@echo "All Environments Status"
	@echo "====================================="
	@echo ""
	@echo "ArgoCD Applications:"
	@kubectl get applications -n argocd | grep rideshare || echo "No applications found"
	@echo ""
	@echo "DEV Pods:"
	@kubectl get pods -n rideshare-dev 2>/dev/null || echo "Namespace not found or no pods"
	@echo ""
	@echo "STAGING Pods:"
	@kubectl get pods -n rideshare-staging 2>/dev/null || echo "Namespace not found or no pods"
	@echo ""
	@echo "PRODUCTION Pods:"
	@kubectl get pods -n rideshare-prod 2>/dev/null || echo "Namespace not found or no pods"

status-dev:
	@echo "====================================="
	@echo "DEV Environment Status"
	@echo "====================================="
	@echo ""
	@echo "ArgoCD Applications:"
	@kubectl get applications -n argocd | grep "rideshare.*-dev" || echo "No dev applications found"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n rideshare-dev 2>/dev/null || echo "Namespace not found or no pods"
	@echo ""
	@echo "Services:"
	@kubectl get svc -n rideshare-dev 2>/dev/null || echo "No services found"

status-staging:
	@echo "====================================="
	@echo "STAGING Environment Status"
	@echo "====================================="
	@echo ""
	@echo "ArgoCD Applications:"
	@kubectl get applications -n argocd | grep "rideshare.*-staging" || echo "No staging applications found"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n rideshare-staging 2>/dev/null || echo "Namespace not found or no pods"
	@echo ""
	@echo "Services:"
	@kubectl get svc -n rideshare-staging 2>/dev/null || echo "No services found"

status-prod:
	@echo "====================================="
	@echo "PRODUCTION Environment Status"
	@echo "====================================="
	@echo ""
	@echo "ArgoCD Applications:"
	@kubectl get applications -n argocd | grep "rideshare.*-prod" || echo "No prod applications found"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n rideshare-prod 2>/dev/null || echo "Namespace not found or no pods"
	@echo ""
	@echo "Services:"
	@kubectl get svc -n rideshare-prod 2>/dev/null || echo "No services found"

sync-all:
	@echo "Syncing all rideshare applications..."
	kubectl get applications -n argocd -o name | grep rideshare | xargs -I {} kubectl patch {} -n argocd --type merge -p '{"operation":{"sync":{}}}'

create-acr-secrets:
	@if [ -z "$(ACR_USERNAME)" ] || [ -z "$(ACR_PASSWORD)" ]; then \
		echo "Error: ACR_USERNAME and ACR_PASSWORD environment variables are required"; \
		echo "Usage: ACR_USERNAME=xxx ACR_PASSWORD=xxx make create-acr-secrets"; \
		exit 1; \
	fi
	@echo "Creating ACR secrets in all namespaces..."
	@kubectl create secret docker-registry acr-secret \
		--docker-server=teleiosacr.azurecr.io \
		--docker-username=$(ACR_USERNAME) \
		--docker-password=$(ACR_PASSWORD) \
		--namespace=rideshare-dev \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret docker-registry acr-secret \
		--docker-server=teleiosacr.azurecr.io \
		--docker-username=$(ACR_USERNAME) \
		--docker-password=$(ACR_PASSWORD) \
		--namespace=rideshare-staging \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret docker-registry acr-secret \
		--docker-server=teleiosacr.azurecr.io \
		--docker-username=$(ACR_USERNAME) \
		--docker-password=$(ACR_PASSWORD) \
		--namespace=rideshare-prod \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ ACR secrets created in all namespaces"

create-acr-secret-dev:
	@if [ -z "$(ACR_USERNAME)" ] || [ -z "$(ACR_PASSWORD)" ]; then \
		echo "Error: ACR_USERNAME and ACR_PASSWORD environment variables are required"; \
		echo "Usage: ACR_USERNAME=xxx ACR_PASSWORD=xxx make create-acr-secret-dev"; \
		exit 1; \
	fi
	@echo "Creating ACR secret in rideshare-dev namespace..."
	@kubectl create secret docker-registry acr-secret \
		--docker-server=teleiosacr.azurecr.io \
		--docker-username=$(ACR_USERNAME) \
		--docker-password=$(ACR_PASSWORD) \
		--namespace=rideshare-dev \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ ACR secret created in rideshare-dev"

create-acr-secret-staging:
	@if [ -z "$(ACR_USERNAME)" ] || [ -z "$(ACR_PASSWORD)" ]; then \
		echo "Error: ACR_USERNAME and ACR_PASSWORD environment variables are required"; \
		echo "Usage: ACR_USERNAME=xxx ACR_PASSWORD=xxx make create-acr-secret-staging"; \
		exit 1; \
	fi
	@echo "Creating ACR secret in rideshare-staging namespace..."
	@kubectl create secret docker-registry acr-secret \
		--docker-server=teleiosacr.azurecr.io \
		--docker-username=$(ACR_USERNAME) \
		--docker-password=$(ACR_PASSWORD) \
		--namespace=rideshare-staging \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ ACR secret created in rideshare-staging"

create-acr-secret-prod:
	@if [ -z "$(ACR_USERNAME)" ] || [ -z "$(ACR_PASSWORD)" ]; then \
		echo "Error: ACR_USERNAME and ACR_PASSWORD environment variables are required"; \
		echo "Usage: ACR_USERNAME=xxx ACR_PASSWORD=xxx make create-acr-secret-prod"; \
		exit 1; \
	fi
	@echo "Creating ACR secret in rideshare-prod namespace..."
	@kubectl create secret docker-registry acr-secret \
		--docker-server=teleiosacr.azurecr.io \
		--docker-username=$(ACR_USERNAME) \
		--docker-password=$(ACR_PASSWORD) \
		--namespace=rideshare-prod \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ ACR secret created in rideshare-prod"

delete-dev:
	@echo "Deleting dev ApplicationSet (this will remove dev applications)..."
	@kubectl delete -f argocd/rideshare-applicationset-dev.yaml
	@echo "✅ Dev ApplicationSet deleted"

delete-staging:
	@echo "Deleting staging ApplicationSet (this will remove staging applications)..."
	@kubectl delete -f argocd/rideshare-applicationset-staging.yaml
	@echo "✅ Staging ApplicationSet deleted"

delete-prod:
	@echo "⚠️  WARNING: This will delete PRODUCTION applications!"
	@read -p "Are you sure? [yes/NO] " confirm && [ "$$confirm" = "yes" ] || exit 1
	@kubectl delete -f argocd/rideshare-applicationset-prod.yaml
	@echo "✅ Production ApplicationSet deleted"

# Quick setup for Phase 1 (Dev only)
quick-start-dev:
	@echo "====================================="
	@echo "Quick Start - DEV Environment"
	@echo "====================================="
	@echo ""
	@echo "Step 1: Creating namespaces..."
	@make deploy-namespaces
	@echo ""
	@echo "✅ Setup partially complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Update repository URL in argocd/rideshare-applicationset-dev.yaml"
	@echo "2. Update secrets in values/dev/common.yaml"
	@echo "3. Create ACR secret: ACR_USERNAME=xxx ACR_PASSWORD=xxx make create-acr-secret-dev"
	@echo "4. Deploy to dev: make deploy-dev"
	@echo "5. Monitor: make status-dev"
	@echo ""
	@echo "See MIGRATION.md for detailed instructions"
