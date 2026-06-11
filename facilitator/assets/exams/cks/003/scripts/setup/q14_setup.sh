#!/bin/bash
set -euo pipefail

kubectl create namespace audit-policy --dry-run=client -o yaml | kubectl apply -f - >/dev/null

mkdir -p /tmp/exam/q14
rm -f /tmp/exam/q14/audit-policy.yaml

cat > /tmp/exam/q14/requirements.txt <<'REQ'
Audit policy requirements (see the exam question for full details):
- apiVersion: audit.k8s.io/v1, kind: Policy
- omitStages: RequestReceived
- Rule 1: secrets (core group) at RequestResponse
- Rule 2: None for watch on endpoints/services by system:kube-proxy
- Rule 3: RequestResponse for create on pods/exec
- Rule 4 (last): catch-all at Metadata
REQ

echo "Question 14 setup complete"
