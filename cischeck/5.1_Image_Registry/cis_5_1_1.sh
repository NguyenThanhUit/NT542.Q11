#!/bin/bash

REPO_NAME=$1
REGION=$2

if [ -z "$REPO_NAME" ] || [ -z "$REGION" ]; then
  echo "Usage: $0 <ECR_REPOSITORY_NAME> <AWS_REGION>"
  exit 1
fi


SCAN_STATUS=$(aws ecr describe-repositories \
    --repository-names $REPO_NAME \
    --region $REGION \
    --query "repositories[].imageScanningConfiguration.scanOnPush" \
    --output text 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "[ERROR] Repository '$REPO_NAME' not found or no permissions!"
    exit 1
fi

echo "[INFO] Current scanOnPush status: $SCAN_STATUS"



if [ "$SCAN_STATUS" == "True" ]; then
    echo "[PASS] scanOnPush is already enabled for repository '$REPO_NAME'"
    exit 0
fi


echo "[FAIL] scanOnPush is NOT enabled for repository '$REPO_NAME'"
echo "[ACTION] Enabling scanOnPush now..."

aws ecr put-image-scanning-configuration \
    --repository-name $REPO_NAME \
    --image-scanning-configuration scanOnPush=true \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "[FIXED] scanOnPush successfully enabled for '$REPO_NAME'"
    echo "[PASS] CIS 5.1.1 requirement satisfied."
else
    echo "[ERROR] Failed to enable scanOnPush!"
    exit 1
fi
