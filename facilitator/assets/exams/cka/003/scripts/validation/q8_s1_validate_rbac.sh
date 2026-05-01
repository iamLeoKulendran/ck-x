#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q8"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:auditor"

if kubectl get clusterrolebinding q8-accidental-admin >/dev/null 2>&1; then
  echo "❌ q8-accidental-admin ClusterRoleBinding still exists"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" get pods -n "$NAMESPACE"; then
  echo "❌ auditor cannot get pods in ${NAMESPACE}"
  exit 1
fi

if ! can_i yes --as="$SA_SUBJECT" list configmaps -n "$NAMESPACE"; then
  echo "❌ auditor cannot list ConfigMaps in ${NAMESPACE}"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" delete pods -n "$NAMESPACE"; then
  echo "❌ auditor can delete pods; expected read-only access"
  exit 1
fi

if ! can_i no --as="$SA_SUBJECT" get secrets -n "$NAMESPACE"; then
  echo "❌ auditor can read Secrets; expected no Secret access"
  exit 1
fi

echo "✅ auditor has least-privilege namespace read access"
exit 0
