#!/bin/bash

echo "CIS BENCHMARK AUDIT: 4.3, 4.4, 4.5 (FIXED & OPTIMIZED)"

echo "[4.3.2] Checking: Namespace Network Isolation"

FAIL_COUNT=0
# Lấy danh sách NS, loại bỏ các NS hệ thống của K8s và AWS
NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -vE "^kube-|^amazon-|^default$")

for ns in $NAMESPACES; do
    NP_COUNT=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l)
    
    if [ "$NP_COUNT" -eq 0 ]; then
        echo " [WARN] Namespace '$ns' has NO Network Policies (Open traffic)."
        ((FAIL_COUNT++))
    else
        echo " [OK] Namespace '$ns' is protected ($NP_COUNT policies)."
    fi
done

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT 4.3.2: FAIL (Found $FAIL_COUNT unprotected user namespaces)"
else
    echo "RESULT 4.3.2: PASS (All user namespaces have policies)"
fi


echo "[4.4.1] Checking: Secrets used as Environment Variables"

SECRET_ENV_PODS=$(kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(
    (.spec.containers[].env[]?.valueFrom.secretKeyRef != null) or 
    (.spec.containers[].envFrom[]?.secretRef != null)
  ) | 
  select(.metadata.namespace != "kube-system") |
  " - NS: " + .metadata.namespace + " | Pod: " + .metadata.name
' | sort | uniq)

COUNT_441=0
if [ -n "$SECRET_ENV_PODS" ]; then
    # Đếm số dòng
    COUNT_441=$(echo "$SECRET_ENV_PODS" | wc -l)
fi

if [ "$COUNT_441" -gt 0 ]; then
    echo "Found pods using Secrets as Env Vars:"
    echo "$SECRET_ENV_PODS"
    echo "RESULT 4.4.1: FAIL (Found $COUNT_441 pods)"
else
    echo "RESULT 4.4.1: PASS (Secrets are mounted as files or not used in env)"
fi


echo "[4.5.2] Checking: Usage of 'default' namespace"

# Kiểm tra kỹ các workload phổ biến
RES_IN_DEFAULT=$(kubectl get pods,deployments,statefulsets,daemonsets,jobs,cronjobs -n default --no-headers 2>/dev/null)

if [ -n "$RES_IN_DEFAULT" ]; then
    echo "[WARN] Found resources in 'default' namespace:"
    echo "$RES_IN_DEFAULT"
    echo "RESULT 4.5.2: FAIL (Default namespace contains workloads)"
else
    echo "[OK] 'default' namespace is empty."
    echo "RESULT 4.5.2: PASS"
fi

echo ""
echo "AUDIT COMPLETED"
