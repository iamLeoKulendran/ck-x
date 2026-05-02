#!/bin/bash
set -euo pipefail
NS="rev1-q06"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete pod data-processor --ignore-not-found=true
sleep 2
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: data-processor
  namespace: rev1-q06
spec:
  containers:
  - name: processor
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /data/output/log; sleep 2; done"]
    volumeMounts:
    - name: output-vol
      mountPath: /data/output
      readOnly: true
  volumes:
  - name: output-vol
    emptyDir: {}
EOF
echo "Q6 setup complete"
