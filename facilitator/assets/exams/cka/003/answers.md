# CKA RBAC and Security Troubleshooting Lab 003 - Revalidated Answers

All validations require a positive, task-specific change before marks can be awarded.


## Question 1

Estimated time: `4` minutes.

ServiceAccount `report-reader` exists in namespace `rbac-sec-q1`, but it cannot read Pods.

Fix RBAC so `report-reader` can `get` and `list` Pods only in namespace `rbac-sec-q1`.

Use Role `q1-pod-reader` and RoleBinding `q1-read-pods`.

### Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q1-pod-reader
  namespace: rbac-sec-q1
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q1-read-pods
  namespace: rbac-sec-q1
subjects:
- kind: ServiceAccount
  name: report-reader
  namespace: rbac-sec-q1
roleRef:
  kind: Role
  name: q1-pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```


## Question 2

Estimated time: `4` minutes.

ServiceAccount `log-reader` can read Pod objects but cannot read Pod logs.

Fix RBAC so it can `get` Pods and `get` the `pods/log` subresource in namespace `rbac-sec-q2`.

Use Role `q2-log-reader` and RoleBinding `q2-read-logs`.

### Solution

```bash
kubectl -n rbac-sec-q2 patch role q2-log-reader --type='json'   -p='[{"op":"add","path":"/rules/0/resources/-","value":"pods/log"}]'
```


## Question 3

Estimated time: `4` minutes.

ServiceAccount `deploy-reader` cannot read Deployments because the Role uses the wrong API group.

Fix Role `q3-deployment-reader` so `deploy-reader` can `get`, `list`, and `watch` Deployments in namespace `rbac-sec-q3`.

Keep RoleBinding `q3-read-deployments`.

### Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q3-deployment-reader
  namespace: rbac-sec-q3
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
EOF
```


## Question 4

Estimated time: `5` minutes.

ServiceAccount `auditor` has excessive cluster-admin access through ClusterRoleBinding `q4-accidental-admin`.

Remove the broad binding.

Create namespace-only read access so `auditor` can `get` and `list` Pods and ConfigMaps in namespace `rbac-sec-q4`, but cannot read Secrets or delete Pods.

Use Role `q4-audit-reader` and RoleBinding `q4-audit-read`.

### Solution

```bash
kubectl delete clusterrolebinding q4-accidental-admin

kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q4-audit-reader
  namespace: rbac-sec-q4
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q4-audit-read
  namespace: rbac-sec-q4
subjects:
- kind: ServiceAccount
  name: auditor
  namespace: rbac-sec-q4
roleRef:
  kind: Role
  name: q4-audit-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```


## Question 5

Estimated time: `4` minutes.

User `dev-operator` cannot read Pods because RoleBinding `q5-dev-read-pods` uses the wrong subject kind.

Fix the RoleBinding so user `dev-operator` can `get` and `list` Pods only in namespace `rbac-sec-q5`.

Use Role `q5-pod-reader` and RoleBinding `q5-dev-read-pods`.

### Solution

```bash
kubectl -n rbac-sec-q5 delete rolebinding q5-dev-read-pods
kubectl -n rbac-sec-q5 create rolebinding q5-dev-read-pods   --role=q5-pod-reader   --user=dev-operator
```


## Question 6

Estimated time: `4` minutes.

ServiceAccount `node-inspector` needs read-only node access.

The current namespace Role cannot grant access to cluster-scoped Node resources.

Create ClusterRole `q6-node-reader` and ClusterRoleBinding `q6-node-reader-binding` so `node-inspector` can `get` and `list` Nodes.

### Solution

```bash
kubectl create clusterrole q6-node-reader --verb=get,list --resource=nodes
kubectl create clusterrolebinding q6-node-reader-binding   --clusterrole=q6-node-reader   --serviceaccount=rbac-sec-q6:node-inspector
```


## Question 7

Estimated time: `5` minutes.

Deployment `q7-api` uses the default ServiceAccount and still mounts an API token.

Create ServiceAccount `app-runner` with `automountServiceAccountToken: false`.

Update Deployment `q7-api` to use `app-runner` and disable token automounting in the Pod template.

### Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-runner
  namespace: rbac-sec-q7
automountServiceAccountToken: false
EOF

kubectl -n rbac-sec-q7 patch deployment q7-api --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/serviceAccountName","value":"app-runner"},
  {"op":"replace","path":"/spec/template/spec/automountServiceAccountToken","value":false}
]'
```


## Question 8

Estimated time: `6` minutes.

The kubeconfig file `/tmp/exam/q8/kubeconfig` is broken.

Fix it so it has:
- current context `q8-context`
- context namespace `rbac-sec-q8`
- user `q8-user`
- cluster `q8-cluster`
- the same API server URL as the current cluster

Use the current cluster CA data or configure `insecure-skip-tls-verify: true`.

### Solution

```bash
mkdir -p /tmp/exam/q8
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

kubectl config --kubeconfig=/tmp/exam/q8/kubeconfig set-cluster q8-cluster   --server="$SERVER"   --insecure-skip-tls-verify=true

kubectl config --kubeconfig=/tmp/exam/q8/kubeconfig set-credentials q8-user --token=dummy-token
kubectl config --kubeconfig=/tmp/exam/q8/kubeconfig set-context q8-context   --cluster=q8-cluster   --user=q8-user   --namespace=rbac-sec-q8

kubectl config --kubeconfig=/tmp/exam/q8/kubeconfig use-context q8-context
```


## Question 9

Estimated time: `7` minutes.

Create and approve a Kubernetes client certificate request for user `q9-user`.

Requirements:
- generate private key `/tmp/exam/q9/q9-user.key`
- generate CSR `/tmp/exam/q9/q9-user.csr` with subject `CN=q9-user`
- create Kubernetes CSR object `q9-user`
- signerName `kubernetes.io/kube-apiserver-client`
- usage `client auth`
- approve the CSR

### Solution

```bash
mkdir -p /tmp/exam/q9
openssl genrsa -out /tmp/exam/q9/q9-user.key 2048
openssl req -new -key /tmp/exam/q9/q9-user.key -out /tmp/exam/q9/q9-user.csr -subj "/CN=q9-user"

CSR_B64=$(base64 -w0 /tmp/exam/q9/q9-user.csr)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: q9-user
spec:
  request: ${CSR_B64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

kubectl certificate approve q9-user
```


## Question 10

Estimated time: `4` minutes.

Create certificate expiration report `/tmp/exam/q10/cert-expiration.txt`.

The report must be generated using `kubeadm certs check-expiration`.

It must include the Kubernetes API server certificate information.

### Solution

```bash
mkdir -p /tmp/exam/q10
sudo kubeadm certs check-expiration > /tmp/exam/q10/cert-expiration.txt
cat /tmp/exam/q10/cert-expiration.txt
```


## Question 11

Estimated time: `4` minutes.

RoleBinding `q11-read-pods` points to a non-existing Role.

Fix it so ServiceAccount `reader` can `get` and `list` Pods in namespace `rbac-sec-q11`.

Because RoleBinding `roleRef` is immutable, recreate the RoleBinding if needed.

### Solution

```bash
kubectl -n rbac-sec-q11 delete rolebinding q11-read-pods
kubectl -n rbac-sec-q11 create rolebinding q11-read-pods   --role=q11-pod-reader   --serviceaccount=rbac-sec-q11:reader
```


## Question 12

Estimated time: `5` minutes.

ServiceAccount `impersonator` must be allowed to impersonate Kubernetes user `limited-user`.

Create ClusterRole `q12-impersonate-limited-user` and ClusterRoleBinding `q12-impersonate-limited-user`.

Grant only `impersonate` on resource `users` with resourceName `limited-user`.

### Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: q12-impersonate-limited-user
rules:
- apiGroups: [""]
  resources: ["users"]
  resourceNames: ["limited-user"]
  verbs: ["impersonate"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: q12-impersonate-limited-user
subjects:
- kind: ServiceAccount
  name: impersonator
  namespace: rbac-sec-q12
roleRef:
  kind: ClusterRole
  name: q12-impersonate-limited-user
  apiGroup: rbac.authorization.k8s.io
EOF
```


## Question 13

Estimated time: `4` minutes.

Role `q13-app-reader` is too broad and allows Secret access.

Fix it so ServiceAccount `app-reader` can only `get` and `list` ConfigMaps in namespace `rbac-sec-q13`.

It must not read Secrets.

### Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q13-app-reader
  namespace: rbac-sec-q13
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
EOF
```


## Question 14

Estimated time: `6` minutes.

Pod `q14-insecure-pod` is insecure.

Recreate it as `q14-secure-pod` using image `nginx:1.25`.

Security requirements:
- `runAsNonRoot: true`
- `runAsUser: 101`
- `allowPrivilegeEscalation: false`
- drop capability `ALL`
- `seccompProfile.type: RuntimeDefault`
- `readOnlyRootFilesystem: true`

### Solution

```bash
kubectl -n rbac-sec-q14 delete pod q14-insecure-pod

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q14-secure-pod
  namespace: rbac-sec-q14
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: nginx
    image: nginx:1.25
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
EOF
```


## Question 15

Estimated time: `3` minutes.

Namespace `rbac-sec-q15` must enforce Pod Security Admission.

Label the namespace with:
- `pod-security.kubernetes.io/enforce=restricted`
- `pod-security.kubernetes.io/audit=restricted`
- `pod-security.kubernetes.io/warn=restricted`

### Solution

```bash
kubectl label namespace rbac-sec-q15   pod-security.kubernetes.io/enforce=restricted   pod-security.kubernetes.io/audit=restricted   pod-security.kubernetes.io/warn=restricted   --overwrite
```


## Question 16

Estimated time: `5` minutes.

Create NetworkPolicy `q16-db-ingress` in namespace `rbac-sec-q16`.

It must select Pods with label `role=db`.

Allow ingress only from Pods with label `role=frontend` on TCP port `5432`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: q16-db-ingress
  namespace: rbac-sec-q16
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 5432
EOF
```


## Question 17

Estimated time: `4` minutes.

Secret `q17-regcred` exists in namespace `rbac-sec-q17`.

Create ServiceAccount `image-puller` configured with imagePullSecret `q17-regcred`.

Update Deployment `q17-private-app` so its Pods use ServiceAccount `image-puller`.

### Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: image-puller
  namespace: rbac-sec-q17
imagePullSecrets:
- name: q17-regcred
EOF

kubectl -n rbac-sec-q17 patch deployment q17-private-app   -p '{"spec":{"template":{"spec":{"serviceAccountName":"image-puller"}}}}'
```


## Question 18

Estimated time: `4` minutes.

Pod `q18-token-pod` currently mounts a ServiceAccount token.

Recreate it using image `nginx:1.25` with `automountServiceAccountToken: false`.

### Solution

```bash
kubectl -n rbac-sec-q18 delete pod q18-token-pod

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q18-token-pod
  namespace: rbac-sec-q18
spec:
  automountServiceAccountToken: false
  containers:
  - name: nginx
    image: nginx:1.25
EOF
```


## Question 19

Estimated time: `5` minutes.

Create kubeconfig `/tmp/exam/q19/dev.kubeconfig` for namespace `rbac-sec-q19`.

Requirements:
- cluster name `dev-cluster`
- user name `dev-token-user`
- context name `dev-context`
- current context `dev-context`
- context namespace `rbac-sec-q19`
- user token value exactly `dev-token-123`
- API server URL must match the current cluster

### Solution

```bash
mkdir -p /tmp/exam/q19
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

kubectl config --kubeconfig=/tmp/exam/q19/dev.kubeconfig set-cluster dev-cluster   --server="$SERVER"   --insecure-skip-tls-verify=true

kubectl config --kubeconfig=/tmp/exam/q19/dev.kubeconfig set-credentials dev-token-user   --token=dev-token-123

kubectl config --kubeconfig=/tmp/exam/q19/dev.kubeconfig set-context dev-context   --cluster=dev-cluster   --user=dev-token-user   --namespace=rbac-sec-q19

kubectl config --kubeconfig=/tmp/exam/q19/dev.kubeconfig use-context dev-context
```


## Question 20

Estimated time: `4` minutes.

Create executable script `/tmp/exam/q20/inspect_rbac.sh`.

The script must list effective permissions for ServiceAccount `troubleshoot-sa` in namespace `rbac-sec-q20` using:

`kubectl auth can-i --list --as=system:serviceaccount:rbac-sec-q20:troubleshoot-sa -n rbac-sec-q20`

### Solution

```bash
mkdir -p /tmp/exam/q20
cat > /tmp/exam/q20/inspect_rbac.sh <<'EOF'
#!/bin/bash
kubectl auth can-i --list --as=system:serviceaccount:rbac-sec-q20:troubleshoot-sa -n rbac-sec-q20
EOF
chmod +x /tmp/exam/q20/inspect_rbac.sh
```


## Question 21

Estimated time: `7` minutes.

Create and approve a kubelet serving CertificateSigningRequest named `q21-kubelet-serving`.

Requirements:
- private key `/tmp/exam/q21/q21-kubelet-serving.key`
- CSR file `/tmp/exam/q21/q21-kubelet-serving.csr`
- Kubernetes CSR object `q21-kubelet-serving`
- signerName `kubernetes.io/kubelet-serving`
- usages `digital signature`, `key encipherment`, and `server auth`
- approved CSR

### Solution

```bash
mkdir -p /tmp/exam/q21
openssl genrsa -out /tmp/exam/q21/q21-kubelet-serving.key 2048
openssl req -new   -key /tmp/exam/q21/q21-kubelet-serving.key   -out /tmp/exam/q21/q21-kubelet-serving.csr   -subj "/CN=system:node:q21-node/O=system:nodes"

CSR_B64=$(base64 -w0 /tmp/exam/q21/q21-kubelet-serving.csr)

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: q21-kubelet-serving
spec:
  request: ${CSR_B64}
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kubectl certificate approve q21-kubelet-serving
```


## Question 22

Estimated time: `6` minutes.

Namespace `rbac-sec-q22` enforces the restricted Pod Security standard.

Create Deployment `q22-restricted-nginx` with one replica using image `nginx:1.25`.

The Pod template must comply with restricted settings:
- `runAsNonRoot: true`
- `runAsUser: 101`
- `seccompProfile.type: RuntimeDefault`
- `allowPrivilegeEscalation: false`
- drop capability `ALL`

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q22-restricted-nginx
  namespace: rbac-sec-q22
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q22-restricted-nginx
  template:
    metadata:
      labels:
        app: q22-restricted-nginx
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: nginx
        image: nginx:1.25
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
EOF
```


## Question 23

Estimated time: `5` minutes.

Create Secret `q23-db-secret` with literals `username=admin` and `password=s3cr3t`.

Create Pod `q23-db-client` using image `busybox:1.36` and command `sleep 3600`.

Expose `username` as environment variable `DB_USER`.

Mount the Secret read-only at `/etc/db-secret`.

### Solution

```bash
kubectl -n rbac-sec-q23 create secret generic q23-db-secret   --from-literal=username=admin   --from-literal=password=s3cr3t

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q23-db-client
  namespace: rbac-sec-q23
spec:
  containers:
  - name: client
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: q23-db-secret
          key: username
    volumeMounts:
    - name: db-secret
      mountPath: /etc/db-secret
      readOnly: true
  volumes:
  - name: db-secret
    secret:
      secretName: q23-db-secret
EOF
```


## Question 24

Estimated time: `5` minutes.

ServiceAccount `token-rotator` must update only Secret `app-token` in namespace `rbac-sec-q24`.

Create Role `q24-token-rotator` with verbs `get`, `update`, and `patch` on resource `secrets`, restricted with `resourceNames: ["app-token"]`.

Create RoleBinding `q24-token-rotator` binding it to ServiceAccount `token-rotator`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q24-token-rotator
  namespace: rbac-sec-q24
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-token"]
  verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q24-token-rotator
  namespace: rbac-sec-q24
subjects:
- kind: ServiceAccount
  name: token-rotator
  namespace: rbac-sec-q24
roleRef:
  kind: Role
  name: q24-token-rotator
  apiGroup: rbac.authorization.k8s.io
EOF
```


## Question 25

Estimated time: `5` minutes.

Create a TLS certificate and Secret for `secure.example.local`.

Requirements:
- certificate file `/tmp/exam/q25/tls.crt`
- key file `/tmp/exam/q25/tls.key`
- Secret `q25-tls` in namespace `rbac-sec-q25`
- Secret type `kubernetes.io/tls`
- Secret must contain `tls.crt` and `tls.key`

### Solution

```bash
mkdir -p /tmp/exam/q25
openssl req -x509 -nodes -newkey rsa:2048   -keyout /tmp/exam/q25/tls.key   -out /tmp/exam/q25/tls.crt   -days 365   -subj "/CN=secure.example.local"

kubectl -n rbac-sec-q25 create secret tls q25-tls   --cert=/tmp/exam/q25/tls.crt   --key=/tmp/exam/q25/tls.key
```
