#!/bin/bash
set +e

fail() {
  echo "❌ $1"
  exit 1
}

pass() {
  echo "✅ $1"
  exit 0
}
NS=cka-q10
SVC_SEL=$(kubectl get svc catalog-web -n "$NS" -o jsonpath='{.spec.selector.app}' 2>/dev/null)
POD_LABEL=$(kubectl get deploy catalog-web -n "$NS" -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
[ "$SVC_SEL" = "catalog-web" ] || fail "service selector app is $SVC_SEL"
[ "$POD_LABEL" = "$SVC_SEL" ] || fail "pod label app $POD_LABEL does not match service selector $SVC_SEL"
pass "service selector matches pods"
