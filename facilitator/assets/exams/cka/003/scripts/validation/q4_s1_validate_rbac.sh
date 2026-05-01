#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q4"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:node-inspector"

if ! can_i yes --as="$SA_SUBJECT" get nodes; then
  echo "❌ node-inspector cannot get nodes"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" list nodes; then
  echo "❌ node-inspector cannot list nodes"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" delete nodes; then
  echo "❌ node-inspector can delete nodes; expected read-only access"
  exit 1
fi

echo "✅ node-inspector has correct cluster-scoped node read access"
exit 0
