# Answers — Mock Exam: CKA revision -1 (cka-005)

---

## Question 1 — Init container unblocked by missing Service

**Goal:** Create Service `db-service` and backing Pod so the init container can complete.

```bash
# Create backing Pod
kubectl -n rev1-q01 run db-backend --image=nginx:1.27 --labels=app=db

# Create Service mapping port 5432 -> targetPort 80
kubectl -n rev1-q01 expose pod db-backend \
  --name=db-service --port=5432 --target-port=80 --type=ClusterIP
```

**Verify:**
```bash
kubectl -n rev1-q01 get pod web-init
# Phase should become Running once init container succeeds
```

---

## Question 2 — Service targetPort mismatch

**Goal:** Patch `frontend-svc` targetPort from 80 to 8080.

```bash
kubectl -n rev1-q02 patch service frontend-svc \
  -p '{"spec":{"ports":[{"port":80,"targetPort":8080}]}}'
```

**Verify:**
```bash
kubectl -n rev1-q02 get endpoints frontend-svc
kubectl -n rev1-q02 get service frontend-svc -o jsonpath='{.spec.ports[0].targetPort}'
```

---

## Question 3 — Helm rollback and upgrade

**Goal:** Roll back to revision 1, then upgrade with corrected values.

```bash
# Check release history
helm history web-frontend -n rev1-q03

# Roll back to revision 1
helm rollback web-frontend 1 -n rev1-q03

# Upgrade with good values (creates next revision)
helm upgrade web-frontend /tmp/exam/q3/chart.tgz \
  -n rev1-q03 -f /tmp/exam/q3/good-values.yaml
```

**Verify:**
```bash
helm status web-frontend -n rev1-q03
kubectl -n rev1-q03 get deployment web-frontend
```

---

## Question 4 — Deployment with init container and shared emptyDir

**Goal:** Create `config-loader` with init container copying config to a shared volume.

```bash
kubectl -n rev1-q04 apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-loader
  namespace: rev1-q04
spec:
  replicas: 3
  selector:
    matchLabels:
      app: config-loader
  template:
    metadata:
      labels:
        app: config-loader
    spec:
      initContainers:
      - name: init-copy
        image: busybox:1.36
        command: ["cp", "/input/app.conf", "/shared/app.conf"]
        volumeMounts:
        - name: config-input
          mountPath: /input
        - name: shared-data
          mountPath: /shared
      containers:
      - name: web
        image: nginx:1.27
        volumeMounts:
        - name: shared-data
          mountPath: /etc/app/
      volumes:
      - name: config-input
        configMap:
          name: app-config
      - name: shared-data
        emptyDir: {}
EOF
```

---

## Question 5 — PVC stuck Pending (wrong StorageClass)

**Goal:** Delete PVC `app-data`, recreate with `local-path`, mount into a Pod.

```bash
kubectl -n rev1-q05 delete pvc app-data

kubectl -n rev1-q05 apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: rev1-q05
spec:
  storageClassName: local-path
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 500Mi
EOF

kubectl -n rev1-q05 run app-pod --image=nginx:1.27 \
  --overrides='{"spec":{"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"app-data"}}],"containers":[{"name":"app-pod","image":"nginx:1.27","volumeMounts":[{"name":"d","mountPath":"/data"}]}]}}'
```

---

## Question 6 — CrashLoopBackOff from readOnly volumeMount

**Goal:** Remove `readOnly: true` from the volumeMount, recreate Pod.

```bash
# Export current pod spec
kubectl -n rev1-q06 get pod data-processor -o yaml > /tmp/data-processor.yaml

# Edit: remove "readOnly: true" from the volumeMount
# Then delete and recreate
kubectl -n rev1-q06 delete pod data-processor
kubectl -n rev1-q06 apply -f /tmp/data-processor.yaml
```

**Alternative patch:**
```bash
kubectl -n rev1-q06 get pod data-processor -o json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for vm in d['spec']['containers'][0]['volumeMounts']:
    vm.pop('readOnly', None)
d['metadata'].pop('resourceVersion', None)
d['metadata'].pop('uid', None)
print(json.dumps(d))" | kubectl apply -f -
```

---

## Question 7 — Merge kubeconfig files

**Goal:** Merge both kubeconfig files into `/tmp/exam/q7/merged-config.yaml`, set `prod-context`.

```bash
KUBECONFIG=/tmp/exam/q7/kube-dev:/tmp/exam/q7/kube-prod \
  kubectl config view --flatten > /tmp/exam/q7/merged-config.yaml

KUBECONFIG=/tmp/exam/q7/merged-config.yaml \
  kubectl config use-context prod-context
```

**Verify:**
```bash
KUBECONFIG=/tmp/exam/q7/merged-config.yaml kubectl config get-contexts
KUBECONFIG=/tmp/exam/q7/merged-config.yaml kubectl config current-context
```

---

## Question 8 — Node drain blocked by PodDisruptionBudget

**Goal:** Patch PDB to allow eviction, drain node, uncordon.

```bash
NODE=$(cat /tmp/exam/q8/target-node.txt)

# Lower minAvailable to allow drain
kubectl -n rev1-q08 patch pdb api-pdb \
  -p '{"spec":{"minAvailable":1}}'

# Drain the node
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data

# Uncordon after maintenance
kubectl uncordon "$NODE"
```

---

## Question 9 — DaemonSet OnDelete to RollingUpdate

**Goal:** Change updateStrategy to RollingUpdate, update image to nginx:1.28.

```bash
kubectl -n rev1-q09 patch daemonset log-collector --type='json' -p='[
  {"op":"replace","path":"/spec/updateStrategy/type","value":"RollingUpdate"},
  {"op":"add","path":"/spec/updateStrategy/rollingUpdate","value":{"maxUnavailable":1}}
]'

kubectl -n rev1-q09 set image daemonset/log-collector log-collector=nginx:1.28

kubectl -n rev1-q09 rollout status daemonset/log-collector
```

---

## Question 10 — NetworkPolicy: combined ingress and egress

**Goal:** Create `api-policy` allowing ingress from frontend on 8080 and egress to db on 5432.

```bash
kubectl -n rev1-q10 apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
  namespace: rev1-q10
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: db
    ports:
    - port: 5432
EOF
```

---

## Question 11 — Pending pod due to ResourceQuota CPU exhaustion

**Goal:** Identify quota exhaustion, reduce `batch-worker` CPU requests to fit.

```bash
# Investigate
kubectl -n rev1-q11 describe pod -l app=batch-worker
kubectl -n rev1-q11 describe resourcequota cpu-quota

# Fix: patch Deployment to use 100m CPU (fits within remaining quota)
kubectl -n rev1-q11 patch deployment batch-worker --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"100m"}
]'
```

---

## Question 12 — Kustomize configMapGenerator with namePrefix

**Goal:** Create Kustomize overlay, apply to generate ConfigMap in `rev1-q12`.

```bash
mkdir -p /tmp/exam/q12/overlay

cat > /tmp/exam/q12/overlay/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: rev1-q12
namePrefix: prod-
configMapGenerator:
- name: app-properties
  files:
  - /tmp/exam/q12/app.properties
EOF

kubectl apply -k /tmp/exam/q12/overlay/
```

**Verify:**
```bash
kubectl -n rev1-q12 get configmap
```

---

## Question 13 — StatefulSet with wrong StorageClass

**Goal:** Delete StatefulSet, recreate with `storageClassName: standard`.

```bash
# Export current spec
kubectl -n rev1-q13 get statefulset cache-cluster -o yaml > /tmp/cache-cluster.yaml

# Edit: change premium-nvme -> standard in volumeClaimTemplates
sed -i 's/premium-nvme/standard/g' /tmp/cache-cluster.yaml

# Delete and recreate (volumeClaimTemplates immutable)
kubectl -n rev1-q13 delete statefulset cache-cluster
kubectl apply -f /tmp/cache-cluster.yaml
```

**Verify:**
```bash
kubectl -n rev1-q13 get statefulset cache-cluster
kubectl -n rev1-q13 get pvc
```

---

## Question 14 — Readiness probe port + Service targetPort

**Goal:** Fix both probe port and Service targetPort from 80 to 8080.

```bash
# Fix readiness probe port in Deployment
kubectl -n rev1-q14 patch deployment api-server --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/port","value":8080}
]'

# Fix Service targetPort
kubectl -n rev1-q14 patch service api-svc \
  -p '{"spec":{"ports":[{"port":80,"targetPort":8080}]}}'
```

**Verify:**
```bash
kubectl -n rev1-q14 rollout status deployment/api-server
kubectl -n rev1-q14 get endpoints api-svc
```

---

## Question 15 — Fix CronJob with PVC output

**Goal:** Update schedule, command, volume mount, and history limits.

```bash
kubectl -n rev1-q15 apply -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report-gen
  namespace: rev1-q15
spec:
  schedule: "*/5 * * * *"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: reporter
            image: busybox:1.36
            command: ["sh", "-c", "date >> /data/reports/output.txt"]
            volumeMounts:
            - name: report-vol
              mountPath: /data/reports
          restartPolicy: OnFailure
          volumes:
          - name: report-vol
            persistentVolumeClaim:
              claimName: report-data
EOF
```

---

## Question 16 — Install CRD and create custom resources

**Goal:** Install CRD, create two DatabaseBackup CRs, write list script.

```bash
# Install CRD
kubectl apply -f /tmp/exam/q16/databasebackup-crd.yaml

# Create CRs
kubectl -n rev1-q16 apply -f - <<'EOF'
apiVersion: ops.example.com/v1
kind: DatabaseBackup
metadata:
  name: weekly-pg
  namespace: rev1-q16
spec:
  targetDB: postgres
  schedule: "0 2 * * 0"
  retentionDays: 7
---
apiVersion: ops.example.com/v1
kind: DatabaseBackup
metadata:
  name: daily-mysql
  namespace: rev1-q16
spec:
  targetDB: mysql
  schedule: "0 3 * * *"
  retentionDays: 3
EOF

# Write list script
cat > /tmp/exam/q16/list.sh <<'SCRIPT'
#!/bin/bash
kubectl get databasebackups --all-namespaces \
  -o custom-columns='NAME:.metadata.name,TARGET:.spec.targetDB,SCHEDULE:.spec.schedule'
SCRIPT
chmod +x /tmp/exam/q16/list.sh
```

---

## Question 17 — Multi-port named-port Service

**Goal:** Create Deployment with named ports, Service using port names as targetPort.

```bash
kubectl -n rev1-q17 apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dual-svc-app
  namespace: rev1-q17
spec:
  replicas: 3
  selector:
    matchLabels:
      app: dual-svc-app
  template:
    metadata:
      labels:
        app: dual-svc-app
    spec:
      containers:
      - name: app
        image: nginx:1.27
        ports:
        - name: http
          containerPort: 8080
        - name: metrics
          containerPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: dual-svc
  namespace: rev1-q17
spec:
  selector:
    app: dual-svc-app
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: metrics
    port: 9090
    targetPort: metrics
EOF
```

**Verify:**
```bash
kubectl -n rev1-q17 get service dual-svc \
  -o jsonpath='{.spec.ports[*].targetPort}'
kubectl -n rev1-q17 get endpoints dual-svc
```
