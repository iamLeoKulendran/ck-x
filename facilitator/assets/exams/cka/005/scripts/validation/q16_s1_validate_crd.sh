#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl get crd databasebackups.ops.example.com >/dev/null 2>&1 \
  || fail "CRD databasebackups.ops.example.com not found"
STATE=$(kubectl get crd databasebackups.ops.example.com \
  -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null || echo "")
[ "$STATE" = "True" ] || fail "CRD not Established (status='$STATE')"
pass "CRD databasebackups.ops.example.com is Established"
