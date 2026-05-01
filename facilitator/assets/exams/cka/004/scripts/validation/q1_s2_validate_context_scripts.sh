#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
DIR=/tmp/exam/q1
KFILE="$DIR/context_default_kubectl.sh"
NFILE="$DIR/context_default_no_kubectl.sh"
[ -s "$KFILE" ] || fail "Missing $KFILE"
[ -s "$NFILE" ] || fail "Missing $NFILE"
grep -q "kubectl" "$KFILE" || fail "$KFILE must use kubectl"
grep -q "current-context" "$KFILE" || fail "$KFILE must print current context"
! grep -q "kubectl" "$NFILE" || fail "$NFILE must not use kubectl"
grep -Eq "current-context|\.kube/config|KUBECONFIG" "$NFILE" || fail "$NFILE should read current context from kubeconfig"
pass "Current-context scripts are valid"
