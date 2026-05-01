#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q7"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:log-reader"

if ! can_i yes --as="$SA_SUBJECT" get pods -n "$NAMESPACE"; then
  echo "❌ log-reader cannot get pods in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" get pods/log -n "$NAMESPACE"; then
  echo "❌ log-reader cannot get pods/log in ${NAMESPACE}"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" delete pods -n "$NAMESPACE"; then
  echo "❌ log-reader can delete pods; expected log read-only access"
  exit 1
fi

echo "✅ log-reader can read pod objects and pod logs only"
exit 0
