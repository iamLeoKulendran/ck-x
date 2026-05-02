#!/bin/bash
set -euo pipefail
NS="rev1-q15"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get pvc report-data >/dev/null 2>&1 || fail "PVC report-data not found in $NS"
VOL=$(kubectl -n "$NS" get cronjob report-gen \
  -o jsonpath='{.spec.jobTemplate.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}' \
  2>/dev/null || echo "")
[[ "$VOL" == *"report-data"* ]] || fail "CronJob does not reference PVC 'report-data' in volumes"
MOUNT=$(kubectl -n "$NS" get cronjob report-gen \
  -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].volumeMounts[*].mountPath}' \
  2>/dev/null || echo "")
[[ "$MOUNT" == *"/data/reports"* ]] || fail "PVC not mounted at '/data/reports', got: '$MOUNT'"
pass "CronJob mounts PVC report-data at /data/reports"
