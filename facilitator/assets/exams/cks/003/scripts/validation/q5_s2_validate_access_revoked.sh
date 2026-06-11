#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

# Positive guard: the audit step must be done first
[ -f /tmp/exam/q5/findings.txt ] || fail "complete the audit first; findings.txt missing"

if kubectl get clusterrolebinding telemetry-public-access >/dev/null 2>&1; then
  fail "ClusterRoleBinding telemetry-public-access still exists"
fi
if kubectl get clusterrole telemetry-export >/dev/null 2>&1; then
  fail "ClusterRole telemetry-export still exists"
fi

SAR=$(kubectl create -o jsonpath='{.status.allowed}' -f - 2>/dev/null <<SAR_EOF
apiVersion: authorization.k8s.io/v1
kind: SubjectAccessReview
spec:
  user: "system:anonymous"
  groups:
  - "system:unauthenticated"
  resourceAttributes:
    namespace: "default"
    verb: "get"
    resource: "secrets"
SAR_EOF
)
[ "$SAR" = "false" ] || fail "anonymous users can still read secrets"

echo "PASS: unauthenticated secret access revoked"
exit 0
