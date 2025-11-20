#!/bin/bash

FILE='/etc/kubernetes/kubelet/config.json'

if [! -f "$FILE"]; then
    echo "Kubelet config does not exist"
    exit 0
fi

PERMISSION=$(stat -c %a "$FILE")

echo "Current permission: "$PERMISSION""

if [ "$PERMISSION" -le 644]; then
    echo "PASS: Permission is valid."
else 
    echo "FAIL: Permission is invalid, remediating..."
    sudo chmod 644 "$FILE"
    echo "Permission is now $(stat -c %a "$FILE")"
fi