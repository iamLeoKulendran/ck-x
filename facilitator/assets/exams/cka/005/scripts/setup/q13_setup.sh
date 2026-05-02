#!/bin/bash
set -euo pipefail
NS="rev1-q13"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Create 'standard' StorageClass using local-path provisioner
kubectl apply -f - <<'EOF' 2>/dev/null || true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl -n "$NS" delete statefulset cache-cluster --ignore-not-found=true
sleep 3

# StatefulSet with broken storageClassName — pods stay Pending
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cache-cluster
  namespace: rev1-q13
spec:
  serviceName: cache-cluster
  replicas: 2
  selector:
    matchLabels:
      app: cache-cluster
  template:
    metadata:
      labels:
        app: cache-cluster
    spec:
      containers:
      - name: cache
        image: nginx:1.27
        ports:
        - containerPort: 80
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: premium-nvme
      resources:
        requests:
          storage: 100Mi
EOF

echo "Q13 setup complete"
