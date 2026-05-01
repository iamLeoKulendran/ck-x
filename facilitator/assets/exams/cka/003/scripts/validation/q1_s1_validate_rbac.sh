#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q1"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:report-reader"

if ! kubectl -n "$NAMESPACE" get serviceaccount report-reader >/dev/null 2>&1; then
  echo "❌ ServiceAccount report-reader is missing in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" get pods -n "$NAMESPACE"; then
  echo "❌ report-reader cannot get pods in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" list pods -n "$NAMESPACE"; then
  echo "❌ report-reader cannot list pods in ${NAMESPACE}"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" delete pods -n "$NAMESPACE"; then
  echo "❌ report-reader has delete pod permission; expected read-only access"
  exit 1
fi

echo "✅ report-reader has read-only pod access in ${NAMESPACE}"
exit 0
