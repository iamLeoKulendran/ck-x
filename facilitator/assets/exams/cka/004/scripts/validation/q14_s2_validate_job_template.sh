#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
NS=cka-q14
CJ=q14-cleanup
IMG=$(kubectl get cronjob "$CJ" -n "$NS" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')
SUCCESS=$(kubectl get cronjob "$CJ" -n "$NS" -o jsonpath='{.spec.successfulJobsHistoryLimit}')
FAILED=$(kubectl get cronjob "$CJ" -n "$NS" -o jsonpath='{.spec.failedJobsHistoryLimit}')
[ "$IMG" = "busybox:1.36" ] || fail "Expected image busybox:1.36, got $IMG"
[ "$SUCCESS" = "2" ] || fail "successfulJobsHistoryLimit must be 2"
[ "$FAILED" = "1" ] || fail "failedJobsHistoryLimit must be 1"
kubectl get cronjob "$CJ" -n "$NS" -o yaml | grep -q 'echo cleanup' || fail "Command must echo cleanup"
pass "CronJob template is correct"
