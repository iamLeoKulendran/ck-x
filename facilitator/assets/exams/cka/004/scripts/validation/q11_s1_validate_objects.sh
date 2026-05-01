#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
kubectl get clusterrole q11-node-reader >/dev/null 2>&1 || fail "ClusterRole q11-node-reader not found"
kubectl get clusterrolebinding q11-node-reader >/dev/null 2>&1 || fail "ClusterRoleBinding q11-node-reader not found"
SUBJ=$(kubectl get clusterrolebinding q11-node-reader -o jsonpath='{.subjects[0].namespace}:{.subjects[0].name}')
[ "$SUBJ" = "cka-q11:node-reader" ] || fail "ClusterRoleBinding subject must be cka-q11:node-reader"
pass "Cluster RBAC objects exist"
