#!/bin/bash
set -euo pipefail
NS=cka-q08
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-cleanup
  namespace: cka-q08
spec:
  schedule: "0 0 * * *"
  timeZone: "UTC"
  concurrencyPolicy: Allow
  suspend: true
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: cleanup
            image: busybox:1.36
            command: ["sh","-c","date; echo cleanup"]
YAML
exit 0
