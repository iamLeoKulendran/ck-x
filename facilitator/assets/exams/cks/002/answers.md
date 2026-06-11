# Answers - Mock Exam - CKS - 1 (cks-002)

## Question 1 - Zero-trust segmentation in web-tier

Goal: default-deny everything, then whitelist web->api:80, api->cache:80, and DNS.

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: web-tier
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: web-tier
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress-to-api
  namespace: web-tier
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress-from-web
  namespace: web-tier
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress-to-cache
  namespace: web-tier
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: cache
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cache-ingress-from-api
  namespace: web-tier
spec:
  podSelector:
    matchLabels:
      app: cache
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 80
EOF
```

Verify:

```bash
kubectl -n web-tier exec deploy/web -- wget -q -T 4 -O /dev/null http://api-svc && echo allowed
kubectl -n web-tier exec deploy/web -- wget -q -T 4 -O /dev/null http://cache-svc || echo blocked
```

Why this works: `default-deny` cuts all traffic for every pod; each additional policy is additive and re-opens only the required flow. DNS egress is required or service names stop resolving.

## Question 2 - Ingress TLS for portal.ckx.local

```bash
kubectl -n tls-gateway create secret tls portal-tls \
  --cert=/tmp/exam/q2/portal.crt --key=/tmp/exam/q2/portal.key

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portal-ingress
  namespace: tls-gateway
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

Verify:

```bash
kubectl -n tls-gateway get secret portal-tls -o jsonpath='{.type}'
kubectl -n tls-gateway describe ingress portal-ingress
```

## Question 3 - RBAC least privilege for build-bot

```bash
kubectl delete clusterrolebinding build-bot-admin

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: build-bot-role
  namespace: ci-pipeline
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: build-bot-binding
  namespace: ci-pipeline
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: build-bot-role
subjects:
- kind: ServiceAccount
  name: build-bot
  namespace: ci-pipeline
EOF
```

Verify:

```bash
kubectl auth can-i get pods -n ci-pipeline --as=system:serviceaccount:ci-pipeline:build-bot        # yes
kubectl auth can-i delete pods -n ci-pipeline --as=system:serviceaccount:ci-pipeline:build-bot     # no
kubectl auth can-i get secrets -n ci-pipeline --as=system:serviceaccount:ci-pipeline:build-bot     # no
```

## Question 4 - ServiceAccount token automount hardening

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payments-runtime
  namespace: payments
automountServiceAccountToken: false
EOF

kubectl -n payments patch deployment payment-processor -p \
  '{"spec":{"template":{"spec":{"serviceAccountName":"payments-runtime","automountServiceAccountToken":false}}}}'

kubectl -n payments rollout status deployment/payment-processor
```

Why this works: disabling automount on both the SA and the pod template guarantees no API token is mounted even if one side is later edited.

## Question 5 - SIMULATED: API server manifest hardening

This task edits only the copied file `/tmp/exam/q5/kube-apiserver.yaml`. Do not touch the live cluster.

```bash
FILE=/tmp/exam/q5/kube-apiserver.yaml

yq -i '(.spec.containers[0].command[] | select(. == "--anonymous-auth=true")) = "--anonymous-auth=false"' $FILE
yq -i '(.spec.containers[0].command[] | select(. == "--authorization-mode=AlwaysAllow")) = "--authorization-mode=Node,RBAC"' $FILE
yq -i '(.spec.containers[0].command[] | select(. == "--enable-admission-plugins=NamespaceLifecycle")) = "--enable-admission-plugins=NamespaceLifecycle,NodeRestriction"' $FILE

yq '.spec.containers[0].command' $FILE   # review the result
```

(Editing the three flag lines in `vim` is equally valid.)

## Question 6 - SecurityContext hardening + kubesec

```bash
kubectl -n container-hardening apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sensor-agent
  namespace: container-hardening
  labels:
    app: sensor-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sensor-agent
  template:
    metadata:
      labels:
        app: sensor-agent
    spec:
      containers:
      - name: agent
        image: busybox:1.36
        command: ["/bin/sh","-c","sleep 86400"]
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 64Mi
        securityContext:
          runAsNonRoot: true
          runAsUser: 10001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
          seccompProfile:
            type: RuntimeDefault
EOF

kubectl -n container-hardening rollout status deployment/sensor-agent

kubectl -n container-hardening get deployment sensor-agent -o yaml > /tmp/sensor-agent.yaml
kubesec scan /tmp/sensor-agent.yaml | jq '.[0].score'    # expect >= 7 (typically 9)
```

Why this works: applying the full manifest replaces the broken spec (removes `hostPID` and `privileged` by omission) and adds every required hardening field.

## Question 7 - seccomp RuntimeDefault

```bash
kubectl -n syscall-guard patch deployment event-logger -p \
  '{"spec":{"template":{"spec":{"securityContext":{"seccompProfile":{"type":"RuntimeDefault"}}}}}}'

kubectl -n syscall-guard rollout status deployment/event-logger
kubectl -n syscall-guard get pods -l app=event-logger \
  -o jsonpath='{.items[0].spec.securityContext.seccompProfile.type}'   # RuntimeDefault
```

The patch overwrites the previous `Unconfined` value at the same path, so no stale profile remains.

## Question 8 - Restricted Pod Security Standard

```bash
kubectl label namespace restricted-apps \
  pod-security.kubernetes.io/enforce=restricted --overwrite

kubectl -n restricted-apps apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-api
  namespace: restricted-apps
  labels:
    app: legacy-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy-api
  template:
    metadata:
      labels:
        app: legacy-api
    spec:
      containers:
      - name: api
        image: busybox:1.36
        command: ["/bin/sh","-c","sleep 86400"]
        securityContext:
          runAsNonRoot: true
          runAsUser: 10001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
          seccompProfile:
            type: RuntimeDefault
EOF

kubectl -n restricted-apps rollout status deployment/legacy-api

# Capture the admission rejection (the apply MUST fail):
kubectl apply -f /tmp/exam/q8/bad-pod.yaml > /tmp/exam/q8/rejection.txt 2>&1
cat /tmp/exam/q8/rejection.txt   # contains "violates PodSecurity"
```

Note the redirection pattern: `> file 2>&1` captures the error; do not use `| tee` with a heredoc.

## Question 9 - ValidatingAdmissionPolicy against latest tags

```bash
kubectl apply -f - <<EOF
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: deny-latest-tag
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: ["apps"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["deployments"]
  validations:
  - expression: "object.spec.template.spec.containers.all(c, c.image.contains(':') && !c.image.endsWith(':latest'))"
    message: "Container images must use an explicit, non-latest tag."
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: deny-latest-tag-binding
spec:
  policyName: deny-latest-tag
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        env: prod
EOF
```

Verify:

```bash
kubectl -n admission-control create deployment t1 --image=nginx:latest --replicas=0       # rejected
kubectl -n admission-control create deployment t2 --image=nginx:1.27-alpine --replicas=0  # accepted
kubectl -n admission-control delete deployment t2
```

## Question 10 - Credential found in a ConfigMap

```bash
kubectl -n credential-hygiene get configmap app-config -o yaml   # reveals db_password

printf 'S3cr3t-Hunter2-9000' > /tmp/exam/q10/found.txt

kubectl -n credential-hygiene create secret generic db-creds \
  --from-literal=password='S3cr3t-Hunter2-9000'

kubectl -n credential-hygiene patch deployment billing --type=json -p '[
  {"op":"replace","path":"/spec/template/spec/containers/0/env/0","value":
    {"name":"DB_PASSWORD","valueFrom":{"secretKeyRef":{"name":"db-creds","key":"password"}}}}
]'

kubectl -n credential-hygiene patch configmap app-config --type=json \
  -p '[{"op":"remove","path":"/data/db_password"}]'

kubectl -n credential-hygiene rollout status deployment/billing
```

## Question 11 - trivy image triage

```bash
cd /tmp/exam/q11

trivy image -f json -o nginx.json  nginx:1.14.2
trivy image -f json -o python.json python:3.4-alpine
trivy image -f json -o alpine.json alpine:3.20

for f in nginx python alpine; do
  echo "$f: $(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' $f.json)"
done
# alpine:3.20 has the fewest CRITICAL findings

printf 'alpine:3.20' > /tmp/exam/q11/safe-image.txt

kubectl -n image-audit set image deployment/release-app app=alpine:3.20
kubectl -n image-audit rollout status deployment/release-app
```

Why this works: the deployment's command is `sleep`, so any of the three images can run it; the safest by CRITICAL count is the slim, current alpine base.

## Question 12 - cosign artifact verification

```bash
cd /tmp/exam/q12

cosign verify-blob --key signer.pub --signature release-a.sig --insecure-ignore-tlog release-a.yaml
# -> Verified OK
cosign verify-blob --key signer.pub --signature release-b.sig --insecure-ignore-tlog release-b.yaml
# -> error (manifest was modified after signing)

cat > /tmp/exam/q12/verify-result.txt <<EOF
release-a.yaml: VERIFIED
release-b.yaml: FAILED
EOF

kubectl apply -f /tmp/exam/q12/release-a.yaml
kubectl -n artifact-trust rollout status deployment/trusted-api
# Do NOT apply release-b.yaml
```

## Question 13 - syft SBOM + Dockerfile hardening

```bash
syft alpine:3.20 -o spdx-json=/tmp/exam/q13/sbom.json

jq -r '.packages[].name' /tmp/exam/q13/sbom.json | grep -x busybox   # present
jq -r '.packages[].name' /tmp/exam/q13/sbom.json | grep -x bash      # no output -> absent

cat > /tmp/exam/q13/pkg-report.txt <<EOF
busybox=present
bash=absent
EOF
```

Fixed Dockerfile (`/tmp/exam/q13/Dockerfile`):

```dockerfile
FROM node:20-alpine

WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
COPY agent.sh /usr/local/bin/agent.sh
RUN chmod +x /usr/local/bin/agent.sh

USER node

EXPOSE 3000
CMD ["node","server.js"]
```

Key fixes: pinned base tag, non-root `USER`, local `COPY` instead of remote `ADD`/`curl | sh`, no secret in `ENV` (inject at runtime via a Secret instead).

## Question 14 - Audit log investigation

```bash
LOG=/tmp/exam/q14/audit.log

# 1. who read the payroll-db secret
jq -r 'select(.objectRef.resource=="secrets" and .objectRef.name=="payroll-db"
       and .objectRef.namespace=="finance" and .verb=="get")
       | .user.username' $LOG | sort -u
printf 'mallory@ckx.local' > /tmp/exam/q14/secret-reader.txt

# 2. which SA deleted deployment legacy-web
jq -r 'select(.verb=="delete" and .objectRef.resource=="deployments"
       and .objectRef.name=="legacy-web") | .user.username' $LOG
printf 'system:serviceaccount:ci:deploy-bot' > /tmp/exam/q14/deleter.txt

# 3. denied anonymous requests
jq -r 'select(.user.username=="system:anonymous" and .responseStatus.code==403)' $LOG | jq -s 'length'
printf '4' > /tmp/exam/q14/anonymous-denied.txt
```

## Question 15 - Incident response: quarantine kernel-helper

```bash
# Identify: privileged + hostPath / + nc beacon to 203.0.113.66
kubectl -n incident-response get deployments -o yaml | grep -B5 -A5 -E 'privileged|hostPath|nc '

printf 'deployment=kernel-helper' > /tmp/exam/q15/incident.txt

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine
  namespace: incident-response
spec:
  podSelector:
    matchLabels:
      app: kernel-helper
  policyTypes:
  - Ingress
  - Egress
EOF

kubectl -n incident-response scale deployment kernel-helper --replicas=0
```

Why this works: a policy with both policyTypes and no allow rules denies everything for the selected pods. Scaling to 0 stops execution while the Deployment object (and its spec, images, history) remains as evidence.

## Question 16 - Immutable container

```bash
kubectl -n immutable-infra patch deployment report-writer --type=json -p '[
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext",
   "value":{"readOnlyRootFilesystem":true}},
  {"op":"add","path":"/spec/template/spec/volumes",
   "value":[{"name":"data","emptyDir":{}}]},
  {"op":"add","path":"/spec/template/spec/containers/0/volumeMounts",
   "value":[{"name":"data","mountPath":"/data"}]}
]'

kubectl -n immutable-infra rollout status deployment/report-writer
```

Verify:

```bash
POD=$(kubectl -n immutable-infra get pods -l app=report-writer -o jsonpath='{.items[0].metadata.name}')
kubectl -n immutable-infra exec $POD -- touch /probe          # fails: read-only
kubectl -n immutable-infra exec $POD -- ls -la /data/report.log   # still growing
```
