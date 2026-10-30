#!/usr/bin/env bash
set -euo pipefail
kind get clusters | grep -qx fox-demo || kind create cluster --name fox-demo
kubectl config use-context kind-fox-demo
docker build -t fox-api:demo apps/api
docker build -t fox-web:demo apps/web
kind load docker-image fox-api:demo fox-web:demo --name fox-demo
kubectl apply -k k8s/local
kubectl rollout status deployment/mongo -n fox-insurance --timeout=180s
kubectl rollout status deployment/fox-api -n fox-insurance --timeout=180s
kubectl rollout status deployment/fox-web -n fox-insurance --timeout=180s
echo 'Run: kubectl port-forward -n fox-insurance svc/fox-web 8080:80'
