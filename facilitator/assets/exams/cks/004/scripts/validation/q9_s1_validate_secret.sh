#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
NS="payments-svc"

kubectl -n "$NS" get secret billing-db >/dev/null 2>&1 || fail "billing-db secret missing in $NS"

VAL=$(kubectl -n "$NS" get secret billing-db -o jsonpath='{.data.password}' | base64 -d)
[ "$VAL" = 'S3cr3t-P@ss!' ] || fail "billing-db.password does not equal the expected value"

echo "PASS: billing-db secret holds the expected password"
exit 0
