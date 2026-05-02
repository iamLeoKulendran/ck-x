#!/bin/bash
set -euo pipefail
NS="rev1-q02"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

kubectl -n "$NS" get deployment frontend >/dev/null 2>&1 \
  || fail "Deployment frontend not found"
kubectl -n "$NS" get service frontend-svc >/dev/null 2>&1 \
  || fail "Service frontend-svc not found"

# Verify that the fix was a targeted Service patch: containerPort in the Deployment
# must now match the Service targetPort. Before fix: containerPort=8080, targetPort=80 — mismatch.
CONTAINER_PORT=$(kubectl -n "$NS" get deployment frontend \
  -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}' 2>/dev/null || echo "")
SERVICE_TARGET=$(kubectl -n "$NS" get service frontend-svc \
  -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "")

[ -n "$CONTAINER_PORT" ] || fail "Could not read Deployment containerPort"
[ -n "$SERVICE_TARGET" ]  || fail "Could not read Service targetPort"
[ "$CONTAINER_PORT" = "$SERVICE_TARGET" ] \
  || fail "Deployment containerPort=$CONTAINER_PORT does not match Service targetPort=$SERVICE_TARGET — patch incomplete"

pass "Deployment containerPort ($CONTAINER_PORT) matches Service targetPort ($SERVICE_TARGET)"
