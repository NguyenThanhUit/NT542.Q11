#!/bin/bash
set -e

echo "=== CIS 3.1.4 -  Ensure that the kubelet configuration file ownership is set to root:root ==="


echo ">> Checking kubelet config file ownership..."
OUTPUT=$(kubectl exec file-check -- stat -c %U:%G /host/etc/kubernetes/kubelet/config.json)

echo "Ownership: $OUTPUT"

if [ "$OUTPUT" != "root:root" ]; then
    echo "[FAIL]: kubelet config is not owned by root:root"
    kubectl delete pod file-check
    exit 1
fi

echo "[PASS]: kubelet config ownership is correct (root:root)"

exit 0
