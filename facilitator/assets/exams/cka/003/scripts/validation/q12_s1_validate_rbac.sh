#!/bin/bash
set +e

can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

NAMESPACE="rbac-q12"
SA_SUBJECT="system:serviceaccount:${NAMESPACE}:leader-elector"

for verb in get create update patch; do
  if ! can_i yes --as="$SA_SUBJECT" "$verb" leases.coordination.k8s.io -n "$NAMESPACE"; then
    echo "❌ leader-elector cannot ${verb} leases.coordination.k8s.io in ${NAMESPACE}"
    exit 1
  fi
done

if ! can_i no --as="$SA_SUBJECT" delete leases.coordination.k8s.io -n "$NAMESPACE"; then
  echo "❌ leader-elector can delete Leases; expected no delete permission"
  exit 1
fi

echo "✅ leader-elector has correct Lease permissions through coordination.k8s.io API group"
exit 0
