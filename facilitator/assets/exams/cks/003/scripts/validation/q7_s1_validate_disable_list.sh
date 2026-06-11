#!/bin/bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }
FILE="/tmp/exam/q7/disable-list.txt"

[ -f "$FILE" ] || fail "Answer file $FILE not found"

for unit in docker.service rpcbind.service telnet.socket vsftpd.service; do
  grep -qx "$unit" "$FILE" || fail "disable-list.txt must contain $unit on its own line"
done

LINES=$(grep -cve '^[[:space:]]*$' "$FILE" || true)
[ "$LINES" -eq 4 ] || fail "disable-list.txt must contain exactly 4 unit names, found $LINES non-empty lines"

if grep -qE 'sshd|containerd|kubelet|cron\.service|dbus|systemd-' "$FILE"; then
  fail "disable-list.txt wrongly includes a baseline-approved unit"
fi

echo "PASS: baseline-violating units correctly identified"
exit 0
