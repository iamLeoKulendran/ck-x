#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q8
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q8
cat > /tmp/exam/q8/kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: broken-cluster
  cluster:
    server: https://127.0.0.2:6443
    insecure-skip-tls-verify: true
contexts:
- name: broken-context
  context:
    cluster: broken-cluster
    user: broken-user
    namespace: default
current-context: broken-context
users:
- name: broken-user
  user:
    token: broken
EOF
exit 0
