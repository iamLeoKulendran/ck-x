#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
SA="system:serviceaccount:batch-ops:ops-runner"

if kubectl get clusterrolebinding ops-runner-secrets >/dev/null 2>&1; then
  fail "ClusterRoleBinding ops-runner-secrets still exists"
fi
if kubectl get clusterrole ops-runner-secrets >/dev/null 2>&1; then
  fail "ClusterRole ops-runner-secrets still exists"
fi

ANSWER=$(kubectl auth can-i get secrets --all-namespaces --as="$SA" 2>/dev/null || true)
[ "$ANSWER" = "no" ] || fail "ops-runner can still read secrets cluster-wide"

echo "PASS: cluster-wide secret access revoked for ops-runner"
exit 0
