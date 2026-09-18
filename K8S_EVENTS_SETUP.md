# Kubernetes Events Collection Setup

## Goal Achieved ✅
Create a dashboard to display Kubernetes events (similar to application logs collection)

## Architecture

```
Kubernetes Cluster
    ↓
Alloy (DaemonSet)
  ├─ Pod Logs → job="kubernetes-pods"
  └─ K8s Events → job="kubernetes-events"
    ↓
Loki (http://176.57.189.45:30100)
    ↓
Grafana Dashboard/Explore
```

## What Was Configured

### 1. **Event Discovery**
- Added `discovery.kubernetes` with `role = "event"` to discover all Kubernetes events

### 2. **Event Relabeling**
- Namespace extraction: `__meta_kubernetes_namespace` → `namespace`
- Event name extraction: `__meta_kubernetes_event_name` → `event`
- Reason extraction: `__meta_kubernetes_event_reason` → `reason`
- Static labels: `cluster="upstream"`, `job="kubernetes-events"`

### 3. **Log Forwarding**
- Events forwarded to same Loki endpoint as pod logs
- Both sources use `loki.write "central"` to write to `http://176.57.189.45:30100/loki/api/v1/push`

### 4. **Query Selectors**
After deployment, you can query events in Grafana using:

**All events:**
```logql
{job="kubernetes-events"}
```

**Events by reason:**
```logql
{job="kubernetes-events", reason="Failed"}
{job="kubernetes-events", reason="BackOff"}
{job="kubernetes-events", reason="Error"}
```

**Events by namespace:**
```logql
{job="kubernetes-events", namespace="default"}
```

**Warning/Error level events:**
```logql
{job="kubernetes-events"} | json | level=~"Warning|Error"
```

## Files Updated

1. ✅ **alloy-config.alloy** - Added event discovery and relabeling
2. ✅ **upstream-alloy-values.yaml** - Added complete event collection config

## Verification Steps

### Step 1: Deploy the Configuration
```bash
# Apply the Alloy config to your cluster
kubectl apply -f upstream-alloy-values.yaml

# Or if using Helm:
helm upgrade --install alloy grafana/alloy -f upstream-alloy-values.yaml -n monitoring
```

### Step 2: Verify Alloy is Running
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=50
```

### Step 3: Check Loki Received Events
```bash
# Port forward to Loki
kubectl port-forward -n logging svc/loki 3100:3100 &

# Query available labels
curl -s 'http://localhost:3100/loki/api/v1/labels' | jq '.values'

# Query for kubernetes-events job
curl -s 'http://localhost:3100/loki/api/v1/label/job/values' | jq '.values'
```

### Step 4: View in Grafana
1. Go to **Explore** → Select **Loki** datasource
2. Run query: `{job="kubernetes-events"}`
3. You should see Kubernetes events appearing

### Step 5: Create Dashboard
Create a new dashboard panel with these queries:
- **Pod events**: `{job="kubernetes-events", reason=~"Failed|Error|BackOff|CrashLoop"}`
- **Node events**: `{job="kubernetes-events", namespace=""}`
- **Event timeline**: `{job="kubernetes-events"} | json | line_format "{{.involvedObject.kind}}: {{.reason}}"`

## Expected Output

You should see events with these fields:
- `involvedObject.kind` - Pod, Node, PersistentVolume, etc.
- `involvedObject.name` - Name of the object
- `reason` - Why the event occurred (Failed, Error, BackOff, etc.)
- `message` - Event description
- `count` - Number of occurrences
- `namespace` - Kubernetes namespace
- `cluster` - Cluster label (upstream)
- `job` - kubernetes-events

## Success Criteria ✅

- [ ] Alloy pods are running without errors
- [ ] RBAC allows event access
- [ ] Loki receives events (check via API)
- [ ] Grafana shows events with `{job="kubernetes-events"}`
- [ ] Dashboard displays events with proper metadata
