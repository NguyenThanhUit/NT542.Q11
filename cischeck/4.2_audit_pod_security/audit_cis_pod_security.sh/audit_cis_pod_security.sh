#!/bin/bash

echo "CIS BENCHMARK AUDIT: 4.2 POD SECURITY STANDARDS"
echo "Cluster Context: $(kubectl config current-context)"

# --- 4.2.1 Minimize the admission of privileged containers ---

echo "[4.2.1] Checking: Minimize the admission of privileged containers"
echo "Criteria: containers.securityContext.privileged should NOT be set to true."

# Count privileged containers
PRIV_COUNT=0

kubectl get pods --all-namespaces -o json | jq -r '
  .items[] | 
  {ns: .metadata.namespace, pod: .metadata.name, container: .spec.containers[]} | 
  select(.container.securityContext.privileged == true) | 
  " - Namespace: " + .ns + " | Pod: " + .pod + " | Container: " + .container.name
' | while read line; do
    echo "[WARN] Found Privileged Container: $line"
    ((PRIV_COUNT++))
done

if [ "$PRIV_COUNT" -gt 0 ]; then
    echo "RESULT 4.2.1: FAIL (Found $PRIV_COUNT privileged containers)"
    echo "Note: System pods like 'aws-node' or 'kube-proxy' often require privileges. Check your application pods."
else
    echo "RESULT 4.2.1: PASS (No privileged containers found)"
fi

# --- 4.2.2 Minimize the admission of containers wishing to share the host process ID namespace ---
echo "[4.2.2] Checking: Minimize the admission of containers sharing hostPID"
echo "Criteria: spec.hostPID should NOT be set to true."

# Count hostPID pods
PID_COUNT=0

# Logic: Lấy tất cả pods -> Lọc pod có hostPID=true -> In ra
kubectl get pods --all-namespaces -o json | jq -r '
  .items[] | 
  select(.spec.hostPID == true) | 
  " - Namespace: " + .metadata.namespace + " | Pod: " + .metadata.name
' | while read line; do
    echo "[WARN] Found Pod using HostPID: $line"
    ((PID_COUNT++))
done

if [ "$PID_COUNT" -gt 0 ]; then
    echo "RESULT 4.2.2: FAIL (Found $PID_COUNT pods using HostPID)"
    echo "Note: CNI plugins (like aws-node) often require HostPID. Ensure your web apps do not use this."
else
    echo "RESULT 4.2.2: PASS (No pods using HostPID found)"
fi

echo "AUDIT COMPLETED"
