# CKA Mock Exam 004 - Kubernetes Administration Troubleshooting

This mock exam contains 25 independent CKA-style troubleshooting and administration tasks.


## Question 1

Write all available kubectl context names to `/tmp/exam/q1/contexts`.

Create `/tmp/exam/q1/context_default_kubectl.sh` containing a command that prints the current context using `kubectl`.

Create `/tmp/exam/q1/context_default_no_kubectl.sh` containing a command that prints the current context without using `kubectl`.

### Solution

```bash
mkdir -p /tmp/exam/q1
kubectl config get-contexts -o name > /tmp/exam/q1/contexts

cat > /tmp/exam/q1/context_default_kubectl.sh <<'EOF'
kubectl config current-context
EOF
chmod +x /tmp/exam/q1/context_default_kubectl.sh

cat > /tmp/exam/q1/context_default_no_kubectl.sh <<'EOF'
grep '^current-context:' "${KUBECONFIG:-$HOME/.kube/config}" | awk '{print $2}'
EOF
chmod +x /tmp/exam/q1/context_default_no_kubectl.sh
```


## Question 2

Create a Pod named `q2-control-plane-pod` in the `default` namespace using image `httpd:2.4-alpine`.

The container name must be `web`.

Schedule it only on a control-plane node using existing node labels and the required control-plane toleration. Do not add new labels to nodes.

### Solution

```bash
CONTROL_KEY=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.labels.node-role\.kubernetes\.io/control-plane}{" "}{.metadata.labels.node-role\.kubernetes\.io/master}{"
"}{end}' | awk '$2!=""{print "node-role.kubernetes.io/control-plane"; exit} $3!=""{print "node-role.kubernetes.io/master"; exit}')

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q2-control-plane-pod
  namespace: default
spec:
  nodeSelector:
    ${CONTROL_KEY}: ""
  tolerations:
  - key: ${CONTROL_KEY}
    operator: Exists
    effect: NoSchedule
  containers:
  - name: web
    image: httpd:2.4-alpine
EOF
```


## Question 3

In namespace `cka-q03`, the StatefulSet `q3-data-store` is running too many replicas.

Scale it down to exactly `1` replica and ensure only one managed Pod remains active.

### Solution

```bash
kubectl -n cka-q03 scale statefulset q3-data-store --replicas=1
kubectl -n cka-q03 get statefulset q3-data-store
kubectl -n cka-q03 get pods -l app=q3-data-store
```


## Question 4

In namespace `cka-q04`, create a Pod named `waiting-client` using image `nginx:1.16.1-alpine`.

Configure a liveness probe that executes `true`.

Configure a readiness probe that executes `wget -T2 -O- http://service-check:80`.

Then create a second Pod named `dependency-server` using image `nginx:1.16.1-alpine` with label `app=dependency` so the existing Service `service-check` receives an endpoint.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: waiting-client
  namespace: cka-q04
spec:
  containers:
  - name: waiting-client
    image: nginx:1.16.1-alpine
    livenessProbe:
      exec:
        command: ["true"]
    readinessProbe:
      exec:
        command: ["sh", "-c", "wget -T2 -O- http://service-check:80"]
---
apiVersion: v1
kind: Pod
metadata:
  name: dependency-server
  namespace: cka-q04
  labels:
    app: dependency
spec:
  containers:
  - name: nginx
    image: nginx:1.16.1-alpine
EOF
```


## Question 5

Write a command to `/tmp/exam/q5/sort_by_age.sh` that lists all Pods in all namespaces sorted by `.metadata.creationTimestamp`.

Write a second command to `/tmp/exam/q5/sort_by_uid.sh` that lists all Pods in all namespaces sorted by `.metadata.uid`.

Both scripts must use `kubectl --sort-by` and be executable.

### Solution

```bash
mkdir -p /tmp/exam/q5
cat > /tmp/exam/q5/sort_by_age.sh <<'EOF'
kubectl get pods -A --sort-by=.metadata.creationTimestamp
EOF
chmod +x /tmp/exam/q5/sort_by_age.sh

cat > /tmp/exam/q5/sort_by_uid.sh <<'EOF'
kubectl get pods -A --sort-by=.metadata.uid
EOF
chmod +x /tmp/exam/q5/sort_by_uid.sh
```


## Question 6

Create PersistentVolume `q6-safari-pv` with capacity `2Gi`, access mode `ReadWriteOnce`, hostPath `/tmp/exam/q6-data`, and no dynamic storage class.

Create PersistentVolumeClaim `q6-safari-pvc` in namespace `cka-q06` requesting `2Gi` with access mode `ReadWriteOnce`, bound to that PV.

Create Deployment `q6-safari` in namespace `cka-q06` using image `httpd:2.4-alpine` and mount the claim at `/tmp/safari-data`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: q6-safari-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
  hostPath:
    path: /tmp/exam/q6-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: q6-safari-pvc
  namespace: cka-q06
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
  volumeName: q6-safari-pv
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q6-safari
  namespace: cka-q06
spec:
  replicas: 1
  selector:
    matchLabels:
      app: q6-safari
  template:
    metadata:
      labels:
        app: q6-safari
    spec:
      containers:
      - name: httpd
        image: httpd:2.4-alpine
        volumeMounts:
        - name: safari-data
          mountPath: /tmp/safari-data
      volumes:
      - name: safari-data
        persistentVolumeClaim:
          claimName: q6-safari-pvc
EOF
```


## Question 7

In namespace `cka-q07`, Deployment `q7-broken-web` was updated to a bad image and its rollout is failing.

Restore the Deployment so it runs exactly `2` replicas using image `nginx:1.25`.

### Solution

```bash
kubectl -n cka-q07 rollout history deployment/q7-broken-web
kubectl -n cka-q07 rollout undo deployment/q7-broken-web
# or directly:
kubectl -n cka-q07 set image deployment/q7-broken-web nginx=nginx:1.25
kubectl -n cka-q07 scale deployment q7-broken-web --replicas=2
kubectl -n cka-q07 rollout status deployment/q7-broken-web
```


## Question 8

In namespace `cka-q08`, Service `q8-web-svc` has no endpoints because its selector is wrong.

Fix the Service so it selects the existing Deployment Pods with label `app=q8-web`.

Keep the Service port as `80` and target port as `80`.

### Solution

```bash
kubectl -n cka-q08 patch service q8-web-svc -p '{"spec":{"selector":{"app":"q8-web"}}}'
kubectl -n cka-q08 get endpoints q8-web-svc
```


## Question 9

In namespace `cka-q09`, create a NetworkPolicy named `q9-egress-lockdown`.

It must select Pods with label `app=backend`.

It must allow egress only to Pods with label `app=db` on TCP port `5432`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: q9-egress-lockdown
  namespace: cka-q09
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: db
    ports:
    - protocol: TCP
      port: 5432
EOF
```


## Question 10

In namespace `cka-q10`, create ServiceAccount `processor`.

Create Role `processor` allowing only `create` on `secrets` and `configmaps`.

Create RoleBinding `processor` binding that Role to the ServiceAccount.

### Solution

```bash
kubectl -n cka-q10 create serviceaccount processor
kubectl -n cka-q10 create role processor --verb=create --resource=secrets,configmaps
kubectl -n cka-q10 create rolebinding processor --role=processor --serviceaccount=cka-q10:processor
kubectl -n cka-q10 auth can-i create secrets --as system:serviceaccount:cka-q10:processor
```


## Question 11

In namespace `cka-q11`, ServiceAccount `node-reader` already exists.

Create ClusterRole `q11-node-reader` that allows `get`, `list`, and `watch` on `nodes`.

Create ClusterRoleBinding `q11-node-reader` binding the ClusterRole to ServiceAccount `cka-q11:node-reader`.

### Solution

```bash
kubectl create clusterrole q11-node-reader --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding q11-node-reader --clusterrole=q11-node-reader --serviceaccount=cka-q11:node-reader
kubectl auth can-i list nodes --as system:serviceaccount:cka-q11:node-reader
```


## Question 12

Create Pod `q12-tolerant` in namespace `cka-q12` using image `nginx:1.25`.

The Pod must have nodeSelector `kubernetes.io/os=linux`.

Add a toleration for key `workload`, operator `Equal`, value `reserved`, effect `NoSchedule`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q12-tolerant
  namespace: cka-q12
spec:
  nodeSelector:
    kubernetes.io/os: linux
  tolerations:
  - key: workload
    operator: Equal
    value: reserved
    effect: NoSchedule
  containers:
  - name: nginx
    image: nginx:1.25
EOF
```


## Question 13

In namespace `cka-q13`, Job `q13-pi` is failed because its command exits with an error.

Replace or recreate it so Job `q13-pi` completes successfully using image `busybox:1.36` and command `sh -c 'echo cka-q13-complete'`.

### Solution

```bash
kubectl -n cka-q13 delete job q13-pi
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: q13-pi
  namespace: cka-q13
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pi
        image: busybox:1.36
        command: ["sh", "-c", "echo cka-q13-complete"]
EOF
kubectl -n cka-q13 wait --for=condition=complete job/q13-pi --timeout=90s
```


## Question 14

Create CronJob `q14-cleanup` in namespace `cka-q14`.

It must run every 5 minutes using schedule `*/5 * * * *`.

Use image `busybox:1.36` with command `sh -c 'date; echo cleanup'`.

Set `successfulJobsHistoryLimit` to `2` and `failedJobsHistoryLimit` to `1`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: q14-cleanup
  namespace: cka-q14
spec:
  schedule: "*/5 * * * *"
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: cleanup
            image: busybox:1.36
            command: ["sh", "-c", "date; echo cleanup"]
EOF
```


## Question 15

In namespace `cka-q15`, ConfigMap `app-settings` already exists with required keys.

Create Pod `q15-configured` using image `nginx:1.25`.

Expose ConfigMap key `APP_MODE` as environment variable `APP_MODE`.

Mount the full ConfigMap as volume `settings` at `/etc/app-settings`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q15-configured
  namespace: cka-q15
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    env:
    - name: APP_MODE
      valueFrom:
        configMapKeyRef:
          name: app-settings
          key: APP_MODE
    volumeMounts:
    - name: settings
      mountPath: /etc/app-settings
  volumes:
  - name: settings
    configMap:
      name: app-settings
EOF
```


## Question 16

Create Secret `q16-db-secret` in namespace `cka-q16` with literal keys `username=admin` and `password=s3cr3t`.

Create Pod `q16-db-client` using image `busybox:1.36` running `sleep 3600`.

Expose `username` as env var `DB_USER`.

Mount the Secret read-only at `/etc/db-secret`.

### Solution

```bash
kubectl -n cka-q16 create secret generic q16-db-secret --from-literal=username=admin --from-literal=password=s3cr3t
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q16-db-client
  namespace: cka-q16
spec:
  containers:
  - name: client
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: q16-db-secret
          key: username
    volumeMounts:
    - name: db-secret
      mountPath: /etc/db-secret
      readOnly: true
  volumes:
  - name: db-secret
    secret:
      secretName: q16-db-secret
EOF
```


## Question 17

Create Pod `q17-resource-check` in namespace `cka-q17` using image `nginx:1.25`.

Set CPU request `100m`, memory request `128Mi`, CPU limit `250m`, and memory limit `256Mi`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q17-resource-check
  namespace: cka-q17
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 256Mi
EOF
```


## Question 18

Create Deployment `q18-web` in namespace `cka-q18` with `3` replicas using image `nginx:1.25`.

Use label `app=q18-web`.

Configure preferred pod anti-affinity so replicas prefer different nodes using topology key `kubernetes.io/hostname`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: q18-web
  namespace: cka-q18
spec:
  replicas: 3
  selector:
    matchLabels:
      app: q18-web
  template:
    metadata:
      labels:
        app: q18-web
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - q18-web
              topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx:1.25
EOF
```


## Question 19

In namespace `cka-q19`, Pod `q19-broken` is failing with an invalid image.

Fix it so Pod `q19-broken` uses image `nginx:1.25` and reaches Ready state.

### Solution

```bash
kubectl -n cka-q19 delete pod q19-broken
kubectl -n cka-q19 run q19-broken --image=nginx:1.25
kubectl -n cka-q19 wait --for=condition=Ready pod/q19-broken --timeout=90s
```


## Question 20

In namespace `cka-q20`, expose Deployment `q20-api`.

Create Service `q20-api-svc` of type `NodePort`.

The Service must select `app=q20-api`, expose port `8080`, and forward to target port `80`.

### Solution

```bash
kubectl -n cka-q20 expose deployment q20-api   --name=q20-api-svc   --type=NodePort   --port=8080   --target-port=80
```


## Question 21

Create `/tmp/exam/q21/node_report.txt` containing a node capacity report.

The report must be generated with `kubectl get nodes` and custom columns for node name, CPU capacity, and memory capacity.

Use headers `NODE`, `CPU`, and `MEMORY`.

### Solution

```bash
mkdir -p /tmp/exam/q21
kubectl get nodes   -o custom-columns=NODE:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory   > /tmp/exam/q21/node_report.txt
cat /tmp/exam/q21/node_report.txt
```


## Question 22

Create a static Pod manifest at `/etc/kubernetes/manifests/q22-static-web.yaml`.

The static Pod must be named `q22-static-web`, use image `nginx:1.25`, and expose container port `80`.

### Solution

```bash
sudo tee /etc/kubernetes/manifests/q22-static-web.yaml >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: q22-static-web
  labels:
    static-pod: q22-static-web
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
EOF
```


## Question 23

Create Pod `q23-logger` in namespace `cka-q23` with two containers.

Container `writer` must use image `busybox:1.36` and continuously append timestamps to `/var/log/app.log`.

Container `reader` must use image `busybox:1.36` and continuously read `/var/log/app.log`.

Use one shared `emptyDir` volume named `log-volume`, mounted at `/var/log` in both containers.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: q23-logger
  namespace: cka-q23
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /var/log/app.log; sleep 5; done"]
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "touch /var/log/app.log; tail -F /var/log/app.log"]
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  volumes:
  - name: log-volume
    emptyDir: {}
EOF
```


## Question 24

Create PriorityClass `q24-high-priority` with value `100000` and `globalDefault: false`.

Create Pod `q24-important` in namespace `cka-q24` using image `nginx:1.25` and assign it to PriorityClass `q24-high-priority`.

### Solution

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: q24-high-priority
value: 100000
globalDefault: false
description: High priority class for q24
---
apiVersion: v1
kind: Pod
metadata:
  name: q24-important
  namespace: cka-q24
spec:
  priorityClassName: q24-high-priority
  containers:
  - name: nginx
    image: nginx:1.25
EOF
```


## Question 25

Create executable script `/tmp/exam/q25/backup-etcd.sh` that performs an etcd snapshot backup to `/tmp/exam/q25/etcd-backup.db`.

The script must set `ETCDCTL_API=3` and run `etcdctl snapshot save`.

It must use endpoint `https://127.0.0.1:2379` and include `--cacert`, `--cert`, and `--key` arguments pointing to the standard Kubernetes etcd PKI files under `/etc/kubernetes/pki/etcd/`.

### Solution

```bash
mkdir -p /tmp/exam/q25
cat > /tmp/exam/q25/backup-etcd.sh <<'EOF'
#!/bin/bash
set -euo pipefail
export ETCDCTL_API=3
etcdctl   --endpoints=https://127.0.0.1:2379   --cacert=/etc/kubernetes/pki/etcd/ca.crt   --cert=/etc/kubernetes/pki/etcd/server.crt   --key=/etc/kubernetes/pki/etcd/server.key   snapshot save /tmp/exam/q25/etcd-backup.db
EOF
chmod +x /tmp/exam/q25/backup-etcd.sh
```
