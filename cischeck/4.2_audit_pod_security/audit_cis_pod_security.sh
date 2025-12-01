#!/bin/bash

echo "CIS BENCHMARK AUDIT: 4.2 POD SECURITY STANDARDS (FIXED)"
echo "Cluster Context: $(kubectl config current-context)"
print_line() { echo "----------------------------------------------------------------"; }

# ==============================================================================
# 4.2.1 Minimize the admission of privileged containers
# ==============================================================================
echo ""
echo "[4.2.1] Checking: Minimize the admission of privileged containers"
print_line

# Lưu kết quả vào biến trước (tránh lỗi subshell)
# Lọc: Lấy tất cả, nhưng đánh dấu nếu là namespace hệ thống
PRIV_DATA=$(kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.containers[].securityContext.privileged == true) |
  .metadata.namespace + " " + .metadata.name
')

FAIL_COUNT=0
SYSTEM_COUNT=0

if [ -z "$PRIV_DATA" ]; then
    echo "RESULT 4.2.1: PASS (No privileged containers found)"
else
    # Đọc từng dòng từ biến
    while read -r ns pod; do
        # Kiểm tra xem có phải namespace hệ thống không
        if [[ "$ns" == "kube-system" ]] || [[ "$ns" == "amazon-cloudwatch" ]]; then
            echo "[INFO] System Exemption: $ns/$pod (Allowed)"
            ((SYSTEM_COUNT++))
        else
            echo "[WARN] VIOLATION FOUND: $ns/$pod"
            ((FAIL_COUNT++))
        fi
    done <<< "$PRIV_DATA"

    echo "--- Summary ---"
    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo "RESULT 4.2.1: FAIL (Found $FAIL_COUNT application pods using Privileged mode)"
    else
        echo "RESULT 4.2.1: PASS (Only system pods are privileged)"
    fi
fi

# ==============================================================================
# 4.2.2 Minimize admission of containers sharing hostPID
# ==============================================================================
echo ""
echo "[4.2.2] Checking: Minimize the admission of containers sharing hostPID"
print_line

PID_DATA=$(kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.hostPID == true) |
  .metadata.namespace + " " + .metadata.name
')

FAIL_COUNT=0
SYSTEM_COUNT=0

if [ -z "$PID_DATA" ]; then
    echo "RESULT 4.2.2: PASS (No HostPID pods found)"
else
    while read -r ns pod; do
        if [[ "$ns" == "kube-system" ]] || [[ "$ns" == "amazon-cloudwatch" ]]; then
            echo "[INFO] System Exemption: $ns/$pod (Allowed)"
            ((SYSTEM_COUNT++))
        else
            echo "[WARN] VIOLATION FOUND: $ns/$pod"
            ((FAIL_COUNT++))
        fi
    done <<< "$PID_DATA"

    echo "--- Summary ---"
    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo "RESULT 4.2.2: FAIL (Found $FAIL_COUNT application pods using HostPID)"
    else
        echo "RESULT 4.2.2: PASS (Only system pods use HostPID)"
    fi
fi

echo ""
echo "AUDIT COMPLETED"