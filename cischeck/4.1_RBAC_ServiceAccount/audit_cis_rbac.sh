#!/bin/bash

echo "CIS BENCHMARK AUDIT: 4.1 RBAC AND SERVICE ACCOUNTS (FIXED OUTPUT)"
echo "Cluster Context: $(kubectl config current-context)"
echo "----------------------------------------------------------------"

# ==============================================================================
# 4.1.1 Ensure that the cluster-admin role is only used where required
# ==============================================================================
echo ""
echo "[4.1.1] Checking: Ensure that the cluster-admin role is only used where required"
WARNING_411=0
# Lấy danh sách, lọc bỏ system/eks, đếm số lượng
kubectl get clusterrolebindings -o json | jq -r '
  .items[]
  | select(.roleRef.name == "cluster-admin")
  | .metadata.name + " -> " + (.subjects[]? | .kind + "/" + .name)
' | grep -vE "^system:|^eks:|^aws-node|^addon-" | sort | uniq | while read line; do
    echo "[WARN] Check this binding: $line"
    ((WARNING_411++))
done

if [ "$WARNING_411" -eq 0 ]; then
  echo "RESULT 4.1.1: PASS"
else
  echo "RESULT 4.1.1: FAIL (Found $WARNING_411 suspicious admin bindings)"
fi

# ==============================================================================
# 4.1.2 Minimize access to secrets
# ==============================================================================
echo ""
echo "[4.1.2] Checking: Minimize access to secrets"
WARNING_412=0

# Logic: Tìm ClusterRole có rules truy cập 'secrets' với quyền 'get/list/watch'
# Fix: Dùng sort | uniq để không in lặp lại tên Role
CR_SECRETS=$(kubectl get clusterroles -o json | jq -r '
  .items[] 
  | select(.rules[]? | .resources? and (.resources[] | contains("secrets")) and .verbs? and (.verbs[] | test("get|list|watch|\\*")))
  | .metadata.name
' | sort | uniq | grep -vE "^system:|^eks:|^aws-|^vpc-resource-controller")

if [ -z "$CR_SECRETS" ]; then
    echo "RESULT 4.1.2: PASS"
else
    # Chỉ in tối đa 5 dòng mẫu để không spam, còn lại đếm tổng
    echo "$CR_SECRETS" | head -n 5 | while read role; do
        echo "[WARN] ClusterRole allows secret access: $role"
    done
    COUNT=$(echo "$CR_SECRETS" | wc -l)
    if [ "$COUNT" -gt 5 ]; then echo "... and $((COUNT-5)) more roles."; fi
    echo "RESULT 4.1.2: FAIL (Found roles with broad secret access)"
fi

# ==============================================================================
# 4.1.4 Minimize access to create pods
# ==============================================================================
echo ""
echo "[4.1.4] Checking: Minimize access to create pods"
WARNING_414=0

# Logic: Tìm ClusterRole có thể 'create' 'pods'
# Fix: Filter mạnh tay hơn các role hệ thống
CR_PODS=$(kubectl get clusterroles -o json | jq -r '
  .items[] 
  | select(.rules[]? | .resources? and (.resources[] | contains("pods")) and .verbs? and (.verbs[] | test("create|\\*")))
  | .metadata.name
' | sort | uniq | grep -vE "^system:|^eks:|^aws-|^vpc-|^amazon-")

if [ -z "$CR_PODS" ]; then
    echo "RESULT 4.1.4: PASS"
else
    echo "$CR_PODS" | head -n 5 | while read role; do
        echo "[WARN] ClusterRole allows pod creation: $role"
    done
    COUNT=$(echo "$CR_PODS" | wc -l)
    if [ "$COUNT" -gt 5 ]; then echo "... and $((COUNT-5)) more roles."; fi
    echo "RESULT 4.1.4: FAIL (Found roles that can create pods)"
fi

# ==============================================================================
# 4.1.6 Ensure that Service Account Tokens are only mounted where necessary
# ==============================================================================
echo ""
echo "[4.1.6] Checking: Service Account Tokens automount"
# Logic: Tìm SA không có automountServiceAccountToken: false (tức là true hoặc null)
# Filter: Bỏ qua namespace kube-system
SAS=$(kubectl get serviceaccounts --all-namespaces -o json | jq -r '
  .items[] 
  | select(.automountServiceAccountToken != false) 
  | select(.metadata.namespace != "kube-system")
  | "Namespace: " + .metadata.namespace + " | SA: " + .metadata.name
')

if [ -z "$SAS" ]; then
    echo "RESULT 4.1.6: PASS"
else
    echo "Found Service Accounts with automount enabled (excluding kube-system):"
    echo "$SAS" | head -n 5
    COUNT=$(echo "$SAS" | wc -l)
    if [ "$COUNT" -gt 5 ]; then echo "... and $((COUNT-5)) more SAs."; fi
    echo "RESULT 4.1.6: FAIL (Remediation required)"
fi
echo ""