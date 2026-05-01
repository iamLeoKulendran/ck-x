#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q3"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:namespace-viewer"

if kubectl get clusterrolebinding q3-broad-view >/dev/null 2>&1; then
  echo "❌ q3-broad-view ClusterRoleBinding still exists"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" get pods -n "$NAMESPACE"; then
  echo "❌ namespace-viewer cannot read pods in ${NAMESPACE}"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" get pods -n kube-system; then
  echo "❌ namespace-viewer can read pods outside ${NAMESPACE}; expected namespace-only access"
  exit 1
fi

echo "✅ namespace-viewer has namespace-only view access"
exit 0
