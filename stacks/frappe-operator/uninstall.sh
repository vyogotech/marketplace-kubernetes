#!/bin/sh

set -e

################################################################################
# chart
################################################################################
STACK="frappe-operator"
NAMESPACE="frappe-operator-system"


helm uninstall "$STACK" \
  --namespace "$NAMESPACE"
