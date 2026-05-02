#!/bin/bash
set -euo pipefail
NS="rev1-q11"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get resourcequota cpu-quota >/dev/null 2>&1 || fail "ResourceQuota cpu-quota not found"
USED=$(kubectl -n "$NS" get resourcequota cpu-quota \
  -o jsonpath='{.status.used.requests\.cpu}' 2>/dev/null || echo "")
HARD=$(kubectl -n "$NS" get resourcequota cpu-quota \
  -o jsonpath='{.status.hard.requests\.cpu}' 2>/dev/null || echo "")
[ -n "$USED" ] || fail "Could not read ResourceQuota used CPU"
[ -n "$HARD" ] || fail "Could not read ResourceQuota hard CPU"
pass "ResourceQuota CPU: used=$USED hard=$HARD (within quota)"
