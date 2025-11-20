#!/bin/bash

KUBELET_PROCESS=$(ps -ef | grep kubelet | grep -v grep)
echo "INFO: Check kubelet command line arguments..."
echo "$KUBELET_PROCESS"

if echo "$KUBELET_PROCESS" | grep -q --"--anonymous-auth=false"; then
    echo "[OK] anonymous-auth=false is disabled"
    CLI_OK=true
else
    echo "[WARN] CLI: anonymous-auth is NOT disabled"
    CLI_OK=FALSE
fi

# 3. Tìm file kubelet config từ --config ARG
CONFIG_FILE=$(echo "$KUBELET_PROCESS" | sed -n 's/.*--config[ =]\([^ ]*\).*/\1/p')

if [[ -z "$CONFIG_FILE" ]]; then
    echo "[ERROR] Could not detect kubelet --config file!"
    exit 1
fi

echo "[INFO] Kubelet config file: $CONFIG_FILE"
echo

# 4. Kiểm tra trong file config JSON
echo "[INFO] Checking config file for anonymous-auth setting..."

if grep -q '"anonymous"' "$CONFIG_FILE"; then
    if grep -q '"enabled": *false' "$CONFIG_FILE"; then
        echo "[OK] Config: anonymous-auth disabled in kubelet config."
        FILE_OK=true
    else
        echo "[WARN] Config: anonymous-auth still enabled!"
        FILE_OK=false
    fi
else
    echo "[WARN] Config file does not contain anonymous authentication block."
    FILE_OK=false
fi

# 5. Nếu cả CLI và FILE đều ok → pass
if $CLI_OK && $FILE_OK; then
    echo
    echo "[PASS] CIS 3.2.1 compliant."
    exit 0
fi

# 6. Remediation: Disable anonymous auth bằng cách chỉnh config file
echo
echo "[ACTION] Applying remediation to disable anonymous-auth..."

# Backup file
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
echo "[INFO] Backup created at ${CONFIG_FILE}.bak"

# Nếu block chưa tồn tại, thêm block vào cuối file
if ! grep -q '"authentication"' "$CONFIG_FILE"; then
    echo "[INFO] Adding authentication block..."
    sed -i 's/^{/{\n  "authentication": { "anonymous": { "enabled": false } },/' "$CONFIG_FILE"
else
    # Sửa block có sẵn
    echo "[INFO] Updating existing anonymous-auth block..."
    sed -i 's/"anonymous":[^{]*{[^}]*}/"anonymous": { "enabled": false }/' "$CONFIG_FILE"
fi

echo "[INFO] Restarting kubelet..."
systemctl restart kubelet

echo "[DONE] Anonymous Auth disabled and kubelet restarted."