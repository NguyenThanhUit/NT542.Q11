#!/bin/bash
set -e

echo "=== CIS 3.2.2 - Ensure authorization-mode is NOT AlwaysAllow ==="

NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

for NODE in $NODES; do
    echo
    echo "---- Checking node: $NODE ----"

    CFG=$(kubectl get --raw /api/v1/nodes/$NODE/proxy/configz 2>/dev/null || echo "ERR")

    if [[ "$CFG" == "ERR" ]]; then
        echo "[ERROR] Unable to read kubelet config from $NODE"
        exit 1
    fi

    AUTH_MODE=$(echo "$CFG" | jq -r '.kubeletconfig.authorization.mode')
    WEBHOOK_AUTH=$(echo "$CFG" | jq -r '.kubeletconfig.authentication.webhook.enabled')

    # Check Authorization Mode
    if [[ "$AUTH_MODE" == "Webhook" ]]; then
        echo "[PASS] authorization.mode=Webhook"
    else
        echo "[FAIL] authorization.mode is not Webhook (actual: $AUTH_MODE)"
        exit 1
    fi

    # Check authentication webhook
    if [[ "$WEBHOOK_AUTH" == "true" ]]; then
        echo "[PASS] authentication.webhook.enabled=true"
    else
        echo "[FAIL] authentication.webhook is not enabled (actual: $WEBHOOK_AUTH)"
        exit 1
    fi
done

echo
echo "ALL NODES COMPLIANT ✔"
exit 0
