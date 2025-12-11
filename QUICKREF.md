# Quick Reference Guide

## Phased Deployment Commands

### Phase 1: Development

```bash
# 1. Setup
kubectl apply -f argocd/namespaces.yaml
kubectl create secret docker-registry acr-secret \
  --docker-server=teleiosacr.azurecr.io \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=rideshare-dev

# 2. Deploy
kubectl apply -f argocd/rideshare-applicationset-dev.yaml

# 3. Monitor
kubectl get applications -n argocd | grep "rideshare.*-dev"
kubectl get pods -n rideshare-dev
kubectl get pods -n rideshare-dev -w

# 4. Check logs
kubectl logs -f deployment/rideshare-rider-service -n rideshare-dev

# 5. Test
kubectl port-forward -n rideshare-dev svc/rideshare-rider-service 8080:80
curl http://localhost:8080/health
```

### Phase 2: Staging

```bash
# After dev is validated...

# 1. Setup
kubectl create secret docker-registry acr-secret \
  --docker-server=teleiosacr.azurecr.io \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=rideshare-staging

# 2. Deploy
kubectl apply -f argocd/rideshare-applicationset-staging.yaml

# 3. Monitor
kubectl get applications -n argocd | grep "rideshare.*-staging"
kubectl get pods -n rideshare-staging
```

### Phase 3: Production

```bash
# After staging is validated and approved...

# 1. Setup
kubectl create secret docker-registry acr-secret \
  --docker-server=teleiosacr.azurecr.io \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=rideshare-prod

# 2. Deploy
kubectl apply -f argocd/rideshare-applicationset-prod.yaml

# 3. Manual sync each service
argocd app sync rideshare-rider-service-prod
argocd app sync rideshare-driver-service-prod
argocd app sync rideshare-email-service-prod

# 4. Monitor
kubectl get applications -n argocd | grep "rideshare.*-prod"
kubectl get pods -n rideshare-prod
```

## Common Operations

### Check Status
```bash
# All environments
kubectl get applications -n argocd | grep rideshare
kubectl get pods -n rideshare-dev -n rideshare-staging -n rideshare-prod

# Dev only
kubectl get applications -n argocd | grep "rideshare.*-dev"
kubectl get pods -n rideshare-dev

# Staging only
kubectl get applications -n argocd | grep "rideshare.*-staging"
kubectl get pods -n rideshare-staging

# Production only
kubectl get applications -n argocd | grep "rideshare.*-prod"
kubectl get pods -n rideshare-prod
```

### View Logs
```bash
# Specific service
kubectl logs -f deployment/rideshare-rider-service -n rideshare-dev

# All pods in namespace
kubectl logs -n rideshare-dev --all-containers=true -f --max-log-requests=10
```

### Describe Resources
```bash
# Pod details
kubectl describe pod <pod-name> -n rideshare-dev

# Service details
kubectl describe svc rideshare-rider-service -n rideshare-dev

# ArgoCD application
argocd app get rideshare-rider-service-dev
kubectl describe application rideshare-rider-service-dev -n argocd
```

### Test Configuration
```bash
# Test helm template rendering for dev
helm template rideshare-rider-service helm/rideshare-microservice \
  -f values/rideshare-rider-service.yaml \
  -f values/dev/common.yaml

# Test helm template rendering for staging
helm template rideshare-driver-service helm/rideshare-microservice \
  -f values/rideshare-driver-service.yaml \
  -f values/staging/common.yaml

# Test helm template rendering for prod
helm template rideshare-email-service helm/rideshare-microservice \
  -f values/rideshare-email-service.yaml \
  -f values/prod/common.yaml

# Lint chart
helm lint helm/rideshare-microservice
```

### Sync Applications
```bash
# Sync one app
argocd app sync rideshare-rider-service-dev

# Force sync
argocd app sync rideshare-rider-service-dev --force

# Sync all (careful!)
kubectl get applications -n argocd -o name | grep rideshare | xargs -I {} kubectl patch {} -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

### Rollback
```bash
# Via ArgoCD
argocd app rollback rideshare-rider-service-dev

# Via kubectl
kubectl rollout undo deployment/rideshare-rider-service -n rideshare-dev

# Rollback to specific revision
kubectl rollout undo deployment/rideshare-rider-service -n rideshare-dev --to-revision=2
```

### Scale Manually
```bash
# Scale deployment
kubectl scale deployment rideshare-rider-service -n rideshare-dev --replicas=3

# Note: ArgoCD will revert this on next sync if auto-sync is enabled
```

### Port Forwarding
```bash
# Forward service port
kubectl port-forward -n rideshare-dev svc/rideshare-rider-service 8080:80

# Forward pod port
kubectl port-forward -n rideshare-dev <pod-name> 8080:3000
```

### Execute Commands in Pods
```bash
# Get shell
kubectl exec -it -n rideshare-dev deployment/rideshare-rider-service -- /bin/sh

# Run single command
kubectl exec -n rideshare-dev deployment/rideshare-rider-service -- env

# Test inter-service communication
kubectl exec -n rideshare-dev deployment/rideshare-rider-service -- \
  curl http://rideshare-driver-service/health
```

## Troubleshooting

### Image Pull Errors
```bash
# Check secret exists
kubectl get secret acr-secret -n rideshare-dev

# Recreate secret
kubectl create secret docker-registry acr-secret \
  --docker-server=teleiosacr.azurecr.io \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=rideshare-dev \
  --dry-run=client -o yaml | kubectl apply -f -

# Check image name in values file
cat values/rideshare-rider-service.yaml | grep repository
```

### Pod Not Starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n rideshare-dev

# Check previous logs if CrashLoopBackOff
kubectl logs <pod-name> -n rideshare-dev --previous

# Check resource constraints
kubectl top pods -n rideshare-dev
kubectl describe node
```

### ArgoCD Sync Issues
```bash
# Check application status
argocd app get rideshare-rider-service-dev

# View sync diff
argocd app diff rideshare-rider-service-dev

# Check for manual changes
kubectl get deployment rideshare-rider-service -n rideshare-dev -o yaml

# Force sync
argocd app sync rideshare-rider-service-dev --force --replace
```

### Connection Issues
```bash
# Check service endpoints
kubectl get endpoints -n rideshare-dev

# Check service selector matches pods
kubectl get svc rideshare-rider-service -n rideshare-dev -o yaml
kubectl get pods -n rideshare-dev -l app.kubernetes.io/name=rideshare-rider-service

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup rideshare-driver-service.rideshare-dev.svc.cluster.local
```

### Database Connection Issues
```bash
# Check secret values
kubectl get secret rideshare-rider-service-secret -n rideshare-dev -o yaml

# Decode secret
kubectl get secret rideshare-rider-service-secret -n rideshare-dev \
  -o jsonpath='{.data.DATABASE_URL}' | base64 -d

# Test connection from pod
kubectl exec -it -n rideshare-dev deployment/rideshare-rider-service -- \
  env | grep DATABASE
```

## File Locations

### Configuration Files
```
values/rideshare-rider-service.yaml    - Rider service config
values/rideshare-driver-service.yaml   - Driver service config
values/rideshare-email-service.yaml    - Email service config
values/dev/common.yaml                 - Dev environment config
values/staging/common.yaml             - Staging environment config
values/prod/common.yaml                - Production environment config
```

### ApplicationSet Files
```
argocd/rideshare-applicationset-dev.yaml      - Dev environment
argocd/rideshare-applicationset-staging.yaml  - Staging environment
argocd/rideshare-applicationset-prod.yaml     - Production environment
```

### Helm Chart
```
helm/rideshare-microservice/               - Shared Helm chart
helm/rideshare-microservice/values.yaml    - Default values
helm/rideshare-microservice/templates/     - Kubernetes templates
```

## Important URLs to Update

Before deployment, update these in your files:

1. **Repository URL** in all ApplicationSet files:
   ```yaml
   # argocd/rideshare-applicationset-dev.yaml (line 16)
   # argocd/rideshare-applicationset-staging.yaml (line 16)
   # argocd/rideshare-applicationset-prod.yaml (line 16)
   repoURL: https://github.com/YOUR_ORG/kubernetes-infra.git
   ```

2. **Secrets** in environment common files:
   ```yaml
   # values/dev/common.yaml
   # values/staging/common.yaml
   # values/prod/common.yaml
   secrets:
     DATABASE_URL: "postgresql://..."
     REDIS_URL: "redis://..."
   ```

3. **Ingress hosts** in service values files (if using ingress):
   ```yaml
   # values/rideshare-rider-service.yaml
   ingress:
     hosts:
       - host: rider-api.example.com
   ```

## Git Workflow

```bash
# After making changes
git add .
git commit -m "Update service configuration"
git push

# ArgoCD will detect changes and sync automatically (if auto-sync enabled)
# Check sync status
kubectl get applications -n argocd | grep "rideshare.*-dev"
kubectl get pods -n rideshare-dev
```

## Emergency Procedures

### Stop All Deployments in Dev
```bash
kubectl delete -f argocd/rideshare-applicationset-dev.yaml
```

### Stop All Deployments in Staging
```bash
kubectl delete -f argocd/rideshare-applicationset-staging.yaml
```

### Emergency Production Rollback
```bash
# Option 1: Rollback deployment
kubectl rollout undo deployment/rideshare-rider-service -n rideshare-prod

# Option 2: Scale to 0
kubectl scale deployment rideshare-rider-service -n rideshare-prod --replicas=0

# Option 3: Delete ApplicationSet
kubectl delete -f argocd/rideshare-applicationset-prod.yaml
```

## Useful Aliases

Add these to your shell profile for faster access:

```bash
alias k=kubectl
alias kgp='kubectl get pods'
alias kgpd='kubectl get pods -n rideshare-dev'
alias kgps='kubectl get pods -n rideshare-staging'
alias kgpp='kubectl get pods -n rideshare-prod'
alias kl='kubectl logs -f'
alias kd='kubectl describe'
alias ke='kubectl exec -it'
alias argo='argocd app'
```
