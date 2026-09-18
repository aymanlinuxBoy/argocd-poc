#!/bin/bash

set -e

echo "================================================"
echo "Deploying Kubernetes Events Collection Setup"
echo "================================================"
echo ""

# Configuration
CLUSTER_CONTEXT="upstream"  # Change to your cluster context
MONITORING_NS="monitoring"
LOGGING_NS="logging"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Verify kubectl connectivity${NC}"
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to cluster. Please configure kubectl.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to cluster${NC}"
echo ""

echo -e "${YELLOW}Step 2: Create namespaces if not exist${NC}"
kubectl create namespace ${MONITORING_NS} --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ${LOGGING_NS} --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespaces ready${NC}"
echo ""

echo -e "${YELLOW}Step 3: Deploy Loki (Logging Backend)${NC}"
if helm repo list | grep -q grafana; then
    echo "Grafana repo already added"
else
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
fi

helm upgrade --install loki grafana/loki \
  -f loki-values.yaml \
  -n ${LOGGING_NS}
echo -e "${GREEN}✓ Loki deployed${NC}"
echo ""

echo -e "${YELLOW}Step 4: Deploy Loki External Service${NC}"
kubectl apply -f loki-external.yaml
echo -e "${GREEN}✓ Loki service exposed${NC}"
echo ""

echo -e "${YELLOW}Step 5: Deploy Alloy (Events & Logs Collection)${NC}"
helm upgrade --install alloy grafana/alloy \
  -f upstream-alloy-values.yaml \
  -n ${MONITORING_NS}
echo -e "${GREEN}✓ Alloy deployed${NC}"
echo ""

echo -e "${YELLOW}Step 6: Wait for pods to be ready${NC}"
echo "Waiting for Loki pod..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=loki \
  -n ${LOGGING_NS} \
  --timeout=300s 2>/dev/null || echo "Loki pod not ready yet"

echo "Waiting for Alloy pods..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=alloy \
  -n ${MONITORING_NS} \
  --timeout=300s 2>/dev/null || echo "Alloy pods not ready yet"
echo -e "${GREEN}✓ Pods deployed${NC}"
echo ""

echo -e "${YELLOW}Step 7: Verify Configuration${NC}"
echo "Checking Loki pods:"
kubectl get pods -n ${LOGGING_NS} -l app.kubernetes.io/name=loki

echo ""
echo "Checking Alloy pods:"
kubectl get pods -n ${MONITORING_NS} -l app.kubernetes.io/name=alloy

echo ""
echo -e "${YELLOW}Step 8: Test Event Collection${NC}"
echo "Getting Loki service endpoint..."
LOKI_ENDPOINT=$(kubectl get svc -n ${LOGGING_NS} loki-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].nodePort}' 2>/dev/null || echo "Not yet assigned")

echo "Loki Endpoint: ${LOKI_ENDPOINT}"
echo ""

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

echo "Next steps:"
echo "1. Check Alloy logs:"
echo "   kubectl logs -n ${MONITORING_NS} -l app.kubernetes.io/name=alloy --tail=50"
echo ""
echo "2. Port-forward to Loki:"
echo "   kubectl port-forward -n ${LOGGING_NS} svc/loki 3100:3100 &"
echo ""
echo "3. Query events in Loki:"
echo "   curl 'http://localhost:3100/loki/api/v1/query' \\"
echo "     --data-urlencode 'query={job=\"kubernetes-events\"}'"
echo ""
echo "4. Access Grafana:"
echo "   - Add Loki datasource: http://loki.${LOGGING_NS}:3100"
echo "   - Query: {job=\"kubernetes-events\"}"
echo ""
echo "5. Verify events are flowing:"
echo "   kubectl logs -n ${MONITORING_NS} -l app.kubernetes.io/name=alloy | grep -i event"
echo ""
