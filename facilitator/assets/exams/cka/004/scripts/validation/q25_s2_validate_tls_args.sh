#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q25/backup-etcd.sh
grep -q 'https://127.0.0.1:2379' "$FILE" || fail "Script must use endpoint https://127.0.0.1:2379"
grep -q -- '--cacert=.*/etc/kubernetes/pki/etcd/ca.crt\|--cacert /etc/kubernetes/pki/etcd/ca.crt' "$FILE" || fail "Missing --cacert /etc/kubernetes/pki/etcd/ca.crt"
grep -q -- '--cert=.*/etc/kubernetes/pki/etcd/server.crt\|--cert /etc/kubernetes/pki/etcd/server.crt' "$FILE" || fail "Missing --cert /etc/kubernetes/pki/etcd/server.crt"
grep -q -- '--key=.*/etc/kubernetes/pki/etcd/server.key\|--key /etc/kubernetes/pki/etcd/server.key' "$FILE" || fail "Missing --key /etc/kubernetes/pki/etcd/server.key"
pass "Etcd backup TLS arguments are correct"
