#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

NS=rbac-sec-q19
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q19
rm -f /tmp/exam/q19/dev.kubeconfig
exit 0
