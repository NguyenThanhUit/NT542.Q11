#!/bin/bash
set -e

CONFIG_PATH="/etc/kubernetes/kubelet/config.json"
HOST_PATH="/host${CONFIG_PATH}"
echo "=== CIS 3.1.3 - Ensure that the kubelet configuration file has permissions set to 644 or more restrictive ==="

echo ">> Checking kubelet config permissions at $CONFIG_PATH"

PERM=$(kubectl exec file-check -- stat -c %a $HOST_PATH 2>/dev/null || echo "NOT_FOUND")

echo "Permissions: $PERM"


if [ "$PERM" -gt 644 ]; then
    echo "[FAIL]: kubelet config permissions too open. Must be 644 or more restrictive."
    kubectl delete pod file-check
    exit 1
fi

echo "[PASS]: kubelet config permission is compliant ($PERM)"
exit 0
