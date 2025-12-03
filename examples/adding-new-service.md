# Example: Adding a New Microservice

This guide shows how to add a new microservice to the ArgoCD ApplicationSet deployment.

## Scenario

You want to add `rideshare-payment-service` to your deployment.

## Steps

### 1. Create Service Values File

Create `values/rideshare-payment-service.yaml`:

```yaml
# Service-specific values for rideshare-payment-service
name: rideshare-payment-service
namespace: rideshare

image:
  repository: rideshare-payment-service
  tag: "latest"

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

replicaCount: 2

config:
  NODE_ENV: "production"
  PORT: "3000"
  LOG_LEVEL: "info"
  SERVICE_NAME: "rideshare-payment-service"
  # Payment service specific configs
  PAYMENT_GATEWAY_URL: "https://api.paymentgateway.com"
  # Inter-service communication
  RIDER_SERVICE_URL: "http://rideshare-rider-service.rideshare.svc.cluster.local"
  DRIVER_SERVICE_URL: "http://rideshare-driver-service.rideshare.svc.cluster.local"

secrets:
  DATABASE_URL: ""
  REDIS_URL: ""
  # Payment-specific secrets
  STRIPE_API_KEY: ""
  STRIPE_WEBHOOK_SECRET: ""

ingress:
  enabled: false
```

### 2. Update ApplicationSet

Edit `argocd/rideshare-applicationset.yaml` and add the new service to the list:

```yaml
generators:
  - matrix:
      generators:
        - list:
            elements:
              - service: rideshare-rider-service
              - service: rideshare-driver-service
              - service: rideshare-email-service
              - service: rideshare-payment-service  # Add this line
```

### 3. Commit and Push

```bash
git add values/rideshare-payment-service.yaml
git add argocd/rideshare-applicationset.yaml
git commit -m "Add rideshare-payment-service to deployment"
git push
```

### 4. Verify

ArgoCD will automatically detect the changes and create 3 new applications:
- `rideshare-payment-service-dev`
- `rideshare-payment-service-staging`
- `rideshare-payment-service-prod`

Check the applications:

```bash
kubectl get applications -n argocd | grep payment

# Wait for sync, then check pods
kubectl get pods -n rideshare-dev | grep payment
kubectl get pods -n rideshare-staging | grep payment
kubectl get pods -n rideshare-prod | grep payment
```

## Service-Specific Environment Overrides (Optional)

If a service needs different configuration in specific environments, create environment-specific overrides:

### Create `values/dev/rideshare-payment-service.yaml`:

```yaml
# Dev-specific overrides for payment service
config:
  PAYMENT_GATEWAY_URL: "https://sandbox.paymentgateway.com"

secrets:
  STRIPE_API_KEY: "sk_test_..."
```

### Update ApplicationSet to use the override:

```yaml
helm:
  valueFiles:
    - ../../values/{{service}}.yaml
    - ../../values/{{env}}/common.yaml
    - ../../values/{{env}}/{{service}}.yaml  # Add this line
```

This will only be applied if the file exists, so it's safe to add for all services.

## Testing Before Deployment

Test the Helm rendering locally:

```bash
# Test for dev environment
helm template rideshare-payment-service helm/rideshare-microservice \
  -f values/rideshare-payment-service.yaml \
  -f values/dev/common.yaml

# Test for production environment
helm template rideshare-payment-service helm/rideshare-microservice \
  -f values/rideshare-payment-service.yaml \
  -f values/prod/common.yaml
```

## Common Issues

### Application not created
- Check ApplicationSet is deployed: `kubectl get applicationset -n argocd`
- Check for errors: `kubectl describe applicationset rideshare-microservices -n argocd`

### Application stuck in sync
- Check values files are valid YAML
- Verify image exists in ACR: `az acr repository show -n teleiosacr --repository rideshare-payment-service`
- Check ArgoCD application: `argocd app get rideshare-payment-service-dev`

### Pods not starting
- Check image pull secrets: `kubectl get secrets -n rideshare-dev | grep acr`
- Check pod logs: `kubectl logs -f deployment/rideshare-payment-service -n rideshare-dev`
- Check events: `kubectl get events -n rideshare-dev --sort-by='.lastTimestamp'`
