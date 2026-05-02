#!/bin/bash
set -euo pipefail
NS="rev1-q12"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q12
rm -rf /tmp/exam/q12/overlay

cat > /tmp/exam/q12/app.properties <<'EOF'
app.name=myapp
app.version=1.0
app.env=production
EOF

echo "Q12 setup complete"
