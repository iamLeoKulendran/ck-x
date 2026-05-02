#!/bin/bash
set -euo pipefail
NS="rev1-q11"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete deployment batch-worker filler-app --ignore-not-found=true
kubectl -n "$NS" delete resourcequota cpu-quota --ignore-not-found=true
sleep 3

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cpu-quota
  namespace: rev1-q11
spec:
  hard:
    requests.cpu: "500m"
    limits.cpu: "1000m"
EOF

# Filler deployment consumes 350m CPU — leaves only 150m available
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filler-app
  namespace: rev1-q11
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filler-app
  template:
    metadata:
      labels:
        app: filler-app
    spec:
      containers:
      - name: app
        image: nginx:1.27
        resources:
          requests:
            cpu: "350m"
          limits:
            cpu: "350m"
EOF

kubectl -n "$NS" rollout status deployment/filler-app --timeout=60s || true

# batch-worker requests 300m — exceeds remaining 150m quota
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-worker
  namespace: rev1-q11
spec:
  replicas: 1
  selector:
    matchLabels:
      app: batch-worker
  template:
    metadata:
      labels:
        app: batch-worker
    spec:
      containers:
      - name: worker
        image: nginx:1.27
        resources:
          requests:
            cpu: "300m"
          limits:
            cpu: "300m"
EOF

echo "Q11 setup complete"
