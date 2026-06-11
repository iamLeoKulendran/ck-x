#!/bin/bash
set -euo pipefail

NS="supply-trust"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" delete deployment trusted-release --ignore-not-found=true >/dev/null 2>&1 || true

mkdir -p /tmp/exam/q13
rm -f /tmp/exam/q13/releaser.key /tmp/exam/q13/releaser.pub \
      /tmp/exam/q13/release-good.yaml /tmp/exam/q13/release-bad.yaml \
      /tmp/exam/q13/release-good.sig /tmp/exam/q13/release-bad.sig \
      /tmp/exam/q13/sbom.json /tmp/exam/q13/verified.txt

export COSIGN_PASSWORD=""
cosign generate-key-pair --output-key-prefix /tmp/exam/q13/releaser >/dev/null 2>&1

cat > /tmp/exam/q13/release-good.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trusted-release
  namespace: supply-trust
  labels:
    app: trusted-release
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trusted-release
  template:
    metadata:
      labels:
        app: trusted-release
    spec:
      containers:
      - name: app
        image: registry.localhost:5000/ckx/nginx:v1.25
        ports:
        - containerPort: 80
YAML

cat > /tmp/exam/q13/release-bad.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rogue-release
  namespace: supply-trust
  labels:
    app: rogue-release
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rogue-release
  template:
    metadata:
      labels:
        app: rogue-release
    spec:
      containers:
      - name: app
        image: registry.localhost:5000/ckx/nginx:v1.25
        ports:
        - containerPort: 80
YAML

SIGN_FLAGS="--use-signing-config=false --tlog-upload=false --new-bundle-format=false --yes"

cosign sign-blob --key /tmp/exam/q13/releaser.key $SIGN_FLAGS \
  --output-signature /tmp/exam/q13/release-good.sig /tmp/exam/q13/release-good.yaml >/dev/null 2>&1

cosign sign-blob --key /tmp/exam/q13/releaser.key $SIGN_FLAGS \
  --output-signature /tmp/exam/q13/release-bad.sig /tmp/exam/q13/release-bad.yaml >/dev/null 2>&1

# Supply-chain tamper: release-bad is modified AFTER signing, invalidating its signature
cat >> /tmp/exam/q13/release-bad.yaml <<'YAML'
      # injected: privileged debug access added post-signing
YAML

# Remove the private key so only the public key remains for verification
rm -f /tmp/exam/q13/releaser.key

echo "Question 13 setup complete"
