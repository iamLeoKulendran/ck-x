#!/bin/bash
set -euo pipefail
NS=cka007-q08

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete cronjob db-cleanup --ignore-not-found=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-cleanup
  namespace: cka007-q08
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
