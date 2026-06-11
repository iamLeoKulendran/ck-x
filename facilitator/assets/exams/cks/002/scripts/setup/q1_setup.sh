#!/bin/bash
set -euo pipefail

NS="web-tier"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Reset: remove any candidate-created policies so the question starts open
kubectl -n "$NS" delete networkpolicy --all --ignore-not-found=true >/dev/null 2>&1 || true

for APP in web api cache; do
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP}
  namespace: web-tier
  labels:
    app: ${APP}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP}
  template:
    metadata:
      labels:
        app: ${APP}
    spec:
      containers:
      - name: ${APP}
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
YAML
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Service
metadata:
  name: ${APP}-svc
  namespace: web-tier
spec:
  selector:
    app: ${APP}
  ports:
  - port: 80
    targetPort: 80
YAML
done

kubectl -n "$NS" rollout status deployment/web --timeout=120s >/dev/null 2>&1 || true
kubectl -n "$NS" rollout status deployment/api --timeout=120s >/dev/null 2>&1 || true
kubectl -n "$NS" rollout status deployment/cache --timeout=120s >/dev/null 2>&1 || true

echo "Question 1 setup complete"
