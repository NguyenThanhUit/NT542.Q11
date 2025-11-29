#!/bin/bash
set -e

CONFIG_PATH="/var/lib/kubelet/kubeconfig"
HOST_PATH="/host${CONFIG_PATH}"

echo "=== CIS 3.1.2 -  Ensure that the kubelet kubeconfig file ownership is set to root:root ==="



echo ">> Checking ownership of kubelet kubeconfig: $CONFIG_PATH"

OWNER=$(kubectl exec file-check -- stat -c %U:%G $HOST_PATH 2>/dev/null || echo "NOT_FOUND")


echo "Owner: $OWNER"

if [ "$OWNER" != "root:root" ]; then
    echo "[FAIL]: kubelet kubeconfig ownership must be root:root"
    kubectl delete pod file-check
    exit 1
fi

echo "[PASS]: kubelet kubeconfig ownership is correct (root:root)"
exit 0
