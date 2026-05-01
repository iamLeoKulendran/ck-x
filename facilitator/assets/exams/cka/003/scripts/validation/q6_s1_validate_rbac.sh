#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q6"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:report-sa"

SUBJECT_NS=$(kubectl -n "$NAMESPACE" get rolebinding q6-read-pods -o jsonpath='{.subjects[0].namespace}' 2>/dev/null)
SUBJECT_NAME=$(kubectl -n "$NAMESPACE" get rolebinding q6-read-pods -o jsonpath='{.subjects[0].name}' 2>/dev/null)

if [ "$SUBJECT_NAME" != "report-sa" ] || [ "$SUBJECT_NS" != "$NAMESPACE" ]; then
  echo "❌ q6-read-pods RoleBinding subject is ${SUBJECT_NS}/${SUBJECT_NAME}, expected ${NAMESPACE}/report-sa"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" get pods -n "$NAMESPACE"; then
  echo "❌ report-sa cannot get pods in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" list pods -n "$NAMESPACE"; then
  echo "❌ report-sa cannot list pods in ${NAMESPACE}"
  exit 1
fi

echo "✅ q6-read-pods RoleBinding references the correct ServiceAccount namespace"
exit 0
