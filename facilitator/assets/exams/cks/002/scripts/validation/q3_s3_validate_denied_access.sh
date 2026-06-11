#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="ci-pipeline"
SA="system:serviceaccount:ci-pipeline:build-bot"

# Positive guard: the least-privilege Role must exist
kubectl -n "$NS" get role build-bot-role >/dev/null 2>&1 || fail "Role 'build-bot-role' not found"

if kubectl get clusterrolebinding build-bot-admin >/dev/null 2>&1; then
  fail "ClusterRoleBinding 'build-bot-admin' still exists; cluster-admin must be removed"
fi

[ "$(kubectl auth can-i get secrets -n "$NS" --as="$SA")" = "no" ] || fail "build-bot must NOT read secrets in $NS"
[ "$(kubectl auth can-i list pods --all-namespaces --as="$SA")" = "no" ] || fail "build-bot must NOT list pods cluster-wide"

echo "PASS: overprivileged access removed; denied actions verified"
exit 0
