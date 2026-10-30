#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:?Set AWS_REGION}"; : "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
for APP in fox-api fox-web; do
 aws ecr describe-repositories --repository-names "$APP" --region "$AWS_REGION" >/dev/null 2>&1 || aws ecr create-repository --repository-name "$APP" --region "$AWS_REGION" --image-scanning-configuration scanOnPush=true
 docker build -t "$APP:demo" "apps/${APP#fox-}"
 docker tag "$APP:demo" "$REGISTRY/$APP:demo"
 docker push "$REGISTRY/$APP:demo"
done
echo "Images pushed to $REGISTRY"
