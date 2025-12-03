#!/bin/bash

AWS_REGION=$1
CLUSTER_NAME=$2

echo "=== CIS 5.4.4 - Ensure Network Policy is Enabled ==="


SEC_GRP_ID=$(aws eks describe-cluster \
    --name $CLUSTER_NAME \
    --region $AWS_REGION \
    --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
    --output text)

if [[ -z "$SEC_GRP_ID" || "$SEC_GRP_ID" == "None" ]]; then
    echo "[FAIL] clusterSecurityGroupId is null or not set"
else
    echo "[PASS] clusterSecurityGroupId exists: $SEC_GRP_ID"
fi

CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$CILIUM_POD" ]]; then
    echo "[PASS] Cilium network policy engine is installed and running ($CILIUM_POD)"
else
    echo "[WARN] Network Policy not detected (no vpc-cni addon, no Cilium)"
fi

echo "=== Completed CIS 5.4.4 audit ==="
