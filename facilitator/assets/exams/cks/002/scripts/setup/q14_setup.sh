#!/bin/bash
set -euo pipefail

NS="audit-analysis"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/exam/q14
rm -f /tmp/exam/q14/secret-reader.txt /tmp/exam/q14/deleter.txt /tmp/exam/q14/anonymous-denied.txt

# Plant the audit log extract (JSON lines)
cat > /tmp/exam/q14/audit.log <<'LOG'
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"get","user":{"username":"alice@ckx.local","groups":["developers"]},"objectRef":{"resource":"secrets","namespace":"monitoring","name":"grafana-token"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:02:11Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"list","user":{"username":"system:serviceaccount:kube-system:generic-garbage-collector","groups":["system:serviceaccounts"]},"objectRef":{"resource":"configmaps","namespace":"kube-system"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:03:40Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"get","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"requestURI":"/api/v1/namespaces/finance/secrets/payroll-db","responseStatus":{"code":403},"requestReceivedTimestamp":"2026-06-10T08:05:02Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"get","user":{"username":"mallory@ckx.local","groups":["contractors"]},"objectRef":{"resource":"secrets","namespace":"finance","name":"payroll-db"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:06:13Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"watch","user":{"username":"system:serviceaccount:monitoring:prometheus","groups":["system:serviceaccounts"]},"objectRef":{"resource":"pods","namespace":"monitoring"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:07:55Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"get","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"requestURI":"/api/v1/namespaces/kube-system/pods","responseStatus":{"code":403},"requestReceivedTimestamp":"2026-06-10T08:09:30Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"update","user":{"username":"system:serviceaccount:ci:deploy-bot","groups":["system:serviceaccounts"]},"objectRef":{"resource":"configmaps","namespace":"staging","name":"build-cache"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:11:18Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"get","user":{"username":"mallory@ckx.local","groups":["contractors"]},"objectRef":{"resource":"secrets","namespace":"finance","name":"payroll-db"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:12:44Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"get","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"requestURI":"/version","responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:14:09Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"delete","user":{"username":"bob@ckx.local","groups":["developers"]},"objectRef":{"resource":"pods","namespace":"staging","name":"debug-shell"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:15:27Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"delete","user":{"username":"system:serviceaccount:ci:deploy-bot","groups":["system:serviceaccounts"]},"objectRef":{"resource":"deployments","namespace":"staging","name":"legacy-web"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:17:51Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"create","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"requestURI":"/api/v1/namespaces/default/pods","responseStatus":{"code":403},"requestReceivedTimestamp":"2026-06-10T08:19:33Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"list","user":{"username":"alice@ckx.local","groups":["developers"]},"objectRef":{"resource":"pods","namespace":"monitoring"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:21:14Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"get","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"requestURI":"/api/v1/nodes","responseStatus":{"code":403},"requestReceivedTimestamp":"2026-06-10T08:23:48Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","stage":"ResponseComplete","verb":"patch","user":{"username":"admin@ckx.local","groups":["system:masters"]},"objectRef":{"resource":"deployments","namespace":"production","name":"storefront"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2026-06-10T08:25:09Z"}
LOG

echo "Question 14 setup complete"
