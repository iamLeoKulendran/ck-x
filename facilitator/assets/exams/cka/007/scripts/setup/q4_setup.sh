#!/bin/bash
set -euo pipefail
NS=cka007-q04

# P2.2: remove q16 taints so this question is self-contained
for _n in $(kubectl get nodes -o name | cut -d/ -f2); do
  kubectl taint node "$_n" q16.pool=reserved:NoSchedule- 2>/dev/null || true
  kubectl taint node "$_n" q16.soft=reserved:PreferNoSchedule- 2>/dev/null || true
done

# P2.3: keep hard delete — StatefulSet VCT creates PVCs that must be fully purged
kubectl delete ns "$NS" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
kubectl create ns "$NS" >/dev/null

# Create 'standard' StorageClass using local-path provisioner so the question's
# storageClassName: standard resolves correctly on k3d/K3s.
kubectl apply -f - >/dev/null 2>&1 <<'SC' || true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
SC

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Service
metadata:
  name: metrics-store-hl
  namespace: cka007-q04
spec:
  clusterIP: None
  selector:
    app: metrics-store
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: metrics-store
  namespace: cka007-q04
spec:
  serviceName: metrics-store-hl
  replicas: 2
  selector:
    matchLabels:
      app: metrics-store
  template:
    metadata:
      labels:
        app: metrics-store
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
        volumeMounts:
        - name: cache
          mountPath: /usr/share/nginx/html
      volumes:
      - name: cache
        emptyDir: {}
YAML
exit 0
