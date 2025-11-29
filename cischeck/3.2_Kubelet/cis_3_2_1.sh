#!/bin/bash
set -e

echo "=== CIS 3.2.1 -  Ensure that the Anonymous Auth is Not Enabled ==="

NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

echo ">> Starting kubelet anonymous-auth check"

for NODE in $NODES; do
    echo
    echo "---- Checking node: $NODE ----"

    RAW=$(kubectl get --raw /api/v1/nodes/$NODE/proxy/configz 2>/dev/null || echo "ERR")

    if [[ "$RAW" == "ERR" ]]; then
        echo "Unable to get kubelet configz for node $NODE"
        exit 1
    fi

    ENABLED=$(echo "$RAW" | jq -r '.kubeletconfig.authentication.anonymous.enabled')

    if [[ "$ENABLED" == "false" ]]; then
        echo "[PASS]: anonymous-auth is DISABLED on $NODE"
    else
        echo "[FAIL]: anonymous-auth is ENABLED on $NODE"
        exit 1
    fi
done

echo
echo "ALL NODES COMPLIANT (anonymous-auth=false)"
exit 0
