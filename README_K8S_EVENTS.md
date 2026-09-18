# Kubernetes Events Collection - Complete Implementation

## 📋 Overview

This implementation adds **Kubernetes events collection** to your observability stack, complementing your existing **application logs** collection.

### What You Get:
- ✅ Kubernetes events collected via Alloy
- ✅ Events stored in Loki alongside application logs
- ✅ Queryable via Grafana with label `job="kubernetes-events"`
- ✅ Full event metadata (namespace, reason, involved object, etc.)

---

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
cd /Users/ayman.aly/argocd-poc

# 1. Deploy everything automatically
./DEPLOY.sh

# 2. Wait 1-2 minutes for pods to be ready

# 3. Verify the deployment
./VERIFY.sh
```

### Option 2: Manual Step-by-Step Deployment

```bash
# 1. Create namespaces
kubectl create namespace monitoring
kubectl create namespace logging

# 2. Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 3. Deploy Loki
helm upgrade --install loki grafana/loki \
  -f loki-values.yaml \
  -n logging

# 4. Expose Loki
kubectl apply -f loki-external.yaml

# 5. Deploy Alloy (events + logs collection)
helm upgrade --install alloy grafana/alloy \
  -f upstream-alloy-values.yaml \
  -n monitoring
```

---

## ✅ Verification Steps

### Check 1: Pods Running
```bash
# Loki should be running
kubectl get pods -n logging -l app.kubernetes.io/name=loki

# Alloy DaemonSet should have pods on all nodes
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
```

### Check 2: Alloy Logs
```bash
# Check for any errors
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=50

# Should see logs mentioning:
# - "kubernetes.discovery" or discovery.kubernetes
# - "loki.source.kubernetes"
# - Event discovery configured
```

### Check 3: Loki API
```bash
# Port forward to Loki
kubectl port-forward -n logging svc/loki 3100:3100 &

# Query available job labels
curl -s 'http://localhost:3100/loki/api/v1/label/job/values' | jq '.values'

# Should see: "kubernetes-events", "kubernetes-pods"
```

### Check 4: Events in Loki
```bash
# Query for events data
curl -s 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={job="kubernetes-events"}' | jq

# Should return event data with structure like:
# {
#   "involvedObject": {"kind": "Pod", "name": "...", "namespace": "..."},
#   "reason": "Failed",
#   "message": "...",
#   "count": N,
#   ...
# }
```

### Check 5: Grafana Query
1. Open Grafana → **Explore** → Select **Loki** datasource
2. Run query: `{job="kubernetes-events"}`
3. Should see events appearing in real-time

---

## 📊 Common Queries

Use these queries in Grafana Explore or Loki:

### All Events
```logql
{job="kubernetes-events"}
```

### Failed/Error Events
```logql
{job="kubernetes-events", reason=~"Failed|Error|BackOff|CrashLoop"}
```

### Events by Namespace
```logql
{job="kubernetes-events", namespace="default"}
```

### Pod Events
```logql
{job="kubernetes-events"} | json | involvedObject_kind="Pod"
```

### Node Events
```logql
{job="kubernetes-events"} | json | involvedObject_kind="Node"
```

### Recent Warnings
```logql
{job="kubernetes-events"} | json | level="Warning"
```

### Parse and Format
```logql
{job="kubernetes-events"} 
| json 
| line_format "{{.involvedObject.kind}}/{{.involvedObject.name}}: {{.reason}} - {{.message}}"
```

---

## 📁 Configuration Files

| File | Purpose |
|------|---------|
| `upstream-alloy-values.yaml` | Alloy Helm values - pod logs + K8s events |
| `alloy-config.alloy` | Raw Alloy config (standalone reference) |
| `loki-values.yaml` | Loki Helm values - log storage backend |
| `loki-external.yaml` | NodePort service to access Loki externally |
| `monitoring-rke2-values.yaml` | RKE2 monitoring configuration |
| `prometheus-ingress.yaml` | Prometheus external access |
| `thanos-query.yaml` | Thanos query configuration |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│         Kubernetes Cluster                       │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────────────────────────────────┐   │
│  │  Alloy DaemonSet (monitoring ns)       │   │
│  │  ├─ discovery.kubernetes "pods"       │   │
│  │  │  └─ loki.source.kubernetes         │   │
│  │  │     (job="kubernetes-pods")        │   │
│  │  │                                     │   │
│  │  ├─ discovery.kubernetes "events"     │   │
│  │  │  └─ loki.source.kubernetes         │   │
│  │  │     (job="kubernetes-events")      │   │
│  │  └─ loki.write "central"              │   │
│  │     └─ http://loki:3100/loki/api/...  │   │
│  └────────────────────────────────────────┘   │
│                     ↓                           │
│  ┌────────────────────────────────────────┐   │
│  │  Loki (logging ns)                     │   │
│  │  ├─ Receives logs and events           │   │
│  │  ├─ Stores in local filesystem         │   │
│  │  └─ Exposes via NodePort 30100         │   │
│  └────────────────────────────────────────┘   │
│                                                  │
└─────────────────────────────────────────────────┘
                     ↓
         ┌──────────────────────┐
         │  Grafana             │
         │  ├─ Loki Datasource  │
         │  └─ Dashboards       │
         └──────────────────────┘
```

---

## 🔍 Troubleshooting

### No events appearing?

1. **Check Alloy is running:**
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
   ```

2. **Check for RBAC errors:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=alloy | grep -i "rbac\|forbidden\|permission"
   ```

3. **Verify RBAC is configured:**
   ```bash
   kubectl get clusterrole alloy -o yaml | grep -i event
   ```

4. **Check if events exist in cluster:**
   ```bash
   kubectl get events -A
   ```

5. **Restart Alloy to pick up new config:**
   ```bash
   kubectl rollout restart daemonset alloy -n monitoring
   ```

### Events empty but pods exist?

Events may take time to appear after deployment. Give it 2-3 minutes and check again.

### Loki service not accessible?

```bash
# Check service is created
kubectl get svc -n logging

# Check NodePort is assigned
kubectl get svc loki-external -n logging -o wide

# Port forward for testing
kubectl port-forward -n logging svc/loki 3100:3100 &
```

---

## 📝 Status

| Component | Status |
|-----------|--------|
| Configuration | ✅ Complete |
| Git Commit | ✅ d6360da |
| Helm Values | ✅ Ready |
| Documentation | ✅ Complete |
| Deployment Scripts | ✅ Ready |
| **Cluster Deployment** | ⏳ **Pending** |

**Next: Run `./DEPLOY.sh` to apply to your upstream cluster**

---

## 📞 Support

For issues:
1. Check logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=alloy`
2. Run verification: `./VERIFY.sh`
3. Check event discovery: `kubectl get events -A`

---

**Last Updated:** 2026-09-18  
**Git Commit:** d6360da  
**Status:** Ready for Deployment
