#!/bin/bash
set -euo pipefail

NS="artifact-trust"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/exam/q12
rm -f /tmp/exam/q12/signer.key /tmp/exam/q12/signer.pub \
      /tmp/exam/q12/release-a.yaml /tmp/exam/q12/release-b.yaml \
      /tmp/exam/q12/release-a.sig /tmp/exam/q12/release-b.sig \
      /tmp/exam/q12/verify-result.txt

# Reset cluster state
kubectl -n "$NS" delete deployment trusted-api rogue-api --ignore-not-found=true >/dev/null 2>&1 || true

export COSIGN_PASSWORD=""
cosign generate-key-pair --output-key-prefix /tmp/exam/q12/signer >/dev/null 2>&1

cat > /tmp/exam/q12/release-a.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trusted-api
  namespace: artifact-trust
  labels:
    app: trusted-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trusted-api
  template:
    metadata:
      labels:
        app: trusted-api
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
YAML

cat > /tmp/exam/q12/release-b.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rogue-api
  namespace: artifact-trust
  labels:
    app: rogue-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rogue-api
  template:
    metadata:
      labels:
        app: rogue-api
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
YAML

SIGN_FLAGS="--use-signing-config=false --tlog-upload=false --new-bundle-format=false --yes"

cosign sign-blob --key /tmp/exam/q12/signer.key $SIGN_FLAGS \
  --output-signature /tmp/exam/q12/release-a.sig /tmp/exam/q12/release-a.yaml >/dev/null 2>&1

cosign sign-blob --key /tmp/exam/q12/signer.key $SIGN_FLAGS \
  --output-signature /tmp/exam/q12/release-b.sig /tmp/exam/q12/release-b.yaml >/dev/null 2>&1

# Supply-chain attack simulation: release-b is modified AFTER signing
cat >> /tmp/exam/q12/release-b.yaml <<'YAML'
      # hotfix: temporary debug access
YAML

rm -f /tmp/exam/q12/signer.key

echo "Question 12 setup complete"
