#!/bin/bash

set -e

echo "================================================"
echo "Verifying Kubernetes Events Collection"
echo "================================================"
echo ""

MONITORING_NS="monitoring"
LOGGING_NS="logging"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test 1: Check Alloy pods
echo -e "${YELLOW}[Test 1] Checking Alloy Pods${NC}"
ALLOY_PODS=$(kubectl get pods -n ${MONITORING_NS} -l app.kubernetes.io/name=alloy --no-headers 2>/dev/null | wc -l)
if [ "$ALLOY_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ Alloy pods running: $ALLOY_PODS pods${NC}"
    kubectl get pods -n ${MONITORING_NS} -l app.kubernetes.io/name=alloy
else
    echo -e "${RED}✗ No Alloy pods found${NC}"
    exit 1
fi
echo ""

# Test 2: Check Loki pods
echo -e "${YELLOW}[Test 2] Checking Loki Pods${NC}"
LOKI_PODS=$(kubectl get pods -n ${LOGGING_NS} -l app.kubernetes.io/name=loki --no-headers 2>/dev/null | wc -l)
if [ "$LOKI_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ Loki pods running: $LOKI_PODS pods${NC}"
    kubectl get pods -n ${LOGGING_NS} -l app.kubernetes.io/name=loki
else
    echo -e "${RED}✗ No Loki pods found${NC}"
fi
echo ""

# Test 3: Check Alloy logs for errors
echo -e "${YELLOW}[Test 3] Checking Alloy Logs for Errors${NC}"
ALLOY_POD=$(kubectl get pods -n ${MONITORING_NS} -l app.kubernetes.io/name=alloy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$ALLOY_POD" ]; then
    ERROR_COUNT=$(kubectl logs -n ${MONITORING_NS} "$ALLOY_POD" --tail=100 2>/dev/null | grep -i "error\|failed" | wc -l)
    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✓ No errors in Alloy logs${NC}"
    else
        echo -e "${YELLOW}⚠ Found $ERROR_COUNT error(s) in logs:${NC}"
        kubectl logs -n ${MONITORING_NS} "$ALLOY_POD" --tail=100 2>/dev/null | grep -i "error\|failed" | head -5
    fi
else
    echo -e "${RED}✗ Could not get Alloy pod${NC}"
fi
echo ""

# Test 4: Check if events discovery is configured
echo -e "${YELLOW}[Test 4] Checking Event Discovery Configuration${NC}"
EVENTS_CONFIG=$(kubectl logs -n ${MONITORING_NS} "$ALLOY_POD" --tail=200 2>/dev/null | grep -i "kubernetes.*events\|event.*discovery" | wc -l)
if [ "$EVENTS_CONFIG" -gt 0 ]; then
    echo -e "${GREEN}✓ Event discovery configured${NC}"
else
    echo -e "${YELLOW}⚠ Event discovery not found in logs (may not be loaded yet)${NC}"
fi
echo ""

# Test 5: Query Loki API
echo -e "${YELLOW}[Test 5] Testing Loki API Connectivity${NC}"
LOKI_SVC="loki.${LOGGING_NS}.svc.cluster.local:3100"
LOKI_TEST=$(kubectl run -n ${LOGGING_NS} loki-test --image=curlimages/curl --rm -i --restart=Never -- \
    curl -s "http://${LOKI_SVC}/loki/api/v1/labels" 2>/dev/null | grep -o '"values"' || echo "")

if [ -n "$LOKI_TEST" ]; then
    echo -e "${GREEN}✓ Loki API is responding${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify Loki API response${NC}"
fi
echo ""

# Test 6: Check for kubernetes-events job label
echo -e "${YELLOW}[Test 6] Checking for Kubernetes Events in Loki${NC}"
EVENTS_DATA=$(kubectl run -n ${LOGGING_NS} loki-query --image=curlimages/curl --rm -i --restart=Never -- \
    curl -s "http://${LOKI_SVC}/loki/api/v1/query" \
    --data-urlencode 'query={job="kubernetes-events"}' 2>/dev/null | grep -o '"kubernetes-events"' || echo "")

if [ -n "$EVENTS_DATA" ]; then
    echo -e "${GREEN}✓ Kubernetes events data found in Loki!${NC}"
else
    echo -e "${YELLOW}⚠ No events data yet (may be collecting)${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}Verification Complete${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

echo "Troubleshooting tips:"
echo "1. Check Alloy pod logs:"
echo "   kubectl logs -n ${MONITORING_NS} -l app.kubernetes.io/name=alloy --tail=100"
echo ""
echo "2. Verify RBAC permissions:"
echo "   kubectl get clusterrole alloy -o yaml | grep -A5 events"
echo ""
echo "3. Port-forward to Loki and test directly:"
echo "   kubectl port-forward -n ${LOGGING_NS} svc/loki 3100:3100 &"
echo "   curl 'http://localhost:3100/loki/api/v1/query?query={job=\"kubernetes-events\"}'"
echo ""
echo "4. Check if events are being discovered:"
echo "   kubectl get events -A"
echo ""
