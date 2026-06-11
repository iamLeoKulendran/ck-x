#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="ci-pipeline"
SA="system:serviceaccount:ci-pipeline:build-bot"

[ "$(kubectl auth can-i get pods -n "$NS" --as="$SA")" = "yes" ] || fail "build-bot must be able to get pods in $NS"
[ "$(kubectl auth can-i list pods -n "$NS" --as="$SA")" = "yes" ] || fail "build-bot must be able to list pods in $NS"
[ "$(kubectl auth can-i get pods/log -n "$NS" --as="$SA")" = "yes" ] || fail "build-bot must be able to read pod logs in $NS"

# Denied behavior in the same namespace proves least privilege (fails while cluster-admin binding exists)
[ "$(kubectl auth can-i delete pods -n "$NS" --as="$SA")" = "no" ] || fail "build-bot must NOT be able to delete pods in $NS"

echo "PASS: build-bot has the required read access and no delete rights"
exit 0
