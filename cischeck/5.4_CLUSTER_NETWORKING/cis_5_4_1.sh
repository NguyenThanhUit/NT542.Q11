#!/bin/bash

CLUSTER_NAME=$1
REGION=$2
ALLOWED_CIDR=$3 #Địa chỉ public ip của người dùng

if [[ -z "$CLUSTER_NAME" || -z "$REGION" ]]; then #Kiem tra xem cac doi so co duoc truyen vao khong
    echo "Usage: $0 <CLUSTER_NAME> <REGION> [ALLOWED_CIDR]"
    exit 1
fi

echo "=== CIS 5.4.1 - Restrict Access to the Control Plane Endpoint ==="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo

ENDPOINT_PUBLIC=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query "cluster.resourcesVpcConfig.endpointPublicAccess" --output text)

ENDPOINT_PRIVATE=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query "cluster.resourcesVpcConfig.endpointPrivateAccess" --output text)

PUBLIC_CIDRS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query "cluster.resourcesVpcConfig.publicAccessCidrs" --output text)

echo "Current settings:"
echo "  endpointPublicAccess : $ENDPOINT_PUBLIC"
echo "  endpointPrivateAccess: $ENDPOINT_PRIVATE"
echo "  publicAccessCidrs    : $PUBLIC_CIDRS"
echo

AUDIT_PASS=true

if [[ "$ENDPOINT_PRIVATE" != "True" ]]; then
    echo "[WARN] endpointPrivateAccess is NOT enabled!"
    AUDIT_PASS=false
else
    echo "[OK] endpointPrivateAccess is enabled."
fi

if [[ "$ENDPOINT_PUBLIC" == "True" ]]; then
    if [[ "$PUBLIC_CIDRS" != "$ALLOWED_CIDRS" ]]; then
        echo "[WARN] endpointPublicAccess is enabled but publicAccessCidrs not restricted!"
        AUDIT_PASS=false
    else
        echo "[OK] endpointPublicAccess is enabled with restricted CIDRs."
    fi
else
    echo "[INFO] endpointPublicAccess is disabled (safe)."
fi

# ====== Remediation ======
if [[ "$AUDIT_PASS" == "true" ]]; then
    echo
    echo "[PASS] Cluster control plane endpoints are compliant."
else
    echo
    echo "[ACTION] Remediating cluster endpoint access..."
    
    aws eks update-cluster-config \
    --region "$REGION" \
    --name "$CLUSTER_NAME" \
    --resources-vpc-config '{"endpointPrivateAccess":true,"endpointPublicAccess":true,"publicAccessCidrs":["'"$ALLOWED_CIDR"'"]}'
    
    echo "[DONE] Cluster endpoint configuration updated."
fi

echo
echo "=== Completed CIS 5.4.1 audit/remediation ==="