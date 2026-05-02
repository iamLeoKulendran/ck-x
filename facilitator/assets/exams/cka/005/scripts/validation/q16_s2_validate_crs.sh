#!/bin/bash
set -euo pipefail
NS="rev1-q16"
fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; exit 0; }
kubectl -n "$NS" get databasebackup weekly-pg >/dev/null 2>&1 || fail "DatabaseBackup 'weekly-pg' not found in $NS"
kubectl -n "$NS" get databasebackup daily-mysql >/dev/null 2>&1 || fail "DatabaseBackup 'daily-mysql' not found in $NS"
PG_DB=$(kubectl -n "$NS" get databasebackup weekly-pg \
  -o jsonpath='{.spec.targetDB}' 2>/dev/null || echo "")
[ "$PG_DB" = "postgres" ] || fail "weekly-pg targetDB='$PG_DB', expected 'postgres'"
MYSQL_DB=$(kubectl -n "$NS" get databasebackup daily-mysql \
  -o jsonpath='{.spec.targetDB}' 2>/dev/null || echo "")
[ "$MYSQL_DB" = "mysql" ] || fail "daily-mysql targetDB='$MYSQL_DB', expected 'mysql'"
PG_RET=$(kubectl -n "$NS" get databasebackup weekly-pg \
  -o jsonpath='{.spec.retentionDays}' 2>/dev/null || echo "")
[ "$PG_RET" = "7" ] || fail "weekly-pg retentionDays='$PG_RET', expected '7'"
MYSQL_RET=$(kubectl -n "$NS" get databasebackup daily-mysql \
  -o jsonpath='{.spec.retentionDays}' 2>/dev/null || echo "")
[ "$MYSQL_RET" = "3" ] || fail "daily-mysql retentionDays='$MYSQL_RET', expected '3'"
pass "Both DatabaseBackup CRs exist with correct spec fields"
