#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q25/backup-etcd.sh
[ -x "$FILE" ] || fail "$FILE is missing or not executable"
grep -q 'ETCDCTL_API=3' "$FILE" || fail "Script must set ETCDCTL_API=3"
grep -q 'etcdctl snapshot save' "$FILE" || fail "Script must run etcdctl snapshot save"
grep -q '/tmp/exam/q25/etcd-backup.db' "$FILE" || fail "Snapshot path must be /tmp/exam/q25/etcd-backup.db"
pass "Etcd backup script command is present"
