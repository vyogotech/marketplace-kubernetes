#!/bin/sh

set -e

################################################################################
# chart
################################################################################
STACK="frappe-operator"
NAMESPACE="frappe-operator-system"

helm uninstall "$STACK" \
  --namespace "$NAMESPACE"

################################################################################
# StackGres is deliberately left installed
################################################################################
# Removing it would take every SGCluster with it, and those hold the site
# databases this operator created. Uninstalling the control plane must not
# destroy the data it was managing.
#
# To remove it once you have confirmed nothing depends on it:
#
#   kubectl get sgclusters -A
#   helm uninstall stackgres-operator -n stackgres
#
if kubectl get deployment stackgres-operator -n stackgres >/dev/null 2>&1; then
  echo ""
  echo "The StackGres PostgreSQL Operator is still installed in namespace 'stackgres'."
  echo "It was left in place because removing it would delete the SGCluster resources"
  echo "holding your site databases. Check 'kubectl get sgclusters -A' before removing"
  echo "it with 'helm uninstall stackgres-operator -n stackgres'."
fi
