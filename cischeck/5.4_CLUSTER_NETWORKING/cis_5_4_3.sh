#!/bin/bash

AWS_REGION=$1
CLUSTER_NAME=$2

echo "=== CIS 5.4.3 – Ensure Private Nodes ==="
echo

# 1. Lấy nodegroups
NODEGROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --query "nodegroups" --output text)

if [[ -z "$NODEGROUPS" ]]; then
    echo "[WARN] No nodegroups found in cluster $CLUSTER_NAME"
    exit 0
fi

for NG in $NODEGROUPS; do
    echo "Checking NodeGroup: $NG"
    
    NG_DESC=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NG --region $AWS_REGION --output json)
    

    ASSOC_PUBLIC=$(echo "$NG_DESC" | jq -r '.nodegroup.scalingConfig' 2>/dev/null)
    

    ASSOC_IP=$(echo "$NG_DESC" | jq -r '.nodegroup.launchTemplate.launchTemplateName?')
    
    echo "  Launch Template: ${ASSOC_IP:-None}"
    
    # 3. Check subnets
    SUBNETS=$(echo "$NG_DESC" | jq -r '.nodegroup.subnets[]')
    for SUB in $SUBNETS; do
        ROUTES=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SUB" --region $AWS_REGION --query "RouteTables[].Routes[].GatewayId" --output text)
        if echo "$ROUTES" | grep -q igw-; then
            echo "  [WARN] Subnet $SUB is public (has route to IGW)"
        else
            echo "  [OK] Subnet $SUB is private (no IGW)"
        fi
    done
    
done

echo
echo "=== Completed CIS 5.4.3 audit ==="
