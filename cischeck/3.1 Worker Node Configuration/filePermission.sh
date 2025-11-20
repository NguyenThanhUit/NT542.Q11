#!/bin/bash
FILE="/var/lib/kubelet/kubeconfig"

if [ ! -f "$FILE"]; then
    echo "Kubeconfig file does not exist."
    exit 0
fi

PERMISSION=$(stat -c %a "$FILE")

echo "Current perrmission: $PERMISSION"

if [ "$PERMISSION" -le 644]; then
    echo "Permission is compliant"
else
    echo "PASS: Need to fix permission"
    sudo chmod 644 "$FILE"
    echo "Current "$FILE" permission is $(stat -c %a "$FILE")"
fi
