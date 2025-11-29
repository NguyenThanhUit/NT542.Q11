#!/bin/bash

AWS_REGION=$1
CLUSTER_NAME=$2  
MY_IP=$3

echo "=== CIS 5.4.2 - Control Plane Endpoint Audit ==="
echo


echo "[INFO] Fetching cluster endpoint configuration..."
ENDPOINT_CONFIG=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.resourcesVpcConfig" \
  --output json)

PRIVATE_ACCESS=$(echo "$ENDPOINT_CONFIG" | jq -r '.endpointPrivateAccess')
PUBLIC_ACCESS=$(echo "$ENDPOINT_CONFIG" | jq -r '.endpointPublicAccess')
PUBLIC_CIDRS=$(echo "$ENDPOINT_CONFIG" | jq -r '.publicAccessCidrs[]?')

echo "Current settings:"
echo "  Private Endpoint : $PRIVATE_ACCESS"
echo "  Public Endpoint  : $PUBLIC_ACCESS"
echo "  Public CIDRs     : ${PUBLIC_CIDRS:-None}"
echo

# 2. Audit
if [ "$PRIVATE_ACCESS" = "true" ]; then
    echo "[OK] Private endpoint is enabled"
else
    echo "[WARN] Private endpoint is NOT enabled"
fi

if [ "$PUBLIC_ACCESS" = "false" ]; then
    echo "[OK] Public endpoint is disabled"
else
    echo "[WARN] Public endpoint is NOT disabled"
    echo "[ACTION] Restricting public access to a single IP (your IP)..."
    
    aws eks update-cluster-config \
      --region "$AWS_REGION" \
      --name "$CLUSTER_NAME" \
      --resources-vpc-config endpointPrivateAccess=true,endpointPublicAccess=true,publicAccessCidrs="$MY_IP"
    
    echo "[FIXED] Public endpoint restricted to $MY_IP"
fi

echo
echo "=== Completed CIS 5.4.x audit ==="
