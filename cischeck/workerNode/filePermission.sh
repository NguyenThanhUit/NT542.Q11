#!/bin/bash
FILE="/var/lib/kubelet/kubeconfig"

if [ ! -f "$FILE"]; then
    echo "Kubeconfig file does not exist."
    exit 0
fi

PERMISSION=$(stat -c %a "$FILE")

echo "Current perrmission: $PERMISSION"

if [ "$PERMISSION" -le ]