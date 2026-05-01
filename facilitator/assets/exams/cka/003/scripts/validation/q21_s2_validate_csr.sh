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

CSR=q21-kubelet-serving
kubectl get csr "$CSR" >/dev/null 2>&1 || fail "Kubernetes CSR q21-kubelet-serving missing"
SIGNER=$(kubectl get csr "$CSR" -o jsonpath='{.spec.signerName}' 2>/dev/null)
USAGES=$(kubectl get csr "$CSR" -o jsonpath='{.spec.usages[*]}' 2>/dev/null)
COND=$(kubectl get csr "$CSR" -o jsonpath='{.status.conditions[*].type}' 2>/dev/null)
[ "$SIGNER" = "kubernetes.io/kubelet-serving" ] || fail "signerName must be kubernetes.io/kubelet-serving"
echo "$USAGES" | grep -qi 'server auth' || fail "CSR must include server auth usage"
echo "$USAGES" | grep -qi 'digital signature' || fail "CSR must include digital signature usage"
echo "$USAGES" | grep -qi 'key encipherment' || fail "CSR must include key encipherment usage"
echo "$COND" | grep -qw Approved || fail "CSR is not approved"
pass "Kubelet serving CSR is approved"
