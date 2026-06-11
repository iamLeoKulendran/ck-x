# CKS Mock Exam - 3 (cks-004) — Answer Key

All images are served from the internal CK-X registry. The jumphost pushes/pulls
as `registry:5000/ckx/<image>:<tag>`; Kubernetes pod specs reference the same
images through the containerd mirror alias `registry.localhost:5000/ckx/<image>:<tag>`.
The registry is internal-only — no public port is exposed.

---

## Question 1 — Default-deny + trusted-only ingress (frontend-zone)

**Goal:** lock `frontend-zone` to a default-deny posture, then allow only `tier=trusted` namespaces to reach `storefront` on port 80.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: frontend-zone
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-trusted-clients
  namespace: frontend-zone
spec:
  podSelector:
    matchLabels:
      app: storefront
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: trusted
    ports:
    - protocol: TCP
      port: 80
EOF
```

**Verify:**
```bash
kubectl -n trusted-clients exec client -- wget -qO- -T5 http://storefront-svc.frontend-zone.svc.cluster.local   # works
kubectl -n untrusted-clients exec client -- wget -qO- -T5 http://storefront-svc.frontend-zone.svc.cluster.local  # times out
```

---

## Question 2 — TLS Ingress (gateway-edge)

**Goal:** create a `kubernetes.io/tls` secret from the provided cert/key and an Ingress that terminates TLS for `portal.ckx.local`.

```bash
kubectl -n gateway-edge create secret tls portal-tls \
  --cert=/tmp/exam/q2/tls.crt --key=/tmp/exam/q2/tls.key

kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portal-ingress
  namespace: gateway-edge
spec:
  tls:
  - hosts:
    - portal.ckx.local
    secretName: portal-tls
  rules:
  - host: portal.ckx.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: portal-svc
            port:
              number: 80
EOF
```

---

## Question 3 — RBAC least privilege (audit-team)

**Goal:** reduce the wildcard `report-role` to read-only on configmaps.

```bash
kubectl -n audit-team apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: report-role
  namespace: audit-team
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
EOF
```

**Verify:**
```bash
kubectl auth can-i get configmaps --as=system:serviceaccount:audit-team:report-sa -n audit-team   # yes
kubectl auth can-i get secrets    --as=system:serviceaccount:audit-team:report-sa -n audit-team   # no
kubectl auth can-i delete pods    --as=system:serviceaccount:audit-team:report-sa -n audit-team   # no
```

---

## Question 4 — RBAC: read pods/logs, deny exec (support-rbac)

**Goal:** `oncall-sa` reads pods and logs but cannot exec.

```bash
kubectl -n support-rbac apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: oncall-role
  namespace: support-rbac
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
EOF
```

**Verify:**
```bash
kubectl auth can-i get pods/log    --as=system:serviceaccount:support-rbac:oncall-sa -n support-rbac   # yes
kubectl auth can-i create pods/exec --as=system:serviceaccount:support-rbac:oncall-sa -n support-rbac  # no
```

---

## Question 5 — ValidatingAdmissionPolicy: trusted registry only (registry-guard)

**Goal:** only `registry.localhost:5000/` images may run in namespaces labelled `registry-policy=enforced`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: trusted-registry-only
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: "object.spec.containers.all(c, c.image.startsWith('registry.localhost:5000/'))"
    message: "images must come from registry.localhost:5000/"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: trusted-registry-only-binding
spec:
  policyName: trusted-registry-only
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        registry-policy: enforced
EOF
```

**Verify:**
```bash
kubectl -n registry-guard run bad --image=nginx:1.25 --restart=Never        # denied
kubectl -n registry-guard run ok --image=registry.localhost:5000/ckx/nginx:v1.25 --restart=Never  # admitted
kubectl -n registry-guard delete pod ok --ignore-not-found
```

> Note: if `initContainers` may be present, extend the expression with
> `&& object.spec.initContainers.all(...)` using `has(object.spec.initContainers)`.

---

## Question 6 — Harden container securityContext (system-lockdown)

```bash
# Strategic-merge patch (default) merges the container by name and keeps the image.
# Set add: [] explicitly to clear the contractor's SYS_ADMIN/NET_RAW additions.
kubectl -n system-lockdown patch deployment edge-cache -p '
spec:
  template:
    spec:
      containers:
      - name: cache
        securityContext:
          runAsNonRoot: true
          runAsUser: 10001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            add: []
            drop: ["ALL"]
'
kubectl -n system-lockdown rollout status deployment/edge-cache
```

> Use a strategic-merge patch (the default `kubectl patch`, no `--type=merge`). A JSON
> merge patch (`--type=merge`) replaces the whole `containers` array and drops the image.
> The existing `capabilities.add` list is only cleared if you set `add: []` — omitting it
> leaves `SYS_ADMIN`/`NET_RAW` in place.

Confirm there are no added caps:
```bash
kubectl -n system-lockdown get deploy edge-cache -o jsonpath='{.spec.template.spec.containers[0].securityContext}'; echo
```

---

## Question 7 — seccomp RuntimeDefault (syscall-lockdown)

```bash
kubectl -n syscall-lockdown patch deployment metrics-shipper -p '
spec:
  template:
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
'
kubectl -n syscall-lockdown rollout status deployment/metrics-shipper
```

---

## Question 8 — Restricted Pod Security Standard (microsvc-restricted)

```bash
kubectl label ns microsvc-restricted \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted --overwrite

kubectl -n microsvc-restricted patch deployment orders-ui -p '
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: ui
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
'
kubectl -n microsvc-restricted rollout status deployment/orders-ui
```

**Verify a violation is blocked:**
```bash
kubectl -n microsvc-restricted run psa-bad --image=registry.localhost:5000/ckx/nginx:v1.25 --privileged --restart=Never
# Error: violates PodSecurity "restricted"
```

---

## Question 9 — Secret hygiene + disable automount (payments-svc)

```bash
kubectl -n payments-svc create secret generic billing-db \
  --from-literal=password='S3cr3t-P@ss!'

# Replace the whole env array (a strategic merge of one env item would keep the old
# plaintext `value` alongside `valueFrom`, which the API rejects). A JSON patch that
# replaces the array removes the plaintext cleanly.
kubectl -n payments-svc patch deployment billing --type=json -p '[
  {"op":"replace","path":"/spec/template/spec/containers/0/env","value":[
     {"name":"DB_PASSWORD","valueFrom":{"secretKeyRef":{"name":"billing-db","key":"password"}}}
  ]}
]'

# Disable token automount with a strategic-merge patch
kubectl -n payments-svc patch deployment billing -p '
spec:
  template:
    spec:
      automountServiceAccountToken: false
'
kubectl -n payments-svc rollout status deployment/billing
```

> Confirm no plaintext remains:
> `kubectl -n payments-svc get deploy billing -o yaml | grep -n 'S3cr3t' || echo clean`

---

## Question 10 — Zero-trust egress (txn-mesh)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: processor-egress
  namespace: txn-mesh
spec:
  podSelector:
    matchLabels:
      app: processor
  policyTypes:
  - Egress
  egress:
  - ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  - to:
    - namespaceSelector:
        matchLabels:
          tier: ledger
    ports:
    - protocol: TCP
      port: 80
EOF
```

**Verify:**
```bash
kubectl -n txn-mesh exec deploy/processor -- wget -qO- -T5 http://ledger-svc.txn-ledger.svc.cluster.local   # works
kubectl -n txn-mesh exec deploy/processor -- wget -qO- -T5 http://ledger-svc.txn-public.svc.cluster.local   # blocked
```

---

## Question 11 — Digest pinning from the internal registry (supply-frontend)

```bash
# 1. Resolve the current digest
DIGEST=$(curl -sI -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  http://registry:5000/v2/ckx/nginx/manifests/v1.25 \
  | grep -i docker-content-digest | tr -d '\r' | awk '{print $2}')
echo "$DIGEST"

# 2. Pin the deployment to the digest
kubectl -n supply-frontend set image deployment/web-frontend \
  web=registry.localhost:5000/ckx/nginx@${DIGEST}
kubectl -n supply-frontend rollout status deployment/web-frontend
```

---

## Question 12 — trivy config scan + hardened deploy (supply-scan)

```bash
# 1. Scan the planted manifest (offline misconfig policies; no DB download)
trivy config /tmp/exam/q12/workload.yaml | tee /tmp/exam/q12/findings.txt

# 2. Deploy a hardened version from the internal registry
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanner-api
  namespace: supply-scan
  labels:
    app: scanner-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scanner-api
  template:
    metadata:
      labels:
        app: scanner-api
    spec:
      containers:
      - name: api
        image: registry.localhost:5000/ckx/alpine:3.20
        command: ["sleep", "infinity"]
        securityContext:
          runAsNonRoot: true
          runAsUser: 10001
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
EOF
kubectl -n supply-scan rollout status deployment/scanner-api
```

The `trivy config` report lists `KSV` check IDs including the privileged-container
finding (e.g. `KSV017`), `allowPrivilegeEscalation` (`KSV001`), and runs-as-root
(`KSV012`). The grading only requires the report to contain at least two distinct
`KSV` IDs and the privileged finding.

---

## Question 13 — SBOM + cosign verify (supply-trust)

```bash
# 1. SBOM for the internal-registry alpine image (works offline via the docker daemon)
docker pull registry:5000/ckx/alpine:3.20
syft docker:registry:5000/ckx/alpine:3.20 -o spdx-json > /tmp/exam/q13/sbom.json

# 2. Verify which manifest is authentic
cd /tmp/exam/q13
cosign verify-blob --key releaser.pub --signature release-good.sig --insecure-ignore-tlog release-good.yaml  # Verified OK
cosign verify-blob --key releaser.pub --signature release-bad.sig  --insecure-ignore-tlog release-bad.yaml   # fails
echo "release-good.yaml" > /tmp/exam/q13/verified.txt

# 3. Apply only the authentic manifest
kubectl apply -f /tmp/exam/q13/release-good.yaml
```

---

## Question 14 — Audit log analysis (runtime-audit)

```bash
LOG=/tmp/exam/q14/audit.log

# Who reads secrets?
jq -r 'select(.verb=="get" and .objectRef.resource=="secrets") | .user.username' "$LOG" | sort | uniq -c
# -> system:serviceaccount:ops:snapshot-sa is the heavy reader

USER=system:serviceaccount:ops:snapshot-sa
COUNT=$(jq -c "select(.user.username==\"$USER\" and .verb==\"get\" and .objectRef.resource==\"secrets\")" "$LOG" | wc -l)
NS=$(jq -r "select(.user.username==\"$USER\" and .verb==\"get\" and .objectRef.resource==\"secrets\") | .objectRef.namespace" "$LOG" | sort -u | head -1)

cat > /tmp/exam/q14/findings.txt <<EOF
user=$USER
count=$COUNT
namespace=$NS
EOF
cat /tmp/exam/q14/findings.txt
```

Expected result: `user=system:serviceaccount:ops:snapshot-sa`, `count=4`, `namespace=vault-system`.

---

## Question 15 — Contain a compromised workload (runtime-soc)

```bash
# Remove the debug sidecar and harden api in one merge, then add default-deny.
kubectl -n runtime-soc patch deployment ingest-api --type=json -p '[
  {"op":"remove","path":"/spec/template/spec/containers/1"}
]'

kubectl -n runtime-soc patch deployment ingest-api -p '
spec:
  template:
    spec:
      containers:
      - name: api
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
'

kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: soc-default-deny
  namespace: runtime-soc
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
kubectl -n runtime-soc rollout status deployment/ingest-api
```

> The `remove` op deletes container index 1 (`debug`). If your editor reorders
> containers, instead re-apply the full deployment with only the `api` container.

---

## Question 16 — Immutable root filesystem (runtime-immutable)

```bash
kubectl -n runtime-immutable patch deployment log-rotator -p '
spec:
  template:
    spec:
      volumes:
      - name: spool
        emptyDir: {}
      containers:
      - name: rotator
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: spool
          mountPath: /var/spool/app
'
kubectl -n runtime-immutable rollout status deployment/log-rotator
```

The container keeps appending to `/var/spool/app/out.log`, which now lives on the
writable `emptyDir` while the rest of the root filesystem is read-only.
