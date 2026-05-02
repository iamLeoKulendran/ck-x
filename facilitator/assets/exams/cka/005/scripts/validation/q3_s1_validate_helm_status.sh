#!/bin/bash
set -euo pipefail
NS="rev1-q03"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }

# The task requires two explicit operations: rollback then upgrade.
# Setup leaves the release at revision 2 (bad-tag upgrade).
# A rollback creates revision 3. A subsequent upgrade creates revision 4.
# Requiring revision >= 3 ensures the candidate performed at least the rollback step.
REV=$(helm history web-frontend -n "$NS" --max 1 -o json 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['revision'])" 2>/dev/null \
  || echo "0")
STATUS=$(helm status web-frontend -n "$NS" -o json 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['info']['status'])" 2>/dev/null \
  || echo "")

[ "${REV:-0}" -ge 3 ] \
  || fail "Release still at revision ${REV:-0} — rollback not yet performed (need revision >= 3)"
[ "$STATUS" = "deployed" ] \
  || fail "Helm release status='$STATUS', expected 'deployed'"

pass "Helm release web-frontend is deployed at revision $REV"
