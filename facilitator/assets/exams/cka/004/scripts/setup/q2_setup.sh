#!/bin/bash
set -euo pipefail
kubectl delete pod q2-control-plane-pod -n default --ignore-not-found=true >/dev/null 2>&1 || true
exit 0
