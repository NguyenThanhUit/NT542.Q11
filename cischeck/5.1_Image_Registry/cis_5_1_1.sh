#!/bin/bash

REGION=$1
shift              
REPOSITORIES=("$@")

if [ -z "$REGION" ] || [ ${#REPOSITORIES[@]} -eq 0 ]; then
  echo "Usage: $0 <AWS_REGION> <REPO_1> <REPO_2> ... <REPO_N>"
  exit 1
fi

echo "[INFO] Checking scanOnPush for ${#REPOSITORIES[@]} repositories..."
echo "------------------------------------------------------------"

for REPO_NAME in "${REPOSITORIES[@]}"; do
  echo "[CHECK] Repository: $REPO_NAME"

  SCAN_STATUS=$(aws ecr describe-repositories \
      --repository-names "$REPO_NAME" \
      --region "$REGION" \
      --query "repositories[].imageScanningConfiguration.scanOnPush" \
      --output text 2>/dev/null)

  if [ $? -ne 0 ]; then
      echo "[ERROR] '$REPO_NAME' not found or insufficient permissions!"
      echo
      continue
  fi

  echo " - scanOnPush: $SCAN_STATUS"

  if [ "$SCAN_STATUS" == "True" ]; then
      echo "[PASS] scanOnPush already enabled for '$REPO_NAME'"
      echo
      continue
  fi

  echo "[FAIL] scanOnPush is NOT enabled for '$REPO_NAME'"
  echo "[ACTION] Enabling scanOnPush..."

  aws ecr put-image-scanning-configuration \
      --repository-name "$REPO_NAME" \
      --image-scanning-configuration scanOnPush=true \
      --region "$REGION"

  if [ $? -eq 0 ]; then
      echo "[FIXED] scanOnPush ENABLED for '$REPO_NAME'"
      echo "[PASS] CIS 5.1.1 satisfied"
  else
      echo "[ERROR] Failed to enable scanOnPush for '$REPO_NAME'"
  fi

  echo
done

echo "------------------------------------------------------------"
echo "[DONE] CIS 5.1.1 check completed for all repositories."
