#!/bin/bash
set -euo pipefail
rm -f /etc/kubernetes/manifests/q22-static-web.yaml 2>/dev/null || true
kubectl delete pod -n default -l static-pod=q22-static-web --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
