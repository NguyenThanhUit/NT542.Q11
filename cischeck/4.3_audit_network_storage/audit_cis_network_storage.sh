#!/bin/bash

echo "CIS BENCHMARK AUDIT: 4.3 CNI, 4.4 SECRETS, 4.5 NAMESPACES"
echo "Cluster Context: $(kubectl config current-context)"

# --- 4.3.2 Ensure that all Namespaces have Network Policies defined ---
echo "[4.3.2] Checking: Ensure that all Namespaces have Network Policies defined"
echo "Criteria: Every namespace should have at least one NetworkPolicy to isolate traffic."


# Get all namespaces
NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')
FAIL_432=0

for ns in $NAMESPACES; do
    # Count network policies in the namespace
    NP_COUNT=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l)
    
    if [ "$NP_COUNT" -eq 0 ]; then
        echo "[WARN] Namespace '$ns' has NO Network Policies."
        ((FAIL_432++))
    else
        echo "[PASS] Namespace '$ns' has $NP_COUNT Network Policies."
    fi
done

if [ "$FAIL_432" -gt 0 ]; then
    echo "RESULT 4.3.2: FAIL (Found $FAIL_432 namespaces without network isolation)"
else
    echo "RESULT 4.3.2: PASS (All namespaces have policies)"
fi

# --- 4.4.1 Prefer using secrets as files over secrets as environment variables ---
echo "[4.4.1] Checking: Prefer using secrets as files over secrets as environment variables"
echo "Criteria: Pods should mount secrets as volumes, not map them to env vars (envFrom/valueFrom)."


WARN_441=0

# Logic: Scan all pods, look for containers using 'secretKeyRef' inside 'env'
kubectl get pods --all-namespaces -o json | jq -r '
  .items[] | 
  select(.spec.containers[].env[]?.valueFrom.secretKeyRef != null) |
  " - Namespace: " + .metadata.namespace + " | Pod: " + .metadata.name + " uses Secret as EnvVar"
' | while read line; do
    echo "[WARN] $line"
    ((WARN_441++))
done

if [ "$WARN_441" -gt 0 ]; then
    echo "RESULT 4.4.1: FAIL (Found $WARN_441 pods using Secrets as Env Vars)"
    echo "Note: Using Secrets as Env Vars allows values to be seen in crash dumps or 'env' commands."
else
    echo "RESULT 4.4.1: PASS (No secrets mapped to environment variables found)"
fi

# --- 4.5.2 The default namespace should not be used ---
echo "[4.5.2] Checking: The default namespace should not be used"
echo "Criteria: No application workloads (Pods, Deployments) should run in the 'default' namespace."

# Check for resources in 'default' namespace (excluding the default kubernetes service)
RES_COUNT=$(kubectl get pods,deployments,statefulsets,daemonsets -n default --no-headers 2>/dev/null | wc -l)

if [ "$RES_COUNT" -gt 0 ]; then
    echo "[WARN] Found resources in 'default' namespace:"
    kubectl get pods,deployments -n default --no-headers
    echo "RESULT 4.5.2: FAIL (Default namespace is being used)"
else
    echo "[PASS] 'default' namespace is empty (No workloads found)."
    echo "RESULT 4.5.2: PASS"
fi

echo "AUDIT COMPLETED"