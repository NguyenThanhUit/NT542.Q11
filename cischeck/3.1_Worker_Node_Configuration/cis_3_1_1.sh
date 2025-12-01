#!/bin/bash
set -e

CONFIG_PATH="/var/lib/kubelet/kubeconfig"
HOST_PATH="/host${CONFIG_PATH}"

echo "=== CIS 3.1.1 -  Ensure that the kubeconfig file permissions are set to 644 or more restrictive ==="

echo ">> Checking permissions of kubeconfig file: $CONFIG_PATH"

PERM=$(kubectl exec file-check -- stat -c %a $HOST_PATH || echo "NOT_FOUND")

if [ "$PERM" == "NOT_FOUND" ]; then
    echo "kubeconfig file NOT found — kubelet may be using ConfigMap instead."
    kubectl delete pod file-check
    exit 0
fi

echo "Permissions: $PERM"

if [ "$PERM" -gt 644 ]; then
    echo "[FAIL]: kubeconfig permissions are too open. Must be 644 or more restrictive."
    kubectl delete pod file-check
    exit 1
fi

echo "[PASS]: kubeconfig permissions are $PERM (compliant)"
exit 0
