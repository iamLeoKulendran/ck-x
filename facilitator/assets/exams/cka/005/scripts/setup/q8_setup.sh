#!/bin/bash
set -euo pipefail
NS="rev1-q08"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q8

# Detect actual worker node (not control-plane)
NODE=$(kubectl get nodes --no-headers \
  -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}')
echo "$NODE" > /tmp/exam/q8/target-node.txt

# Uncordon in case leftover from prior run
kubectl uncordon "$NODE" 2>/dev/null || true

kubectl -n "$NS" delete deployment api-pdb-app --ignore-not-found=true
kubectl -n "$NS" delete pdb api-pdb --ignore-not-found=true
sleep 3

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-pdb-app
  namespace: rev1-q08
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-pdb-app
  template:
    metadata:
      labels:
        app: api-pdb-app
    spec:
      containers:
      - name: app
        image: nginx:1.27
EOF

kubectl -n "$NS" rollout status deployment/api-pdb-app --timeout=90s || true

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
  namespace: rev1-q08
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: api-pdb-app
EOF

echo "Q8 setup complete — target node: $(cat /tmp/exam/q8/target-node.txt)"
