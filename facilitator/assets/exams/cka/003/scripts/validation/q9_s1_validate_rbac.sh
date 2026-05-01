#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q9"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:batch-runner"

if ! can_i yes --as="$SA_SUBJECT" create jobs.batch -n "$NAMESPACE"; then
  echo "❌ batch-runner cannot create jobs.batch in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" get jobs.batch -n "$NAMESPACE"; then
  echo "❌ batch-runner cannot get jobs.batch in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" list jobs.batch -n "$NAMESPACE"; then
  echo "❌ batch-runner cannot list jobs.batch in ${NAMESPACE}"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" create deployments.apps -n "$NAMESPACE"; then
  echo "❌ batch-runner can create deployments; expected Job-only creation"
  exit 1
fi

echo "✅ batch-runner has correct Job permissions through batch API group"
exit 0
