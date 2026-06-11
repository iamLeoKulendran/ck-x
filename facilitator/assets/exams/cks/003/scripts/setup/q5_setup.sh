#!/bin/bash
set -euo pipefail

NS="access-review"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

mkdir -p /tmp/exam/q5
rm -f /tmp/exam/q5/findings.txt

# Broken state: a custom ClusterRole grants secret/node read to unauthenticated users
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: ServiceAccount
metadata:
  name: release-bot
  namespace: access-review
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: telemetry-export
rules:
- apiGroups: [""]
  resources: ["secrets", "nodes"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: telemetry-public-access
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: telemetry-export
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:unauthenticated
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: release-bot-read
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: ServiceAccount
  name: release-bot
  namespace: access-review
YAML

echo "Question 5 setup complete"
