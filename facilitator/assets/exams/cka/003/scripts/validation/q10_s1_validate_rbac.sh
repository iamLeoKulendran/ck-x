#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q10"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:scaler"

if ! can_i yes --as="$SA_SUBJECT" get deployments/scale -n "$NAMESPACE"; then
  echo "❌ scaler cannot get deployments/scale in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" update deployments/scale -n "$NAMESPACE"; then
  echo "❌ scaler cannot update deployments/scale in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" patch deployments/scale -n "$NAMESPACE"; then
  echo "❌ scaler cannot patch deployments/scale in ${NAMESPACE}"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" delete deployments.apps -n "$NAMESPACE"; then
  echo "❌ scaler can delete deployments; expected scale-only write access"
  exit 1
fi

echo "✅ scaler has correct deployments/scale subresource permissions"
exit 0
