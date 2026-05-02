#!/bin/bash
NS="rev1-q15"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

# Trigger one-shot job from CronJob
kubectl -n "$NS" delete job q15-verify --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" create job q15-verify --from=cronjob/report-gen >/dev/null 2>&1 \
  || fail "Failed to create job from CronJob report-gen"

# Wait for completion (up to 60s)
DEADLINE=60
ELAPSED=0
STATUS=""
while [ $ELAPSED -lt $DEADLINE ]; do
  STATUS=$(kubectl -n "$NS" get job q15-verify \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")
  FAILED_STATUS=$(kubectl -n "$NS" get job q15-verify \
    -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "")
  [ "$STATUS" = "True" ] && break
  [ "$FAILED_STATUS" = "True" ] && fail "Triggered Job q15-verify failed"
  sleep 3
  ELAPSED=$((ELAPSED + 3))
done
[ "$STATUS" = "True" ] || fail "Job q15-verify did not complete within ${DEADLINE}s"

# Read output via debug pod mounting same PVC
kubectl -n "$NS" delete pod q15-debug --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" run q15-debug --image=busybox:1.36 --restart=Never \
  --overrides='{
    "spec": {
      "volumes": [{"name": "r", "persistentVolumeClaim": {"claimName": "report-data"}}],
      "containers": [{
        "name": "q15-debug",
        "image": "busybox:1.36",
        "command": ["sleep", "30"],
        "volumeMounts": [{"name": "r", "mountPath": "/data/reports"}]
      }]
    }
  }' >/dev/null 2>&1 || fail "Failed to create debug pod"

# Wait for debug pod to be running
ELAPSED=0
while [ $ELAPSED -lt 30 ]; do
  PHASE=$(kubectl -n "$NS" get pod q15-debug \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [ "$PHASE" = "Running" ] && break
  sleep 2; ELAPSED=$((ELAPSED + 2))
done

CONTENT=$(kubectl -n "$NS" exec q15-debug -- cat /data/reports/output.txt 2>/dev/null || echo "")

# Cleanup
kubectl -n "$NS" delete pod q15-debug --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete job q15-verify --ignore-not-found=true >/dev/null 2>&1 || true

[ -n "$CONTENT" ] || fail "/data/reports/output.txt is empty or missing"
pass "Output file /data/reports/output.txt contains content"
