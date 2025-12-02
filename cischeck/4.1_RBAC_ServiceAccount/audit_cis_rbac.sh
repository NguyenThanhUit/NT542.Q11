#!/bin/bash

echo "[4.1.1] Checking: Cluster-admin usage"

# Lọc tìm đối tượng "lạ" giữ quyền admin
DATA=$(kubectl get clusterrolebindings -o json | jq -r '
  .items[]
  | select(.roleRef.name == "cluster-admin")
  | .subjects[]?
  | select(.name != "system:masters") 
  | select(.kind == "ServiceAccount" and .namespace == "kube-system" | not)
  | "TYPE: " + .kind + " | NAME: " + .name + " | NS: " + (.namespace // "-")
' | sort | uniq)

if [ -z "$DATA" ]; then
    echo "RESULT: PASS (Clean. Only system admins found.)"
else
    echo "RESULT: FAIL (Suspicious entities have cluster-admin):"
    echo "$DATA"
fi

echo "[4.1.2] Checking: Minimize access to secrets"

# Logic: Tìm Custom Role có quyền đọc secrets
# Loại bỏ: Role hệ thống (system:*) và Role mặc định (rbac-defaults)
RISKY_ROLES=$(kubectl get clusterroles -o json | jq -r '
  .items[]
  | select(.metadata.labels["kubernetes.io/bootstrapping"] != "rbac-defaults")
  | select(.metadata.name | test("^system:|^eks:|^aws-") | not)
  | select(.rules[]? | .resources? and (.resources[] | contains("secrets")) and .verbs? and (.verbs[] | test("get|list|watch|\\*")))
  | " - " + .metadata.name
' | sort | uniq)

if [ -z "$RISKY_ROLES" ]; then
    echo "RESULT: PASS (No custom roles have broad secret access)"
else
    echo "RESULT: FAIL (Review the following custom roles):"
    echo "$RISKY_ROLES"
fi

echo "[4.1.4] Checking: Minimize access to create pods"

# Logic: Tìm Custom Role có quyền tạo Pods
# Loại bỏ: Role hệ thống và Role mặc định (admin/edit/view của K8s)
RISKY_POD_ROLES=$(kubectl get clusterroles -o json | jq -r '
  .items[]
  | select(.metadata.labels["kubernetes.io/bootstrapping"] != "rbac-defaults")
  | select(.metadata.name | test("^system:|^eks:|^aws-") | not)
  | select(.rules[]? | .resources? and (.resources[] | contains("pods")) and .verbs? and (.verbs[] | test("create|\\*")))
  | " - " + .metadata.name
' | sort | uniq)

if [ -z "$RISKY_POD_ROLES" ]; then
    echo "RESULT: PASS (No suspicious custom roles can create pods)"
else
    echo "RESULT: FAIL (Found custom roles with 'create pod' permission):"
    echo "$RISKY_POD_ROLES"
fi

echo "[4.1.6] Checking: Service Account Tokens automount"

# Logic: Tìm SA tên là 'default' (trong non-system namespace) mà vẫn bật automount.
DATA=$(kubectl get serviceaccounts --all-namespaces -o json | jq -r '
  .items[]
  | select(.automountServiceAccountToken != false) 
  | select(.metadata.name == "default")
  | select(.metadata.namespace != "kube-system")
  | "Namespace: " + .metadata.namespace + " | SA: " + .metadata.name
' | sort | uniq)

if [ -z "$DATA" ]; then
    echo "RESULT: PASS (All default SAs are secured.)"
else
    COUNT=$(echo "$DATA" | wc -l)
    echo "RESULT: FAIL (Found $COUNT default Service Accounts with automount enabled):"
fi
