#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q13/Dockerfile"

[ -f "$FILE" ] || fail "Dockerfile $FILE not found"

# Base image must be pinned (not latest, not untagged)
FROM_LINE=$(grep -i '^FROM' "$FILE" | head -1)
[ -n "$FROM_LINE" ] || fail "Dockerfile has no FROM instruction"
echo "$FROM_LINE" | grep -q ":latest" && fail "Base image must not use the latest tag" || true
echo "$FROM_LINE" | awk '{print $2}' | grep -q ":" || fail "Base image must be pinned to an explicit tag"

# Must run as a non-root user
USER_LINE=$(grep -i '^USER' "$FILE" | tail -1)
[ -n "$USER_LINE" ] || fail "Dockerfile must add a USER instruction for a non-root user"
echo "$USER_LINE" | awk '{print $2}' | grep -qiE '^(root|0)$' && fail "USER must not be root" || true

# Dangerous patterns must be gone
grep -qiE 'curl[^|]*\|\s*(ba)?sh' "$FILE" && fail "curl | sh pattern must be removed" || true
grep -qiE '^ADD\s+https?://' "$FILE" && fail "Remote ADD must be removed" || true
grep -q "API_TOKEN" "$FILE" && fail "Hardcoded API token must be removed" || true

echo "PASS: Dockerfile hardened (pinned base, non-root user, no unsafe fetch, no embedded secret)"
exit 0
