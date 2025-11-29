#!/bin/bash

echo "=== CIS 5.2.1 - Prefer using dedicated EKS Service Accounts ==="
echo

NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

for ns in $NAMESPACES; do
    echo "Checking namespace: $ns"
    echo "--------------------------------"


    SA=$(kubectl get sa default -n $ns --ignore-not-found)
    if [[ -z "$SA" ]]; then
        echo "INFO: No default service account in $ns"
        continue
    fi


    RB=$(kubectl get rolebinding -n $ns -o json | jq -r ".items[] | select(.subjects[]? | select(.name==\"default\")) | .metadata.name")
    CRB=$(kubectl get clusterrolebinding -o json | jq -r ".items[] | select(.subjects[]? | select(.name==\"default\" and .namespace==\"$ns\")) | .metadata.name")

    if [[ -n "$RB" ]] || [[ -n "$CRB" ]]; then
        echo "[WARN] Default service account in namespace '$ns' has role bindings!"
        echo "       RoleBinding: $RB"
        echo "       ClusterRoleBinding: $CRB"
        echo "       → Manual review required."
    else
        echo "[OK] Default SA has no extra role bindings."
    fi

    # 3. Check automountServiceAccountToken
    AUTO=$(kubectl get sa default -n $ns -o jsonpath='{.automountServiceAccountToken}')

    if [[ "$AUTO" == "false" ]]; then
        echo "[OK] automountServiceAccountToken=false"
    else
        echo "[WARN] automountServiceAccountToken is NOT false → Fixing..."
        
        # Remediation
        kubectl patch sa default -n $ns -p '{"automountServiceAccountToken": false}' >/dev/null

        echo "[FIXED] automountServiceAccountToken set to false"
    fi

    echo
done

echo "=== Completed CIS 5.2.1 audit ==="
