#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam/q7
rm -f /tmp/exam/q7/kube-dev /tmp/exam/q7/kube-prod /tmp/exam/q7/merged-config.yaml

# Get cluster server and token
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
TOKEN=$(kubectl create token default --duration=8760h 2>/dev/null || \
        kubectl get secret -n default -o jsonpath='{.items[0].data.token}' 2>/dev/null | base64 -d || \
        echo "placeholder-token")

cat > /tmp/exam/q7/kube-dev <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: ${SERVER}
    insecure-skip-tls-verify: true
  name: dev-cluster
contexts:
- context:
    cluster: dev-cluster
    user: dev-user
    namespace: default
  name: dev-context
current-context: dev-context
users:
- name: dev-user
  user:
    token: ${TOKEN}
EOF

cat > /tmp/exam/q7/kube-prod <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: ${SERVER}
    insecure-skip-tls-verify: true
  name: prod-cluster
contexts:
- context:
    cluster: prod-cluster
    user: prod-user
    namespace: default
  name: prod-context
current-context: prod-context
users:
- name: prod-user
  user:
    token: ${TOKEN}
EOF

echo "Q7 setup complete"
