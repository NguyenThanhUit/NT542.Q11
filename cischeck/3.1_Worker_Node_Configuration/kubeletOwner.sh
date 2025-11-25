#!/bin/bash

FILE="/etc/kubernetes/kubelet/config.json"


if [ ! -f "$FILE" ]; then
    echo "INFO: Kubeconfig file does not exist."
    exit 0
fi

OWNER=$(stat -c %U:%G "$FILE")

echo "Current ownership: $OWNER"

if [ "$OWNER" == "root:root" ]; then
    echo "PASS: Ownership is compliant"
else
    echo "FAIL: Permission is invalid"
    sudo chown root:root "$FILE"
    echo "Remediated: Ownership is now $(stat -c %U:%G "$FILE")"
fi
