#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
USER="system:serviceaccount:cka-q11:node-reader"
[ "$(kubectl auth can-i get nodes --as "$USER")" = "yes" ] || fail "node-reader cannot get nodes"
[ "$(kubectl auth can-i list nodes --as "$USER")" = "yes" ] || fail "node-reader cannot list nodes"
[ "$(kubectl auth can-i watch nodes --as "$USER")" = "yes" ] || fail "node-reader cannot watch nodes"
pass "ClusterRole permissions are correct"
