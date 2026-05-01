#!/bin/bash
set -euo pipefail
NS=cka-q07
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
mkdir -p /tmp/exam/q07
cat > /tmp/exam/q07/checksum-job.yaml <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: checksum-job
  namespace: cka-q07
spec:
  completions: 1
  parallelism: 1
  template:
    spec:
      restartPolicy: Always
      containers:
      - name: checksum
        image: busybox:1.36
        command: ["sh","-c","echo checksum-ok"]
YAML
kubectl delete job checksum-job -n "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
