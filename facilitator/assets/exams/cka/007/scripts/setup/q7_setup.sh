#!/bin/bash
set -euo pipefail
NS=cka007-q07

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
mkdir -p /tmp/exam/q07
cat > /tmp/exam/q07/checksum-job.yaml <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: checksum-job
  namespace: cka007-q07
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
