#!/bin/sh

set -e

################################################################################
# prerequisites, via DigitalOcean's own 1-Click stacks
################################################################################
# Both already exist as Marketplace apps, so their tested deploy scripts are
# reused rather than reimplemented -- the same pattern stacks/mattermost-operator
# uses for ingress-nginx. Each is installed only when the cluster lacks it: a user
# who selected them at cluster creation is not double-installed, and one who did
# not still ends up with something that works.

# ReadWriteMany storage, needed for multi-node benches. do-block-storage is RWO
# only. The provisioner list mirrors storageClassSupportsRWX() in the operator,
# so this script and the operator agree on what counts as RWX.
if ! kubectl get storageclass -o jsonpath='{.items[*].provisioner}' 2>/dev/null \
     | tr ' ' '\n' | grep -qiE 'nfs|ceph|gluster|netapp|azurefile|filestore|portworx'; then
  echo "No ReadWriteMany-capable StorageClass found; installing OpenEBS NFS Provisioner."
  sh -c "curl --location --silent --show-error https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/openebs-nfs-provisioner/deploy.sh | sh"
fi

# Ingress controller. Sites have no external route without one.
if [ -z "$(kubectl get ingressclass -o name 2>/dev/null)" ]; then
  echo "No IngressClass found; installing NGINX Ingress Controller."
  sh -c "curl --location --silent --show-error https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/ingress-nginx/deploy.sh | sh"
fi

################################################################################
# repo
################################################################################
helm repo add frappe-operator https://vyogotech.github.io/frappe-operator/helm-repo
helm repo update > /dev/null

################################################################################
# chart
################################################################################
STACK="frappe-operator"
CHART="frappe-operator/frappe-operator"
CHART_VERSION="5.2.0"
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
