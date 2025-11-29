#!/bin/bash

echo "=== CIS 3.2.2 - Ensure authorization-mode is not AlwaysAllow ==="


# 1. Detect kubelet process

KUBELET_PROCESS=$(ps -ef | grep kubelet | grep -v grep)

if [[ -z "$KUBELET_PROCESS" ]]; then
    echo "[FAIL] Kubelet process not found."
    exit 1
fi

echo "[INFO] Kubelet process:"
echo "$KUBELET_PROCESS"
echo

CLI_OK=0
FILE_OK=0


# 2. Check CLI arguments

echo "[INFO] Checking CLI arguments..."

# Authorization Mode
if echo "$KUBELET_PROCESS" | grep -q -- "--authorization-mode=AlwaysAllow"; then
    echo "[FAIL] CLI: authorization-mode=AlwaysAllow (NOT allowed)"
    CLI_OK=1
elif echo "$KUBELET_PROCESS" | grep -q -- "--authorization-mode=Webhook"; then
    echo "[PASS] CLI: authorization-mode=Webhook"
else
    echo "[INFO] CLI: No authorization-mode specified"
fi

# Authentication Webhook
if echo "$KUBELET_PROCESS" | grep -q -- "--authentication-token-webhook"; then
    echo "[PASS] CLI: authentication-token-webhook enabled"
else
    echo "[FAIL] CLI: authentication-token-webhook missing"
    CLI_OK=1
fi

echo


# 3. Check kubelet config file
CONFIG_FILE=$(echo "$KUBELET_PROCESS" | sed -n 's/.*--config=\([^ ]*\).*/\1/p')

if [[ -z "$CONFIG_FILE" ]]; then
    echo "[INFO] No kubelet config file used."
else
    echo "[INFO] Using kubelet config file: $CONFIG_FILE"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[FAIL] Config file not found."
        FILE_OK=1
    else
        # Authorization
        if grep -q '"mode": *"AlwaysAllow"' "$CONFIG_FILE"; then
            echo "[FAIL] Config: authorization.mode=AlwaysAllow"
            FILE_OK=1
        elif grep -q '"mode": *"Webhook"' "$CONFIG_FILE"; then
            echo "[PASS] Config: authorization.mode=Webhook"
        else
            echo "[INFO] authorization.mode not found in config"
        fi

        # Authentication webhook
        if grep -q '"webhook": *{ *"enabled": *true' "$CONFIG_FILE"; then
            echo "[PASS] Config: authentication.webhook enabled"
        else
            echo "[FAIL] Config: authentication.webhook missing"
            FILE_OK=1
        fi
    fi
fi

echo


if [[ "$CLI_OK" -eq 0 && "$FILE_OK" -eq 0 ]]; then
    echo "[PASS] CIS 3.2.2 Fully Compliant"
    exit 0
else
    echo "[FAIL] CIS 3.2.2 NOT Compliant — Fix Required"
    exit 1
fi
