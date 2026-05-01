#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q2"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:deploy-reader"

SA_NAME=$(kubectl -n "$NAMESPACE" get deployment frontend -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)

if [ "$SA_NAME" != "deploy-reader" ]; then
  echo "❌ Deployment frontend uses ServiceAccount '${SA_NAME:-default/missing}', expected deploy-reader"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" get configmaps -n "$NAMESPACE"; then
  echo "❌ deploy-reader cannot get ConfigMaps in ${NAMESPACE}"
  exit 1
fi

echo "✅ frontend Deployment uses deploy-reader and the ServiceAccount has expected ConfigMap read access"
exit 0
