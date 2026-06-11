#!/bin/bash
set -euo pipefail

mkdir -p /tmp/exam/q14
rm -f /tmp/exam/q14/findings.txt

# Plant a deterministic API server audit log extract (one JSON event per line).
# The offender system:serviceaccount:ops:snapshot-sa performs `get` on `secrets`
# in namespace `vault-system` exactly 4 times. Other events are noise.
cat > /tmp/exam/q14/audit.log <<'LOG'
{"kind":"Event","verb":"get","user":{"username":"system:serviceaccount:ops:snapshot-sa"},"objectRef":{"resource":"secrets","namespace":"vault-system","name":"db-root"},"responseStatus":{"code":200}}
{"kind":"Event","verb":"list","user":{"username":"system:serviceaccount:apps:web-sa"},"objectRef":{"resource":"pods","namespace":"apps"},"responseStatus":{"code":200}}
{"kind":"Event","verb":"get","user":{"username":"system:serviceaccount:ops:snapshot-sa"},"objectRef":{"resource":"secrets","namespace":"vault-system","name":"tls-cert"},"responseStatus":{"code":200}}
{"kind":"Event","verb":"get","user":{"username":"system:serviceaccount:apps:web-sa"},"objectRef":{"resource":"configmaps","namespace":"apps","name":"web-config"},"responseStatus":{"code":200}}
{"kind":"Event","verb":"get","user":{"username":"system:serviceaccount:ops:snapshot-sa"},"objectRef":{"resource":"secrets","namespace":"vault-system","name":"api-token"},"responseStatus":{"code":200}}
{"kind":"Event","verb":"watch","user":{"username":"system:serviceaccount:kube-system:controller"},"objectRef":{"resource":"endpoints","namespace":"kube-system"},"responseStatus":{"code":200}}
{"kind":"Event","verb":"delete","user":{"username":"system:serviceaccount:apps:web-sa"},"objectRef":{"resource":"pods","namespace":"apps","name":"web-1"},"responseStatus":{"code":200}}
{"kind":"Event","verb":"get","user":{"username":"system:serviceaccount:ops:snapshot-sa"},"objectRef":{"resource":"secrets","namespace":"vault-system","name":"signing-key"},"responseStatus":{"code":200}}
{"kind":"Event","verb":"create","user":{"username":"system:serviceaccount:ops:snapshot-sa"},"objectRef":{"resource":"pods","namespace":"ops","name":"snapshot-job"},"responseStatus":{"code":201}}
{"kind":"Event","verb":"get","user":{"username":"system:serviceaccount:apps:web-sa"},"objectRef":{"resource":"secrets","namespace":"apps","name":"web-tls"},"responseStatus":{"code":200}}
LOG

echo "Question 14 setup complete"
