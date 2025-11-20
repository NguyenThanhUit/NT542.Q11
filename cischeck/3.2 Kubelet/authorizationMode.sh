#!/bin/bash

echo "=== CIS 3.2.2 - Check Kubelet authorization-mode ==="

# 1. Lấy process kubelet
KUBELET_PROCESS=$(ps -ef | grep kubelet | grep -v grep)

if [ -z "$KUBELET_PROCESS" ]; then
    echo "[FAIL] Kubelet process not found."
    exit 1
fi

echo "[INFO] Kubelet process found."
echo "$KUBELET_PROCESS"

CLI_OK=true
FILE_OK=true

# 2. Kiểm tra CLI arguments
if echo "$KUBELET_PROCESS" | grep -q -- "--authorization-mode=AlwaysAllow"; then
    CLI_OK=false
    echo "[FAIL] CLI sets --authorization-mode=AlwaysAllow (NOT allowed)"
elif echo "$KUBELET_PROCESS" | grep -q -- "--authorization-mode=Webhook"; then
    echo "[PASS] CLI sets --authorization-mode=Webhook"
else
    echo "[INFO] CLI does not define authorization-mode (checking config file)"
fi

# 3. Lấy đường dẫn file cấu hình kubelet
CONFIG_FILE=$(echo "$KUBELET_PROCESS" | sed -n 's/.*--config=\([^ ]*\).*/\1/p')

if [ -z "$CONFIG_FILE" ]; then
    echo "[INFO] No --config file found. Using CLI only."
else
    echo "[INFO] Kubelet config file: $CONFIG_FILE"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "[FAIL] Config file not found: $CONFIG_FILE"
        FILE_OK=false
    else
        # Kiểm tra nội dung file
        if grep -q '"mode": *"AlwaysAllow"' "$CONFIG_FILE"; then
            echo "[FAIL] Config file sets authorization.mode=AlwaysAllow"
            FILE_OK=false
        elif grep -q '"mode": *"Webhook"' "$CONFIG_FILE"; then
            echo "[PASS] Config file sets authorization.mode=Webhook"
        else
            echo "[INFO] Config file does not define authorization.mode"
        fi
    fi
fi

# 4. Kết luận
if $CLI_OK && $FILE_OK; then
    echo "------------------------------------------"
    echo "[PASS] CIS 3.2.2 Passed – Authorization is secure."
    echo "------------------------------------------"
    exit 0
else
    echo "------------------------------------------"
    echo "[FAIL] CIS 3.2.2 Failed – Fix required."
    echo "------------------------------------------"
    exit 1
fi
