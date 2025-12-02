echo "[4.1.1] Checking: Cluster-admin usage (Smart Check)"

# 1. Lấy tất cả binding trỏ tới 'cluster-admin'.
# 2. Loại bỏ các binding mà Subject là Group 'system:masters' hoặc 'system:nodes' (đây là core K8s).
# 3. Báo động tất cả các trường hợp còn lại (User cụ thể, ServiceAccount cụ thể).
ADMIN_BINDINGS=$(kubectl get clusterrolebindings -o json | jq -r '
  .items[]
  | select(.roleRef.name == "cluster-admin")
  | .subjects[]?
  | select(.kind == "User" or (.kind == "Group" and (.name | startswith("system:") | not)) or .kind == "ServiceAccount")
  | "TYPE: " + .kind + " | NAME: " + .name + " | NS: " + (.namespace // "Cluster-Scope")
' | sort | uniq)

if [ -z "$ADMIN_BINDINGS" ]; then
  echo "RESULT 4.1.1: PASS (No suspicious user/SA has cluster-admin)"
else
  # Đếm số dòng
  COUNT=$(echo "$ADMIN_BINDINGS" | wc -l)
  echo "$ADMIN_BINDINGS" | while read line; do
     echo " [WARN] $line"
  done
  echo "RESULT 4.1.1: FAIL (Found $COUNT non-system entities with cluster-admin)"
fi

# 4.1.2 & 4.1.4: Lọc dựa trên System Labels
# Hàm dùng chung để check role nguy hiểm
check_roles() {
    RESOURCE=$1
    VERB_REGEX=$2
    LABEL_DESC=$3


    # 1. Tìm role có quyền truy cập resource.
    # 2. LOẠI BỎ các role có label "kubernetes.io/bootstrapping=rbac-defaults" (Role chuẩn của K8s).
    # 3. LOẠI BỎ các role bắt đầu bằng "system:" (Role nội bộ của Control Plane).
    # -> Kết quả: Chỉ hiện ra Role do người dùng/tool cài thêm (Custom Roles).
    kubectl get clusterroles -o json | jq -r --arg res "$RESOURCE" --arg regex "$VERB_REGEX" '
      .items[]
      | select(.metadata.labels["kubernetes.io/bootstrapping"] != "rbac-defaults")
      | select(.metadata.name | startswith("system:") | not)
      | select(.rules[]? | .resources? and (.resources[] | contains($res)) and .verbs? and (.verbs[] | test($regex)))
      | .metadata.name
    ' | sort | uniq
}

echo ""
echo "[4.1.2] Checking: Minimize access to Secrets (Custom Roles only)"
BAD_SECRET_ROLES=$(check_roles "secrets" "get|list|watch|\\*")

if [ -z "$BAD_SECRET_ROLES" ]; then
    echo "RESULT 4.1.2: PASS"
else
    echo "$BAD_SECRET_ROLES" | head -n 5 | while read role; do echo " [WARN] Custom Role allows Secrets: $role"; done
    COUNT=$(echo "$BAD_SECRET_ROLES" | wc -l)
    [ "$COUNT" -gt 5 ] && echo " ... and $((COUNT-5)) more."
    echo "RESULT 4.1.2: FAIL (Found custom roles exposing secrets)"
fi

echo ""
echo "[4.1.4] Checking: Minimize access to Create Pods (Custom Roles only)"
BAD_POD_ROLES=$(check_roles "pods" "create|\\*")

if [ -z "$BAD_POD_ROLES" ]; then
    echo "RESULT 4.1.4: PASS"
else
    echo "$BAD_POD_ROLES" | head -n 5 | while read role; do echo " [WARN] Custom Role allows Pod create: $role"; done
    COUNT=$(echo "$BAD_POD_ROLES" | wc -l)
    [ "$COUNT" -gt 5 ] && echo " ... and $((COUNT-5)) more."
    echo "RESULT 4.1.4: FAIL (Found custom roles creating pods)"
fi


# 4.1.6 Service Account
echo ""
echo "[4.1.6] Checking: Automount on 'default' ServiceAccounts"

# Thay vì check tất cả SA, chỉ check SA tên là "default".
# Đây là recommend quan trọng nhất của CIS vì SA này có mặt ở mọi namespace.
DEFAULT_SAS=$(kubectl get serviceaccounts --all-namespaces -o json | jq -r '
  .items[]
  | select(.metadata.name == "default")
  | select(.automountServiceAccountToken != false)
  | .metadata.namespace
')

if [ -z "$DEFAULT_SAS" ]; then
    echo "RESULT 4.1.6: PASS (All default SAs have automount disabled)"
else
    # Đếm số lượng namespace vi phạm
    COUNT=$(echo "$DEFAULT_SAS" | wc -l)
    
    # In ra dạng gọn gàng hơn
    echo "Found 'default' SA with automount=true in these namespaces:"
    echo "$DEFAULT_SAS" | head -n 5 | awk '{print " - " $0}'
    
    if [ "$COUNT" -gt 5 ]; then echo " ... and $((COUNT-5)) more namespaces."; fi
    echo "RESULT 4.1.6: FAIL (Recommend: Patch 'default' SAs to automount=false)"
fi

echo ""
