#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
F="/tmp/exam/q12/findings.txt"

[ -s "$F" ] || fail "findings.txt missing or empty at $F"

# Must contain Trivy Kubernetes security check IDs (KSV...) - at least two distinct
COUNT=$(grep -oiE 'KSV-?[0-9]+' "$F" | sort -u | wc -l)
[ "$COUNT" -ge 2 ] || fail "findings.txt must contain at least two distinct KSV check IDs (found: $COUNT)"

# Must surface the privileged-container finding
grep -qi "privileged" "$F" || fail "findings.txt must report the privileged container misconfiguration"

echo "PASS: findings.txt contains the trivy KSV findings including the privileged check"
exit 0
