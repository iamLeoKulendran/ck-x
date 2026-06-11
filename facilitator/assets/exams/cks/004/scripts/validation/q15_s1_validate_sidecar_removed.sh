#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="runtime-soc"

kubectl -n "$NS" get deployment ingest-api >/dev/null 2>&1 || fail "ingest-api deployment missing"
JSON=$(kubectl -n "$NS" get deployment ingest-api -o json)

# The debug container must be gone
if echo "$JSON" | jq -e '[.spec.template.spec.containers[].name] | index("debug")' >/dev/null 2>&1; then
  fail "the malicious debug sidecar is still present"
fi

# Exactly one container (api) must remain
N=$(echo "$JSON" | jq '.spec.template.spec.containers | length')
[ "$N" -eq 1 ] || fail "ingest-api must have exactly one container, found $N"

echo "$JSON" | jq -e '.spec.template.spec.containers[0].name == "api"' >/dev/null \
  || fail "the remaining container must be the legitimate api container"

echo "PASS: debug sidecar removed; only api container remains"
exit 0
