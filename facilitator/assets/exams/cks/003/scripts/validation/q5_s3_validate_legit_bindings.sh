#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

# Positive guard: this check only counts once the audit and cleanup happened
[ -f /tmp/exam/q5/findings.txt ] || fail "complete the audit first; findings.txt missing"
if kubectl get clusterrolebinding telemetry-public-access >/dev/null 2>&1; then
  fail "cleanup not done yet; telemetry-public-access still exists"
fi

kubectl get clusterrolebinding system:public-info-viewer >/dev/null 2>&1 || fail "built-in system:public-info-viewer was removed; it must stay"
kubectl get clusterrolebinding release-bot-read >/dev/null 2>&1 || fail "release-bot-read was removed; it must stay"

echo "PASS: legitimate bindings survived the cleanup"
exit 0
