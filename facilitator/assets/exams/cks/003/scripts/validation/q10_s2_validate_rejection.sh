#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="storage-guard"
PROBE="ckx-q10-probe"

[ -f /tmp/exam/q10/rejected.txt ] || fail "captured rejection /tmp/exam/q10/rejected.txt not found"
grep -qiE 'denied|ValidatingAdmissionPolicy|hostPath' /tmp/exam/q10/rejected.txt \
  || fail "rejected.txt does not contain an admission rejection message"

kubectl -n "$NS" delete pod "$PROBE" --ignore-not-found=true >/dev/null 2>&1 || true

if cat <<YAML | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: $PROBE
  namespace: $NS
spec:
  containers:
  - name: probe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 30"]
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /tmp
YAML
then
  kubectl -n "$NS" delete pod "$PROBE" --ignore-not-found=true >/dev/null 2>&1 || true
  fail "a pod with a hostPath volume was accepted; the policy must reject it"
fi

echo "PASS: hostPath pods are rejected and the rejection was captured"
exit 0
