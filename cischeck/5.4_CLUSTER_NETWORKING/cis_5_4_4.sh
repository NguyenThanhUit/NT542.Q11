#!/bin/bash

AWS_REGION=$1
CLUSTER_NAME=$2

echo "=== CIS 5.4.4 – Ensure Network Policy is Enabled ==="
echo

# 1. Kiểm tra clusterSecurityGroupId
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

# 2. Kiểm tra vpc-cni addon
NP_ENABLED=$(aws eks describe-addon \
    --cluster-name $CLUSTER_NAME \
    --addon-name vpc-cni \
    --region $AWS_REGION \
    --query "addon.configurationValues" 2>/dev/null)

if [[ $? -eq 0 && "$NP_ENABLED" == *"NetworkPolicy"* ]]; then
    echo "[PASS] Network Policy is enabled via vpc-cni addon"
else
    # 3. Nếu addon không tồn tại, kiểm tra Calico
    CALICO_POD=$(kubectl get pods -n kube-system -l k8s-app=calico-node -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -n "$CALICO_POD" ]]; then
        echo "[PASS] Calico network policy engine is installed and running ($CALICO_POD)"
    else
        echo "[WARN] Network Policy not detected (no vpc-cni addon, no Calico)"
    fi
fi

echo
echo "=== Completed CIS 5.4.4 audit ==="
