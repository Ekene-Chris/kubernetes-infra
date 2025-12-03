# Rideshare Microservices - Kubernetes Setup

This repository contains Helm charts and ArgoCD ApplicationSet configurations for deploying rideshare microservices to Kubernetes.

## Architecture

- **Shared Helm Chart**: One common chart (`helm/rideshare-microservice`) for all microservices
- **Service-specific Values**: Each service has its own values file (`values/<service-name>.yaml`)
- **Environment-specific Values**: Common values per environment (`values/<env>/common.yaml`)
- **ArgoCD ApplicationSet**: Matrix generator to deploy all services across all environments

## Repository Structure

```
kubernetes-infra/
├── helm/
│   └── rideshare-microservice/          # Shared Helm chart
│       ├── Chart.yaml
│       ├── values.yaml                  # Default values
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── configmap.yaml
│           ├── secret.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           └── serviceaccount.yaml
├── values/
│   ├── rideshare-rider-service.yaml     # Service-specific values
│   ├── rideshare-driver-service.yaml
│   ├── rideshare-email-service.yaml
│   ├── dev/
│   │   └── common.yaml                  # Dev environment common values
│   ├── staging/
│   │   └── common.yaml                  # Staging environment common values
│   └── prod/
│       └── common.yaml                  # Production environment common values
└── argocd/
    ├── rideshare-applicationset.yaml    # ApplicationSet manifest
    ├── namespaces.yaml                  # Namespace definitions
    └── acr-secret-template.yaml         # ACR credentials template
```

## Prerequisites

1. **Kubernetes Cluster**: AKS or any Kubernetes cluster
2. **ArgoCD**: Installed and configured on the cluster
3. **kubectl**: Configured to access your cluster
4. **Helm** (optional): For testing charts locally

## Setup Instructions

### 1. Update Configuration

Before deploying, update the following:

1. **Repository URL** in `argocd/rideshare-applicationset.yaml`:
   ```yaml
   repoURL: https://github.com/YOUR_ORG/kubernetes-infra.git
   ```

2. **ACR Credentials**: Create the ACR pull secret in each namespace:
   ```bash
   # For each namespace (dev, staging, prod)
   kubectl create secret docker-registry acr-secret \
     --docker-server=teleiosacr.azurecr.io \
     --docker-username=<ACR_USERNAME> \
     --docker-password=<ACR_PASSWORD> \
     --namespace=rideshare-dev
   ```

   Or use Azure Workload Identity (recommended for AKS):
   ```bash
   az aks update -n <cluster-name> -g <resource-group> --enable-oidc-issuer --enable-workload-identity
   # Configure ACR integration
   az aks update -n <cluster-name> -g <resource-group> --attach-acr teleiosacr
   ```

3. **Secrets Management**: Update secrets in environment values files or use External Secrets Operator:
   - `values/dev/common.yaml`
   - `values/staging/common.yaml`
   - `values/prod/common.yaml`

### 2. Create Namespaces

```bash
kubectl apply -f argocd/namespaces.yaml
```

### 3. Deploy ApplicationSet

```bash
kubectl apply -f argocd/rideshare-applicationset.yaml
```

This will create ArgoCD Applications for all microservices across all environments:
- `rideshare-rider-service-dev`
- `rideshare-rider-service-staging`
- `rideshare-rider-service-prod`
- `rideshare-driver-service-dev`
- `rideshare-driver-service-staging`
- `rideshare-driver-service-prod`
- `rideshare-email-service-dev`
- `rideshare-email-service-staging`
- `rideshare-email-service-prod`

### 4. Verify Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check pods in each namespace
kubectl get pods -n rideshare-dev
kubectl get pods -n rideshare-staging
kubectl get pods -n rideshare-prod
```

## Adding a New Microservice

To add a new microservice:

1. Create a service-specific values file:
   ```bash
   cp values/rideshare-rider-service.yaml values/rideshare-payment-service.yaml
   ```

2. Update the values in the new file:
   ```yaml
   name: rideshare-payment-service
   image:
     repository: rideshare-payment-service
   config:
     SERVICE_NAME: "rideshare-payment-service"
     # Add service-specific config
   ```

3. Add the service to the ApplicationSet (`argocd/rideshare-applicationset.yaml`):
   ```yaml
   - list:
       elements:
         - service: rideshare-rider-service
         - service: rideshare-driver-service
         - service: rideshare-email-service
         - service: rideshare-payment-service  # New service
   ```

4. Commit and push changes. ArgoCD will automatically create applications for the new service.

## Testing Helm Charts Locally

Before deploying via ArgoCD, test your Helm charts:

```bash
# Lint the chart
helm lint helm/rideshare-microservice

# Test template rendering
helm template rideshare-rider-service helm/rideshare-microservice \
  -f values/rideshare-rider-service.yaml \
  -f values/dev/common.yaml

# Dry run
helm install rideshare-rider-service helm/rideshare-microservice \
  -f values/rideshare-rider-service.yaml \
  -f values/dev/common.yaml \
  -n rideshare-dev \
  --dry-run --debug
```

## Environment-Specific Deployments

### Development
- Auto-sync: Enabled
- Replicas: 1
- Resources: Minimal
- Ingress: Enabled with HTTP

### Staging
- Auto-sync: Enabled
- Replicas: 2
- Resources: Moderate
- Ingress: Enabled with HTTPS (Let's Encrypt staging)
- HPA: Enabled

### Production
- Auto-sync: Disabled (manual approval)
- Replicas: 3+
- Resources: Production-grade
- Ingress: Enabled with HTTPS (Let's Encrypt prod)
- HPA: Enabled with conservative thresholds

## Secrets Management (Important!)

**DO NOT** commit actual secrets to Git. Use one of these approaches:

### Option 1: External Secrets Operator (Recommended)
Install External Secrets Operator and integrate with Azure Key Vault:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

### Option 2: Sealed Secrets
Install Sealed Secrets controller and use sealed secrets:
```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
```

### Option 3: Azure Key Vault with CSI Driver
Use Azure Key Vault Provider for Secrets Store CSI Driver.

## Updating Deployments

### Update a specific service
1. Modify the service values file
2. Commit and push
3. ArgoCD will detect changes and sync (if auto-sync enabled)

### Update an environment
1. Modify the environment common values
2. Commit and push
3. All services in that environment will update

### Manual sync in ArgoCD
```bash
argocd app sync rideshare-rider-service-prod
```

## Rollback

```bash
# Via ArgoCD CLI
argocd app rollback rideshare-rider-service-prod

# Via kubectl
kubectl rollout undo deployment/rideshare-rider-service -n rideshare-prod
```

## Monitoring and Troubleshooting

```bash
# Check application status
argocd app get rideshare-rider-service-dev

# View logs
kubectl logs -f deployment/rideshare-rider-service -n rideshare-dev

# Check events
kubectl get events -n rideshare-dev --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod <pod-name> -n rideshare-dev
```

## Notes

- The ApplicationSet uses a matrix generator to create applications for each service/environment combination
- Values files are merged in order: default → service-specific → environment common
- Production deployments require manual sync for safety
- All services expose port 3000 internally and are accessible via ClusterIP services
- Inter-service communication uses Kubernetes DNS (e.g., `http://rideshare-driver-service.rideshare-dev.svc.cluster.local`)
