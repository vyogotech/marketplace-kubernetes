#!/bin/sh

set -e

################################################################################
# prerequisite: StackGres PostgreSQL Operator
################################################################################
# Supports PostgreSQL alongside MariaDB. Frappe Operator provisions SGCluster
# resources when sites specify dbConfig.provider: postgres.
# Installed in its own namespace and kept outside the --atomic call so that any
# operator upgrades or rollbacks do not interrupt active database instances.
STACKGRES_NAMESPACE="stackgres"

if ! kubectl get crd sgclusters.stackgres.io >/dev/null 2>&1; then
  echo "Installing StackGres PostgreSQL Operator..."
  helm repo add stackgres https://stackgres.io/downloads/stackgres-k8s/stackgres/helm
  helm repo update > /dev/null

  helm upgrade stackgres-operator stackgres/stackgres-operator \
    --install \
    --namespace "$STACKGRES_NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 6m0s

  kubectl wait --for condition=established --timeout=120s crd sgclusters.stackgres.io
fi

################################################################################
# repo
################################################################################
helm repo add frappe-operator https://vyogotech.github.io/frappe-operator/helm-repo
helm repo update > /dev/null

################################################################################
# chart
################################################################################
# Bundles MariaDB Operator, KEDA, NGINX Ingress Controller, and OpenEBS NFS
STACK="frappe-operator"
CHART="frappe-operator/frappe-operator"
CHART_VERSION="5.2.6"
NAMESPACE="frappe-operator-system"

if [ -z "${MP_KUBERNETES}" ]; then
  # use local version of values.yml
  ROOT_DIR=$(git rev-parse --show-toplevel)
  values="$ROOT_DIR/stacks/frappe-operator/values.yml"
else
  # use github hosted master version of values.yml
  values="https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/frappe-operator/values.yml"
fi

helm upgrade "$STACK" "$CHART" \
  --atomic \
  --create-namespace \
  --install \
  --timeout 8m0s \
  --namespace "$NAMESPACE" \
  --values "$values" \
  --version "$CHART_VERSION"
