#!/usr/bin/env bash
# Evening shutdown: delete both AKS clusters, then let Terraform clean up the rest.
# Deleting the whole cluster skips node draining, so PodDisruptionBudgets cannot block it.
set -euo pipefail

RG=rg-hilal-restauranty
CLUSTERS="aks-hilal-restauranty-prod aks-hilal-restauranty-staging"

for c in $CLUSTERS; do
  if az aks show -g "$RG" -n "$c" > /dev/null 2>&1; then
    echo "Deleting $c ..."
    az aks delete -g "$RG" -n "$c" --yes --no-wait
  fi
done

echo -n "Waiting for the clusters to disappear "
while [ -n "$(az aks list -g "$RG" --query '[].name' -o tsv)" ]; do
  echo -n "."
  sleep 30
done
echo " done."

cd "$(dirname "$0")/../infra"
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform apply -var="aks_enabled=false"
