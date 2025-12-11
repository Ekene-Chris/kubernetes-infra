# Phased Migration Guide: Azure Container Apps to Kubernetes

This guide walks you through migrating your rideshare microservices from Azure Container Apps to Kubernetes in a phased approach, starting with dev, then staging, and finally production.

## Migration Phases

### Phase 1: Development Environment ✅ START HERE
### Phase 2: Staging Environment (after dev validation)
### Phase 3: Production Environment (after staging validation)

---

## Phase 1: Development Environment

### Prerequisites

1. ✅ Kubernetes cluster with ArgoCD installed
2. ✅ kubectl configured to access your cluster
3. ✅ ACR credentials for pulling images
4. ✅ This repository cloned locally

### Step 1: Update Configuration

1. **Update Git repository URL** in `argocd/rideshare-applicationset-dev.yaml`:
   ```yaml
   repoURL: https://github.com/YOUR_ORG/kubernetes-infra.git
   ```

2. **Update secrets** in `values/dev/common.yaml`:
   ```yaml
   secrets:
     DATABASE_URL: "postgresql://user:pass@your-dev-db:5432/rideshare_dev"
     REDIS_URL: "redis://your-dev-redis:6379"
   ```

3. **Review service configurations** in `values/` directory:
   - `rideshare-rider-service.yaml`
   - `rideshare-driver-service.yaml`
   - `rideshare-email-service.yaml`

### Step 2: Create Dev Namespace

```bash
# Create only the dev namespace
kubectl create namespace rideshare-dev

# Or apply namespaces.yaml (it won't hurt to create all three)
kubectl apply -f argocd/namespaces.yaml
```

### Step 3: Setup ACR Pull Secret

```bash
# Create ACR secret in dev namespace only
kubectl create secret docker-registry acr-secret \
  --docker-server=teleiosacr.azurecr.io \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=rideshare-dev
```

### Step 4: Test Helm Charts Locally (Optional but Recommended)

```bash
# Test rendering for each service
helm template rideshare-rider-service helm/rideshare-microservice \
  -f values/rideshare-rider-service.yaml \
  -f values/dev/common.yaml

helm template rideshare-driver-service helm/rideshare-microservice \
  -f values/rideshare-driver-service.yaml \
  -f values/dev/common.yaml

helm template rideshare-email-service helm/rideshare-microservice \
  -f values/rideshare-email-service.yaml \
  -f values/dev/common.yaml
```

### Step 5: Deploy to Dev via ArgoCD

```bash
# Deploy ONLY the dev ApplicationSet
kubectl apply -f argocd/rideshare-applicationset-dev.yaml
```

This will create 3 ArgoCD applications:
- `rideshare-rider-service-dev`
- `rideshare-driver-service-dev`
- `rideshare-email-service-dev`

### Step 6: Monitor Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd | grep dev

# Watch pods coming up
kubectl get pods -n rideshare-dev -w

# Check application sync status
argocd app list | grep dev

# Get detailed status of one application
argocd app get rideshare-rider-service-dev
```

### Step 7: Verify Services

```bash
# Check all services are running
kubectl get pods -n rideshare-dev
kubectl get svc -n rideshare-dev

# Check logs for each service
kubectl logs -f deployment/rideshare-rider-service -n rideshare-dev
kubectl logs -f deployment/rideshare-driver-service -n rideshare-dev
kubectl logs -f deployment/rideshare-email-service -n rideshare-dev

# Port-forward to test locally (if ingress not set up yet)
kubectl port-forward -n rideshare-dev svc/rideshare-rider-service 8080:80
# Then test: curl http://localhost:8080/health
```

### Step 8: Test Functionality

Run your test suite against the dev environment:

```bash
# Example: Test health endpoints
curl http://<your-dev-ingress>/health

# Test inter-service communication
# Exec into a pod and test
kubectl exec -it -n rideshare-dev deployment/rideshare-rider-service -- /bin/sh
# Inside pod: curl http://rideshare-driver-service/health
```

### Step 9: Troubleshooting Dev Issues

If pods aren't starting:

```bash
# Check pod status
kubectl describe pod <pod-name> -n rideshare-dev

# Common issues:
# 1. Image pull errors - check ACR secret
kubectl get secrets -n rideshare-dev | grep acr

# 2. CrashLoopBackOff - check logs
kubectl logs <pod-name> -n rideshare-dev --previous

# 3. Pending - check resources
kubectl describe node

# 4. ArgoCD sync issues
argocd app get rideshare-rider-service-dev
kubectl describe application rideshare-rider-service-dev -n argocd
```

### Step 10: Iterate and Fix

1. Make changes to values files
2. Commit and push to git
3. ArgoCD will auto-sync (or manually sync)
4. Verify changes

```bash
# Force sync if needed
argocd app sync rideshare-rider-service-dev
```

### ✅ Dev Phase Checklist

Before moving to staging, ensure:

- [ ] All 3 services deploy successfully
- [ ] All pods are in `Running` state
- [ ] Health checks pass
- [ ] Inter-service communication works
- [ ] Database connections work
- [ ] Redis connections work
- [ ] Logs show no critical errors
- [ ] Performance is acceptable
- [ ] Team has tested functionality

---

## Phase 2: Staging Environment

**⚠️ Only proceed after dev is fully validated and stable**

### Step 1: Prepare Staging Configuration

1. **Update secrets** in `values/staging/common.yaml`:
   ```yaml
   secrets:
     DATABASE_URL: "postgresql://user:pass@your-staging-db:5432/rideshare_staging"
     REDIS_URL: "redis://your-staging-redis:6379"
   ```

2. **Review resource limits** in `values/staging/common.yaml`:
   - Ensure they match your staging infrastructure
   - Adjust HPA settings if needed

3. **Update Git repository URL** in `argocd/rideshare-applicationset-staging.yaml` (if not already done)

### Step 2: Create Staging Namespace and Secrets

```bash
# Namespace should already exist from namespaces.yaml, but verify
kubectl get namespace rideshare-staging || kubectl create namespace rideshare-staging

# Create ACR secret in staging namespace
kubectl create secret docker-registry acr-secret \
  --docker-server=teleiosacr.azurecr.io \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=rideshare-staging
```

### Step 3: Test Staging Configuration

```bash
# Test helm rendering for staging
helm template rideshare-rider-service helm/rideshare-microservice \
  -f values/rideshare-rider-service.yaml \
  -f values/staging/common.yaml

helm template rideshare-driver-service helm/rideshare-microservice \
  -f values/rideshare-driver-service.yaml \
  -f values/staging/common.yaml

helm template rideshare-email-service helm/rideshare-microservice \
  -f values/rideshare-email-service.yaml \
  -f values/staging/common.yaml
```

### Step 4: Deploy to Staging

```bash
# Deploy the staging ApplicationSet
kubectl apply -f argocd/rideshare-applicationset-staging.yaml
```

This creates:
- `rideshare-rider-service-staging`
- `rideshare-driver-service-staging`
- `rideshare-email-service-staging`

### Step 5: Monitor and Verify Staging

```bash
# Monitor deployment
kubectl get pods -n rideshare-staging -w

# Check ArgoCD apps
kubectl get applications -n argocd | grep staging

# Test services
kubectl get svc -n rideshare-staging
```

### Step 6: Staging Validation

Run your full test suite against staging:
- Functional tests
- Integration tests
- Performance tests
- Security tests

### ✅ Staging Phase Checklist

Before moving to production:

- [ ] All services deploy successfully in staging
- [ ] All automated tests pass
- [ ] Performance meets requirements
- [ ] No critical issues in logs
- [ ] Team has performed manual testing
- [ ] Stakeholder approval obtained
- [ ] Rollback plan documented

---

## Phase 3: Production Environment

**⚠️ Only proceed after staging is fully validated and approved**

### Step 1: Prepare Production Configuration

1. **Setup proper secrets management** - DO NOT use plaintext secrets!

   Option A: External Secrets Operator with Azure Key Vault
   ```bash
   # Install External Secrets Operator
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets external-secrets/external-secrets \
     -n external-secrets-system --create-namespace
   ```

   Option B: Sealed Secrets
   ```bash
   # Install Sealed Secrets
   helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
   helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
   ```

2. **Update production values** in `values/prod/common.yaml`:
   - Use specific version tags, not `latest`
   - Review all resource limits
   - Configure proper HPA thresholds
   - Set up monitoring and alerting

3. **Update image tags** in `values/prod/common.yaml`:
   ```yaml
   image:
     tag: "v1.0.0"  # Use specific version, NOT latest
   ```

### Step 2: Create Production Namespace and Secrets

```bash
# Create namespace
kubectl get namespace rideshare-prod || kubectl create namespace rideshare-prod

# Create ACR secret
kubectl create secret docker-registry acr-secret \
  --docker-server=teleiosacr.azurecr.io \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=rideshare-prod
```

### Step 3: Deploy to Production

```bash
# Deploy the production ApplicationSet
kubectl apply -f argocd/rideshare-applicationset-prod.yaml
```

**Note:** Production has auto-sync disabled. You must manually sync each application.

### Step 4: Manual Sync for Production

```bash
# Sync each service one at a time
argocd app sync rideshare-rider-service-prod
# Wait and verify before continuing

argocd app sync rideshare-driver-service-prod
# Wait and verify before continuing

argocd app sync rideshare-email-service-prod
# Wait and verify before continuing
```

### Step 5: Production Monitoring

```bash
# Watch deployment
kubectl get pods -n rideshare-prod -w

# Check all pods are healthy
kubectl get pods -n rideshare-prod

# Monitor logs
kubectl logs -f deployment/rideshare-rider-service -n rideshare-prod
```

### Step 6: Smoke Tests

Run smoke tests against production:
- Health check endpoints
- Critical user flows
- Monitor error rates
- Check metrics and dashboards

### Step 7: Traffic Migration (if migrating from Container Apps)

Gradually migrate traffic from Azure Container Apps to Kubernetes:

1. Start with 10% traffic to Kubernetes
2. Monitor for 24 hours
3. Increase to 50%
4. Monitor for 24 hours
5. Increase to 100%
6. Deprecate Azure Container Apps after stability confirmed

### ✅ Production Phase Checklist

- [ ] All services deployed successfully
- [ ] Health checks passing
- [ ] Monitoring and alerting configured
- [ ] Logs being collected
- [ ] Traffic routing working correctly
- [ ] Performance metrics acceptable
- [ ] No increase in error rates
- [ ] Team trained on Kubernetes operations
- [ ] Runbooks updated
- [ ] On-call team briefed

---

## Rollback Procedures

### Rollback Dev/Staging

```bash
# Rollback via ArgoCD
argocd app rollback <app-name> <revision>

# Or via kubectl
kubectl rollout undo deployment/<deployment-name> -n <namespace>
```

### Rollback Production

1. **Quick rollback** to previous version:
   ```bash
   kubectl rollout undo deployment/rideshare-rider-service -n rideshare-prod
   ```

2. **Complete rollback** - revert to Azure Container Apps:
   - Route traffic back to Container Apps
   - Keep Kubernetes running but idle
   - Investigate issues

3. **Fix-forward** (preferred for minor issues):
   - Fix the issue in git
   - Test in dev
   - Deploy to production

---

## Adding Services Mid-Migration

If you need to add a service during migration:

1. Add the service values file: `values/rideshare-new-service.yaml`
2. Add to the ApplicationSet files you've already deployed
3. Commit and push
4. ArgoCD will create the new applications automatically

---

## Common Issues and Solutions

### Issue: Pods stuck in ImagePullBackOff
**Solution:** Check ACR credentials and image name
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get secret acr-secret -n <namespace>
```

### Issue: CrashLoopBackOff
**Solution:** Check application logs and environment variables
```bash
kubectl logs <pod-name> -n <namespace> --previous
kubectl describe pod <pod-name> -n <namespace>
```

### Issue: Service can't connect to database
**Solution:** Check connection strings and network policies
```bash
# Verify secret
kubectl get secret <service-name>-secret -n <namespace> -o yaml

# Test connection from pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

### Issue: ArgoCD app OutOfSync
**Solution:** Check for manual changes or git repo issues
```bash
argocd app diff <app-name>
argocd app sync <app-name>
```

---

## Success Metrics

Track these metrics throughout migration:

- **Uptime**: Target 99.9%+
- **Error rate**: Should not increase
- **Response time**: Should match or improve
- **Resource utilization**: Monitor costs
- **Deployment frequency**: Should improve with GitOps

---

## Next Steps After Migration

1. Set up proper monitoring (Prometheus/Grafana)
2. Configure alerting (AlertManager/PagerDuty)
3. Implement proper secrets management
4. Set up CI/CD pipelines to build and push to ACR
5. Configure backup and disaster recovery
6. Document operational procedures
7. Train team on Kubernetes operations

---

## Support

- **ArgoCD UI**: Check for application status and sync issues
- **Kubernetes Dashboard**: For cluster-wide view
- **Logs**: Aggregate logs with ELK or similar
- **Metrics**: Monitor with Prometheus/Grafana
