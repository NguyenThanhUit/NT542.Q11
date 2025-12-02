#!/bin/bash

echo "[4.2.1] Checking: Privileged Containers (Minimized)"
FAIL=0; WARN=0

# Lấy dữ liệu: NS, Name, Kind
DATA=$(kubectl get pods -A -o json | jq -r '
  .items[]
  | select(.spec.containers[].securityContext.privileged == true)
  | .metadata.namespace + " " + .metadata.name + " " + (.metadata.ownerReferences[0].kind // "Standalone")
')

if [ -z "$DATA" ]; then
    echo "RESULT: PASS"
    exit 0
fi

echo "--- Violations ---"
while read -r ns name kind; do
    [[ "$ns" =~ ^(kube-system|kube-public)$ ]] && continue
    if [[ "$ns" =~ ^(amazon-|aws-|monitoring|logging) ]] || [[ "$kind" == "DaemonSet" ]]; then
        printf "[WARN] Infra: %s/%s (%s)\n" "$ns" "$name" "$kind" && ((WARN++))
    else
        printf "[FAIL] APP: %s/%s (%s)\n" "$ns" "$name" "$kind" && ((FAIL++))
    fi
done <<< "$DATA"

echo "--- Summary ---"
if [ "$FAIL" -gt 0 ]; then
    echo "RESULT: FAIL ($FAIL critical application violations)"
elif [ "$WARN" -gt 0 ]; then
    echo "RESULT: WARNING ($WARN necessary infrastructure risks)"
else
    echo "RESULT: PASS (Only system core pods are privileged)"
fi

echo "[4.2.2] Checking: HostPID Sharing (Minimized)"
FAIL=0; WARN=0

# Lấy dữ liệu: NS, Name, Kind. Lọc các Pod có hostPID = true
DATA=$(kubectl get pods -A -o json | jq -r '
  .items[]
  | select(.spec.hostPID == true)
  | .metadata.namespace + " " + .metadata.name + " " + (.metadata.ownerReferences[0].kind // "Standalone")
')

if [ -z "$DATA" ]; then
    echo "RESULT: PASS"
    exit 0
fi

echo "--- Violations ---"
while read -r ns name kind; do
    [[ "$ns" =~ ^(kube-system|kube-public)$ ]] && continue
    if [[ "$ns" =~ ^(amazon-|aws-|monitoring|logging) ]] || [[ "$kind" == "DaemonSet" ]]; then
        printf "[WARN] Infra: %s/%s (%s)\n" "$ns" "$name" "$kind" && ((WARN++))
    else
        printf "[FAIL] APP: %s/%s (%s)\n" "$ns" "$name" "$kind" && ((FAIL++))
    fi
done <<< "$DATA"

echo "--- Summary ---"
if [ "$FAIL" -gt 0 ]; then
    echo "RESULT: FAIL ($FAIL critical application violations)"
elif [ "$WARN" -gt 0 ]; then
    echo "RESULT: WARNING ($WARN necessary infrastructure risks)"
else
    echo "RESULT: PASS (Only system core pods use HostPID)"
fi
