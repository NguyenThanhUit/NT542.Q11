#!/bin/bash

echo "CIS BENCHMARK AUDIT: 4.1 RBAC AND SERVICE ACCOUNTS"
echo "Cluster Context: $(kubectl config current-context)"

# --- 4.1.1 Cluster Admin Usage ---
echo ""
echo "[4.1.1] Checking: Ensure that the cluster-admin role is only used where required"
echo "---------------------------------------------------------"
WARNING_411=0

kubectl get clusterrolebindings -o json | jq -r '
  .items[] 
  | select(.roleRef.name == "cluster-admin") 
  | .metadata.name + " -> " + (.subjects[]? | .kind + "/" + .name)
' | while read line; do
    # Filter system defaults
    if [[ "$line" == *"system:"* ]] || [[ "$line" == *"eks:"* ]]; then
        echo "[OK] System Binding: $line"
    else
        echo "[WARN] Check this binding: $line"
        ((WARNING_411++))
    fi
done

if [ "$WARNING_411" -eq 0 ]; then 
    echo "RESULT 4.1.1: PASS"
else
    echo "RESULT 4.1.1: FAIL (Found suspicious admin bindings)"
fi

# --- 4.1.2 Access to Secrets ---
echo "[4.1.2] Checking: Minimize access to secrets"
echo "Scanning for ClusterRoles with 'get/list/watch' on 'secrets'..."

kubectl get clusterroles -o json | jq -r '
  .items[] 
  | select(.rules[]? | select(.resources[]? | index("secrets") or index("*")))
  | select(.rules[]? | select(.verbs[]? | index("get") or index("list") or index("watch") or index("*")))
  | .metadata.name
' | while read role; do
    if [[ "$role" != system:* ]] && [[ "$role" != aws:* ]] && [[ "$role" != eks:* ]]; then
         echo "[WARN] ClusterRole allows secret access: $role"
    fi
done
echo "Note: System roles (system:*, aws:*, eks:*) are excluded from output."

# --- 4.1.4 Create Pods ---

echo "[4.1.4] Checking: Minimize access to create pods"
echo "Scanning for Roles/ClusterRoles that can 'create' pods..."

kubectl get clusterroles,roles --all-namespaces -o json | jq -r '
  .items[] 
  | select(.rules[]? | select(.resources[]? | index("pods") or index("*")))
  | select(.rules[]? | select(.verbs[]? | index("create") or index("*")))
  | .kind + ": " + .metadata.name + " (Namespace: " + (.metadata.namespace // "Cluster-wide") + ")"
' | grep -v "system:" | grep -v "aws-" | grep -v "eks-" | while read line; do
    echo "[WARN] $line"
done
echo "Note: System roles are excluded from output."

# --- 4.1.6 Automount Service Account Token ---

echo "[4.1.6] Checking: Ensure that Service Account Tokens are only mounted where necessary"
echo "Scanning for Service Accounts with automountServiceAccountToken: true (or default)..."

# Count SAs that have automount NOT set to false (default is true)
COUNT_SA=$(kubectl get serviceaccounts --all-namespaces -o json | jq '[.items[] | select(.automountServiceAccountToken != false) | select(.metadata.namespace != "kube-system")] | length')

if [ "$COUNT_SA" -gt 0 ]; then
    echo "[WARN] Found $COUNT_SA Service Accounts with automount enabled (excluding kube-system)."
    echo "Listing first 5 examples:"
    kubectl get serviceaccounts --all-namespaces -o json | jq -r '
      .items[] 
      | select(.automountServiceAccountToken != false) 
      | select(.metadata.namespace != "kube-system")
      | " - Namespace: " + .metadata.namespace + " | SA: " + .metadata.name
    ' | head -n 5
    echo "RESULT 4.1.6: FAIL (Remediation required: set automountServiceAccountToken: false)"
else
    echo "RESULT 4.1.6: PASS (All non-system SAs have automount disabled)"
fi

echo "AUDIT COMPLETED"
