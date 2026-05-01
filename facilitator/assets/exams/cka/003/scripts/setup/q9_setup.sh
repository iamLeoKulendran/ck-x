#!/bin/bash
set -euo pipefail
mkdir -p /tmp/exam

mkdir -p /tmp/exam/q9
rm -f /tmp/exam/q9/q9-user.key /tmp/exam/q9/q9-user.csr
kubectl delete csr q9-user >/dev/null 2>&1 || true
exit 0
