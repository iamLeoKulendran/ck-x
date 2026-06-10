#!/bin/bash
set +e

fail() {
  echo "❌ $1"
  exit 1
}

pass() {
  echo "✅ $1"
  exit 0
}
NS=cka007-q06
DESIRED=$(kubectl get ds packet-capture -n "$NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
READY=$(kubectl get ds packet-capture -n "$NS" -o jsonpath='{.status.numberReady}' 2>/dev/null)
[ "${DESIRED:-0}" -ge 1 ] 2>/dev/null || fail "desiredNumberScheduled is ${DESIRED:-0}, expected at least 1"
[ "${READY:-0}" -ge 1 ] 2>/dev/null || fail "numberReady is ${READY:-0}, expected at least 1"
[ "${READY:-0}" -ge "${DESIRED:-0}" ] 2>/dev/null || fail "not all desired pods are ready (ready=${READY:-0}, desired=${DESIRED:-0})"
pass "packet-capture has ${READY} ready pod(s) on labeled node(s)"
