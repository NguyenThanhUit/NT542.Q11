#!/bin/bash

CLUSTER_NAME=$1
REGION=$2

echo "Checking current logging status..."

STATUS=$(aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --query "cluster.logging.clusterLogging[?enabled==\`true\`]" \
    --output text)


if echo "$STATUS" | grep -q "True"; then
    echo "PASS: Audit logging is already enabled."
    exit 0
else
    echo "FAIL: Audit logging is disabled. Enabling now..."
fi

aws eks update-cluster-config \
  --region "$REGION" \
  --name "$CLUSTER_NAME" \
  --logging "{\"clusterLogging\":[{\"types\":[\"api\",\"audit\",\"authenticator\",\"controllerManager\",\"scheduler\"],\"enabled\":true}]}"

echo "Audit logging enabled successfully."
