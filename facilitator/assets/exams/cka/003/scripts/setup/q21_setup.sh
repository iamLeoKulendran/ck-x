#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

mkdir -p /tmp/exam/q21
rm -f /tmp/exam/q21/q21-kubelet-serving.key /tmp/exam/q21/q21-kubelet-serving.csr
kubectl delete csr q21-kubelet-serving >/dev/null 2>&1 || true
exit 0
