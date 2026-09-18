# Kubernetes Events Collection - Multi-Cluster Status

**Date:** 2026-09-18  
**Status:** ✅ BOTH CLUSTERS SUPPORTED

---

## 🎯 Current Deployment Status

### UPSTREAM Cluster (k3s @ 161.97.180.210:6443)
| Component | Status | Action |
|-----------|--------|--------|
| Alloy | ❌ NOT DEPLOYED | [Deploy Guide →](upstream-deployment-guide.md) |
| Loki | ❌ NOT DEPLOYED | Ready to deploy |
| Events Collection | ❌ DISABLED | See deployment guide |

### DOWNSTREAM Cluster (RKE2 @ 176.57.189.45:6443)
| Component | Status | Pods | Version |
|-----------|--------|------|---------|
| Alloy | ✅ RUNNING | 3 | Latest |
| Loki | ✅ RUNNING | 5+ | 3.6.12 |
| Events Collection | ✅ ACTIVE | Collecting | Working |

---

## 📁 Configuration Files (Support Both Clusters)

### Alloy Configuration
- **`upstream-alloy-values.yaml`** - Helm values for both clusters
  - Kubernetes pod discovery
  - Kubernetes events discovery ✨ NEW
  - Proper relabeling with cluster labels
  - Loki forwarding configured

### Loki Configuration  
- **`loki-values.yaml`** - Works for both clusters
  - Monolithic deployment
  - Local filesystem storage
  - Ready for events + logs

### Service Configuration
- **`loki-external.yaml`** - Expose Loki (both clusters)
  - NodePort 30100
  - For external access

---

## 🚀 Deployment Overview

### DOWNSTREAM (Currently Deployed ✅)
```
Kubernetes Events → Alloy → Loki → Grafana
✅ ACTIVE            ✅       ✅       Ready
```

**Events Query:**
```logql
{job="kubernetes-events", cluster="downstream"}
```

### UPSTREAM (Ready to Deploy)
```
Kubernetes Events → Alloy → Loki → Grafana
❌ PENDING        Waiting  Waiting  Ready
```

**To deploy:** See [upstream-deployment-guide.md](upstream-deployment-guide.md)

---

## 📊 What's Collected

### Pod Logs
- **Label:** `job="kubernetes-pods"`
- **Metadata:** namespace, pod, container, cluster
- **Status:** ✅ Collecting (downstream only)

### Kubernetes Events  
- **Label:** `job="kubernetes-events"` ✨
- **Metadata:** namespace, reason, event name, cluster
- **Status:** ✅ Collecting (downstream only)

**Example Event Data:**
```json
{
  "involvedObject.kind": "Pod",
  "involvedObject.name": "my-app-xyz",
  "reason": "BackOff",
  "message": "Back-off pulling image",
  "cluster": "downstream",
  "namespace": "default"
}
```

---

## 🎛️ Cluster Switching

Both clusters are now in the kubectl dropdown:

```bash
# List all contexts
kubectl config get-contexts

# Switch to upstream
kubectl config use-context upstream
kubectl get nodes

# Switch to downstream
kubectl config use-context downstream
kubectl get nodes
```

---

## ✅ Next Steps

### Immediate (Optional)
- [ ] Deploy to UPSTREAM cluster (see guide below)
- [ ] Create unified dashboard showing both clusters

### After UPSTREAM Deployment
- [ ] Query events from both clusters
- [ ] Compare event streams
- [ ] Create cross-cluster alerting rules

---

## 📋 Deployment Checklist

### DOWNSTREAM (Already Done ✅)
- [x] Alloy deployed
- [x] Loki deployed
- [x] Pod logs collecting
- [x] Kubernetes events collecting
- [x] Grafana ready

### UPSTREAM (Ready to Deploy)
- [ ] Follow [upstream-deployment-guide.md](upstream-deployment-guide.md)
- [ ] Deploy Loki
- [ ] Deploy Alloy
- [ ] Verify events collection
- [ ] Test queries

---

## 🔍 Verification Commands

### Check DOWNSTREAM Status
```bash
kubectl config use-context downstream

# Check pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
kubectl get pods -n logging -l app.kubernetes.io/name=loki

# Check logs are flowing
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=20
```

### Check UPSTREAM Status
```bash
kubectl config use-context upstream

# Should be empty (not deployed yet)
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
kubectl get pods -n logging -l app.kubernetes.io/name=loki
```

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| `CLUSTER-STATUS.md` | This file - Current status of both clusters |
| `upstream-deployment-guide.md` | Step-by-step guide to deploy to upstream |
| `README_K8S_EVENTS.md` | General K8s events collection guide |
| `DEPLOYMENT_STATUS.md` | Deployment architecture and checklist |

---

## 🎯 Success Criteria

- [x] Both clusters accessible via kubectl dropdown
- [x] DOWNSTREAM: Alloy collecting logs + events ✅
- [ ] UPSTREAM: Ready for deployment
- [ ] Both clusters queryable in Grafana (once both deployed)

---

## Git Status

All configuration files committed to repository:
```
✅ upstream-alloy-values.yaml
✅ loki-values.yaml
✅ loki-external.yaml
✅ Application deployment configs
```

Ready for multi-cluster Kubernetes events observability! 🚀

---

**Last Updated:** 2026-09-18  
**Clusters Configured:** 2 (upstream + downstream)  
**Events Collection Status:** ✅ 1/2 clusters active
