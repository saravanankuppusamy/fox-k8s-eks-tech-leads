#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:?Set AWS_REGION}"; : "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
: "${EKS_CLUSTER:=fox-training}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER"
# Explicitly verify context before any cluster-changing operation.
kubectl config current-context
read -r -p 'Deploy Fox Insurance to this context? Type yes: ' CONFIRM
[[ "$CONFIRM" == yes ]] || exit 1
TMP=$(mktemp -d);trap 'rm -rf "$TMP"' EXIT
cp -R k8s/eks "$TMP/eks";cp -R k8s/base "$TMP/base"
sed -i.bak "s/REPLACE_ACCOUNT/$AWS_ACCOUNT_ID/g;s/REPLACE_REGION/$AWS_REGION/g" "$TMP/eks/kustomization.yaml"
rm -f "$TMP/eks/kustomization.yaml.bak"
kubectl apply -k "$TMP/eks"
kubectl rollout status deployment/fox-api -n fox-insurance --timeout=240s
kubectl rollout status deployment/fox-web -n fox-insurance --timeout=240s
