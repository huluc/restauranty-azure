#!/usr/bin/env bash
# Morning bootstrap: infrastructure, Argo CD, cluster registration, root app.
# After this, Argo CD installs everything else from Git.
set -euo pipefail
RG=rg-hilal-restauranty
cd "$(dirname "$0")/.."

echo "== 1/5 Terraform"
( cd infra && export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv) && terraform apply )

echo "== 2/5 Cluster credentials"
az aks get-credentials -g "$RG" -n aks-hilal-restauranty-prod    --context prod    --overwrite-existing
az aks get-credentials -g "$RG" -n aks-hilal-restauranty-staging --context staging --overwrite-existing

echo "== 3/5 Argo CD"
helm repo add argo https://argoproj.github.io/argo-helm > /dev/null 2>&1 || true
helm upgrade --install argocd argo/argo-cd --kube-context prod --version 10.17.0 \
  --namespace argocd --create-namespace --set dex.enabled=false --wait
PASS=$(kubectl --context prod -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "== 4/5 Register clusters"
kubectl --context prod port-forward service/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
PF=$!
sleep 5
argocd login localhost:8080 --username admin --password "$PASS" --insecure
argocd cluster add staging --name staging --yes
argocd cluster set in-cluster --name production

echo "== 5/5 Root application"
kubectl --context prod apply -f argocd/root-app.yaml

echo "Done. Argo CD: https://localhost:8080 (user admin, port-forward PID $PF)"
echo "Password: kubectl --context prod -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
