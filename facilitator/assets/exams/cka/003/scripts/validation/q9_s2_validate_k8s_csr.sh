#!/bin/bash
set +e
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
can_i() {
  local expected="$1"
  shift
  local result
  result=$(kubectl auth can-i "$@" 2>/dev/null | tr -d '\r\n')
  [ "$result" = "$expected" ]
}

CSR=q9-user
kubectl get csr "$CSR" >/dev/null 2>&1 || fail "Kubernetes CSR q9-user missing"
SIGNER=$(kubectl get csr "$CSR" -o jsonpath='{.spec.signerName}' 2>/dev/null)
USAGES=$(kubectl get csr "$CSR" -o jsonpath='{.spec.usages[*]}' 2>/dev/null)
CERT=$(kubectl get csr "$CSR" -o jsonpath='{.status.certificate}' 2>/dev/null)
[ "$SIGNER" = "kubernetes.io/kube-apiserver-client" ] || fail "signerName must be kubernetes.io/kube-apiserver-client"
echo "$USAGES" | grep -qi 'client auth' || fail "CSR must include client auth usage"
[ -n "$CERT" ] || fail "CSR is not approved or certificate is not issued"
pass "Kubernetes CSR is approved"
