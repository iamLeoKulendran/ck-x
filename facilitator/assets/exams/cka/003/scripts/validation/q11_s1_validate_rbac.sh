#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q11"
USER_NAME="dev-operator"

SUBJECT_KIND=$(kubectl -n "$NAMESPACE" get rolebinding q11-dev-read-pods -o jsonpath='{.subjects[0].kind}' 2>/dev/null)
SUBJECT_NAME=$(kubectl -n "$NAMESPACE" get rolebinding q11-dev-read-pods -o jsonpath='{.subjects[0].name}' 2>/dev/null)

if [ "$SUBJECT_KIND" != "User" ] || [ "$SUBJECT_NAME" != "$USER_NAME" ]; then
  echo "❌ q11-dev-read-pods subject is ${SUBJECT_KIND}/${SUBJECT_NAME}, expected User/${USER_NAME}"
  exit 1
fi

if ! can_i yes --as="$USER_NAME" get pods -n "$NAMESPACE"; then
  echo "❌ dev-operator cannot get pods in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$USER_NAME" list pods -n "$NAMESPACE"; then
  echo "❌ dev-operator cannot list pods in ${NAMESPACE}"
  exit 1
fi

if ! can_i no --as="$USER_NAME" get pods -n default; then
  echo "❌ dev-operator can read pods outside ${NAMESPACE}; expected namespace-only access"
  exit 1
fi

echo "✅ dev-operator has correct namespace-only pod read access"
exit 0
