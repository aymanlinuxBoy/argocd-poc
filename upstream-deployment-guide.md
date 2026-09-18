# Upstream Cluster - Kubernetes Events Collection Setup

## Status: READY TO DEPLOY

The upstream cluster currently has NO Kubernetes events collection deployed.

This guide shows how to deploy the same Alloy + Loki stack to the upstream cluster.

## Prerequisites
- Both kubeconfigs merged in `~/.kube/config`
- kubectl configured with both contexts

## Deployment Steps

### Step 1: Switch to Upstream Cluster
```bash
kubectl config use-context upstream
kubectl cluster-info
```

### Step 2: Create Namespaces
```bash
kubectl create namespace monitoring
kubectl create namespace logging
```

### Step 3: Deploy Loki to Upstream
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki \
  -f loki-values.yaml \
  -n logging
```

### Step 4: Expose Loki Service
```bash
kubectl apply -f loki-external.yaml
```

### Step 5: Deploy Alloy to Upstream
```bash
# Update upstream-alloy-values.yaml to reference upstream cluster
helm upgrade --install alloy grafana/alloy \
  -f upstream-alloy-values.yaml \
  -n monitoring
```

### Step 6: Verify Deployment
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
kubectl get pods -n logging -l app.kubernetes.io/name=loki
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=20
```

### Step 7: Query Events from Upstream
```bash
# Get Loki service IP/port
kubectl get svc -n logging loki-external

# Query for events
kubectl port-forward -n logging svc/loki-external 3100:30100 &
curl 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={job="kubernetes-events"}'
```

## Configuration Files Used

- `upstream-alloy-values.yaml` - Alloy configuration with upstream cluster label
- `loki-values.yaml` - Loki configuration (same for both clusters)
- `loki-external.yaml` - Loki external service (same for both clusters)

## After Deployment

Once deployed, you can:
- Query upstream events: `{job="kubernetes-events", cluster="upstream"}`
- Compare with downstream: `{job="kubernetes-events", cluster="downstream"}`
- Create dashboards showing both clusters

## Troubleshooting

### Alloy pod errors
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy
```

### Loki not receiving data
```bash
kubectl logs -n logging loki-0
```

### Events not appearing
- Wait 1-2 minutes for initial event discovery
- Check Kubernetes events exist: `kubectl get events -A`
