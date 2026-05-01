#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q5"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:deploy-reader"

if ! can_i yes --as="$SA_SUBJECT" get deployments.apps -n "$NAMESPACE"; then
  echo "❌ deploy-reader cannot get deployments.apps in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" list deployments.apps -n "$NAMESPACE"; then
  echo "❌ deploy-reader cannot list deployments.apps in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" watch deployments.apps -n "$NAMESPACE"; then
  echo "❌ deploy-reader cannot watch deployments.apps in ${NAMESPACE}"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" get pods -n "$NAMESPACE"; then
  echo "❌ deploy-reader has pod access; expected only Deployment read access"
  exit 1
fi

echo "✅ deploy-reader has correct Deployment read access through apps API group"
exit 0
