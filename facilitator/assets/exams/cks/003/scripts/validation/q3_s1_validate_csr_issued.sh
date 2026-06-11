#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

kubectl get csr dev-lena >/dev/null 2>&1 || fail "CertificateSigningRequest dev-lena not found"
JSON=$(kubectl get csr dev-lena -o json)

[ "$(echo "$JSON" | jq -r '.spec.signerName')" = "kubernetes.io/kube-apiserver-client" ] || fail "CSR signerName must be kubernetes.io/kube-apiserver-client"
echo "$JSON" | jq -e '.spec.usages | index("client auth")' >/dev/null || fail "CSR usages must include client auth"
[ "$(echo "$JSON" | jq -r '.status.conditions[]? | select(.type=="Approved") | .status' | head -1)" = "True" ] || fail "CSR dev-lena is not approved"
[ -n "$(echo "$JSON" | jq -r '.status.certificate // empty')" ] || fail "CSR dev-lena has no issued certificate"

[ -s /tmp/exam/q3/dev-lena.key ] || fail "/tmp/exam/q3/dev-lena.key is missing or empty"
[ -s /tmp/exam/q3/dev-lena.csr ] || fail "/tmp/exam/q3/dev-lena.csr is missing or empty"
grep -q "BEGIN CERTIFICATE" /tmp/exam/q3/dev-lena.crt 2>/dev/null || fail "/tmp/exam/q3/dev-lena.crt must contain the issued PEM certificate"

echo "PASS: CSR approved and certificate issued for dev-lena"
exit 0
