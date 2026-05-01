#!/bin/bash
set -euo pipefail
NS=cka-q03
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: q3-data-store
  namespace: $NS
spec:
  clusterIP: None
  selector:
    app: q3-data-store
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: q3-data-store
  namespace: $NS
spec:
  serviceName: q3-data-store
  replicas: 3
  selector:
    matchLabels:
      app: q3-data-store
  template:
    metadata:
      labels:
        app: q3-data-store
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF
exit 0
