# kubernetes-infra

Kubernetes infrastructure repository for deploying rideshare microservices using Helm charts and ArgoCD ApplicationSets.

## 🚀 Migration Approach: Phased Deployment

This repository supports a **phased migration** from Azure Container Apps to Kubernetes:

**Phase 1:** Deploy to **Dev** → Test and validate
**Phase 2:** Deploy to **Staging** → Full testing
**Phase 3:** Deploy to **Production** → Gradual rollout

> **⚠️ Important:** Each phase must be completed and validated before moving to the next.

## 📚 Documentation

- **[MIGRATION.md](./MIGRATION.md)** - Complete phased migration guide (⭐ START HERE)
- **[SETUP.md](./SETUP.md)** - Detailed technical setup instructions
- **[examples/adding-new-service.md](./examples/adding-new-service.md)** - How to add new microservices

## 🏗️ Architecture

- **Shared Helm Chart:** Single chart for all microservices (`helm/rideshare-microservice/`)
- **Service-Specific Values:** Each service has its own configuration (`values/<service>.yaml`)
- **Environment-Specific Values:** Per-environment settings (`values/<env>/common.yaml`)
- **Separate ApplicationSets:** One per environment for controlled deployment

## 🎯 Quick Start (Dev Environment Only)

### Prerequisites
- Kubernetes cluster with ArgoCD installed
- `kubectl` configured
- ACR credentials

### Deploy to Dev in 5 Steps

```bash
# 1. Update repository URL in argocd/rideshare-applicationset-dev.yaml
# Edit line 16: repoURL: https://github.com/YOUR_ORG/kubernetes-infra.git

# 2. Create namespaces
make deploy-namespaces

# 3. Update secrets in values/dev/common.yaml (database, redis URLs)

# 4. Create ACR pull secret
ACR_USERNAME=xxx ACR_PASSWORD=xxx make create-acr-secret-dev

# 5. Deploy to dev
make deploy-dev

# 6. Monitor deployment
make status-dev
```

Or use the quick start command:
```bash
make quick-start-dev
```

## 📦 Repository Structure

```
kubernetes-infra/
├── helm/rideshare-microservice/          # Shared Helm chart
├── values/                               # Configuration files
│   ├── rideshare-rider-service.yaml     # Service-specific config
│   ├── rideshare-driver-service.yaml
│   ├── rideshare-email-service.yaml
│   ├── dev/common.yaml                  # Dev environment config
│   ├── staging/common.yaml              # Staging environment config
│   └── prod/common.yaml                 # Prod environment config
├── argocd/
│   ├── rideshare-applicationset-dev.yaml       # Dev ApplicationSet
│   ├── rideshare-applicationset-staging.yaml   # Staging ApplicationSet
│   ├── rideshare-applicationset-prod.yaml      # Prod ApplicationSet
│   └── namespaces.yaml                         # Namespace definitions
├── MIGRATION.md                          # Complete migration guide
└── Makefile                             # Helper commands
```

## 🎮 Key Commands

### Testing
```bash
make lint-chart                                    # Lint Helm chart
make test-chart SERVICE=rideshare-rider-service   # Test template rendering
```

### Deployment (Phased)
```bash
make deploy-dev         # Phase 1: Deploy to dev
make deploy-staging     # Phase 2: Deploy to staging (with confirmation)
make deploy-prod        # Phase 3: Deploy to prod (requires "yes" confirmation)
```

### Monitoring
```bash
make status-dev         # Check dev environment
make status-staging     # Check staging environment
make status-prod        # Check production environment
make status             # Check all environments
```

### Cleanup
```bash
make delete-dev         # Remove dev ApplicationSet
make delete-staging     # Remove staging ApplicationSet
make delete-prod        # Remove prod ApplicationSet (requires confirmation)
```

Run `make help` to see all available commands.

## 📋 Current Services

- `rideshare-rider-service` - Handles rider operations
- `rideshare-driver-service` - Manages driver functionality
- `rideshare-email-service` - Email notifications

## 🌍 Environments

| Environment | Namespace | Replicas | Auto-Sync | HPA |
|------------|-----------|----------|-----------|-----|
| Development | `rideshare-dev` | 1 | ✅ Yes | ❌ No |
| Staging | `rideshare-staging` | 2 | ✅ Yes | ✅ Yes |
| Production | `rideshare-prod` | 3+ | ⚠️ Manual | ✅ Yes |

## ➕ Adding New Services

1. Copy a service values file:
   ```bash
   cp values/rideshare-rider-service.yaml values/rideshare-payment-service.yaml
   ```

2. Update the values in the new file

3. Add to ApplicationSet(s) in `argocd/rideshare-applicationset-dev.yaml`:
   ```yaml
   - service: rideshare-payment-service
   ```

4. Commit and push - ArgoCD auto-syncs!

See [examples/adding-new-service.md](./examples/adding-new-service.md) for details.

## 🔒 Security Notes

- **Never commit secrets to Git!** Use External Secrets Operator or Azure Key Vault
- ACR secrets are created per-namespace
- Production uses manual sync for additional safety
- All templates support sealed secrets and external secrets

## 📊 What's Next After Dev?

1. ✅ Validate all services work in dev
2. ✅ Run integration tests
3. ✅ Verify inter-service communication
4. 📝 Document any issues found
5. ➡️ Proceed to staging deployment

See [MIGRATION.md](./MIGRATION.md) for the complete checklist.

## 🆘 Troubleshooting

```bash
# Check pod logs
kubectl logs -f deployment/rideshare-rider-service -n rideshare-dev

# Check pod status
kubectl describe pod <pod-name> -n rideshare-dev

# Check ArgoCD app
argocd app get rideshare-rider-service-dev

# Force sync
argocd app sync rideshare-rider-service-dev
```

## 📞 Support

- Check ArgoCD UI for application status
- Review logs for errors
- Consult MIGRATION.md for detailed troubleshooting
- See SETUP.md for configuration details
