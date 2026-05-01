# Practice Question - Workloads and Scheduling -1

Original CKA-style Workloads and Scheduling hard practice set.

Use the commands as reference solutions; equivalent valid fixes are acceptable when they satisfy validation.


## Q1. Deployment rollout recovery after bad image and paused rollout

Namespace: `cka-q01`

```bash
kubectl -n cka-q01 rollout resume deploy/frontend-api
kubectl -n cka-q01 set image deploy/frontend-api frontend=nginx:1.27
kubectl -n cka-q01 scale deploy/frontend-api --replicas=3
kubectl -n cka-q01 rollout status deploy/frontend-api
```


## Q2. Deployment readiness and rolling update settings

Namespace: `cka-q02`

```bash
kubectl -n cka-q02 patch deploy orders-web --type='json' -p='[
  {"op":"replace","path":"/spec/strategy/rollingUpdate/maxUnavailable","value":0},
  {"op":"replace","path":"/spec/strategy/rollingUpdate/maxSurge","value":1},
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"},
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/port","value":80}
]'
kubectl -n cka-q02 rollout status deploy/orders-web
```


## Q3. StatefulSet headless Service and stable identity

Namespace: `cka-q03`

`serviceName` is immutable on a StatefulSet in many Kubernetes versions. Recreate the StatefulSet with the correct value.

```bash
kubectl -n cka-q03 get sts ledger-db -o yaml > /tmp/q03-ledger-db.yaml
kubectl -n cka-q03 delete sts ledger-db --cascade=orphan
kubectl -n cka-q03 create service clusterip ledger-db-hl --clusterip=None --tcp=80:80
kubectl -n cka-q03 label svc ledger-db-hl app=ledger-db --overwrite
# Edit /tmp/q03-ledger-db.yaml: set spec.serviceName: ledger-db-hl, remove metadata uid/resourceVersion/status
kubectl apply -f /tmp/q03-ledger-db.yaml
kubectl -n cka-q03 rollout status sts/ledger-db
```

Fast recreate alternative:

```bash
kubectl -n cka-q03 delete sts ledger-db
kubectl -n cka-q03 create service clusterip ledger-db-hl --clusterip=None --tcp=80:80
kubectl -n cka-q03 label svc ledger-db-hl app=ledger-db --overwrite
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ledger-db
  namespace: cka-q03
spec:
  serviceName: ledger-db-hl
  replicas: 2
  selector:
    matchLabels: {app: ledger-db}
  template:
    metadata:
      labels: {app: ledger-db}
    spec:
      containers:
      - name: db
        image: nginx:1.27
        ports: [{containerPort: 80}]
EOF
```


## Q4. StatefulSet persistent storage via volumeClaimTemplates

Namespace: `cka-q04`

Recreate the StatefulSet because `volumeClaimTemplates` is immutable.

```bash
kubectl -n cka-q04 delete sts metrics-store
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: metrics-store
  namespace: cka-q04
spec:
  serviceName: metrics-store-hl
  replicas: 2
  selector:
    matchLabels: {app: metrics-store}
  template:
    metadata:
      labels: {app: metrics-store}
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports: [{containerPort: 80}]
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 128Mi
EOF
kubectl -n cka-q04 rollout status sts/metrics-store
```

If your cluster has no `standard` StorageClass, use the available default StorageClass and keep the other required fields unchanged.


## Q5. DaemonSet must run on every node including control plane

Namespace: `cka-q05`

```bash
kubectl -n cka-q05 patch ds node-log-agent --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}
]'
kubectl -n cka-q05 rollout status ds/node-log-agent
```


## Q6. DaemonSet node-specific scheduling label repair

Namespace: `cka-q06`

```bash
NODE=$(kubectl get nodes --no-headers | awk '!/control-plane|master/ {print $1; exit}')
[ -z "$NODE" ] && NODE=$(kubectl get nodes --no-headers | awk '{print $1; exit}')
kubectl label node "$NODE" q06.capture=true --overwrite
kubectl -n cka-q06 rollout status ds/packet-capture
```


## Q7. Job manifest restartPolicy and completion repair

Namespace: `cka-q07`

```bash
sed -i 's/restartPolicy: Always/restartPolicy: OnFailure/' /tmp/exam/q07/checksum-job.yaml
kubectl apply -f /tmp/exam/q07/checksum-job.yaml
kubectl -n cka-q07 wait --for=condition=complete job/checksum-job --timeout=60s
```


## Q8. CronJob schedule, suspend, and concurrency repair

Namespace: `cka-q08`

```bash
kubectl -n cka-q08 patch cronjob db-cleanup --type='merge' -p '{
  "spec": {
    "schedule": "*/5 * * * *",
    "timeZone": "Asia/Colombo",
    "concurrencyPolicy": "Forbid",
    "suspend": false
  }
}'
kubectl -n cka-q08 get cronjob db-cleanup -o yaml
```


## Q9. CrashLoopBackOff from aggressive liveness probe

Namespace: `cka-q09`

```bash
kubectl -n cka-q09 patch deploy slow-api --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/startupProbe","value":{"exec":{"command":["cat","/tmp/healthy"]},"periodSeconds":1,"failureThreshold":30}},
  {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/periodSeconds","value":5}
]'
kubectl -n cka-q09 rollout status deploy/slow-api --timeout=90s
```


## Q10. Service endpoints empty from readiness probe failure

Namespace: `cka-q10`

```bash
kubectl -n cka-q10 patch deploy catalog-web --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}
]'
kubectl -n cka-q10 rollout status deploy/catalog-web
kubectl -n cka-q10 get endpoints catalog-web
```


## Q11. ConfigMap environment variable key mismatch

Namespace: `cka-q11`

```bash
kubectl -n cka-q11 set env deploy/config-consumer APP_MODE-
kubectl -n cka-q11 set env deploy/config-consumer APP_MODE--from=configmap/app-settings
# Or patch exactly:
kubectl -n cka-q11 patch deploy config-consumer --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/configMapKeyRef/key","value":"APP_MODE"}
]'
kubectl -n cka-q11 rollout status deploy/config-consumer
```


## Q12. Secret key injection failure

Namespace: `cka-q12`

```bash
kubectl -n cka-q12 patch deploy payment-worker --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"password"}
]'
kubectl -n cka-q12 rollout status deploy/payment-worker
```


## Q13. Pod hard-pinned to nonexistent nodeName

Namespace: `cka-q13`

```bash
kubectl -n cka-q13 get pod pinned-cache -o yaml > /tmp/q13-pod.yaml
kubectl -n cka-q13 delete pod pinned-cache
# Remove spec.nodeName, status, resourceVersion, uid from /tmp/q13-pod.yaml
kubectl apply -f /tmp/q13-pod.yaml
kubectl -n cka-q13 wait --for=condition=Ready pod/pinned-cache --timeout=60s
```

Fast recreate:

```bash
kubectl -n cka-q13 delete pod pinned-cache
kubectl -n cka-q13 run pinned-cache --image=nginx:1.27 --labels=app=pinned-cache
```


## Q14. nodeSelector label mismatch

Namespace: `cka-q14`

```bash
NODE=$(kubectl get nodes --no-headers | awk '!/control-plane|master/ {print $1; exit}')
[ -z "$NODE" ] && NODE=$(kubectl get nodes --no-headers | awk '{print $1; exit}')
kubectl label node "$NODE" q14.disk=ssd --overwrite
kubectl -n cka-q14 rollout status deploy/reporting-api
```


## Q15. Required nodeAffinity blocks scheduling

Namespace: `cka-q15`

```bash
kubectl -n cka-q15 patch deploy analytics-api --type='json' -p='[
  {"op":"remove","path":"/spec/template/spec/affinity/nodeAffinity/requiredDuringSchedulingIgnoredDuringExecution"},
  {"op":"add","path":"/spec/template/spec/affinity/nodeAffinity/preferredDuringSchedulingIgnoredDuringExecution","value":[{"weight":80,"preference":{"matchExpressions":[{"key":"q15.accelerator","operator":"In","values":["gpu"]}]}}]}
]'
kubectl -n cka-q15 rollout status deploy/analytics-api
```


## Q16. Taints and tolerations for reserved nodes

Namespace: `cka-q16`

```bash
kubectl -n cka-q16 patch deploy reserved-api --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/tolerations","value":[
    {"key":"q16.pool","operator":"Equal","value":"reserved","effect":"NoSchedule"},
    {"key":"q16.soft","operator":"Equal","value":"reserved","effect":"PreferNoSchedule"},
    {"key":"q16.evict","operator":"Equal","value":"reserved","effect":"NoExecute","tolerationSeconds":300}
  ]}
]'
kubectl -n cka-q16 rollout status deploy/reserved-api
```


## Q17. Pod anti-affinity topologyKey correction

Namespace: `cka-q17`

```bash
kubectl -n cka-q17 patch deploy ha-web --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/affinity/podAntiAffinity/requiredDuringSchedulingIgnoredDuringExecution/0/topologyKey","value":"kubernetes.io/hostname"}
]'
kubectl -n cka-q17 rollout status deploy/ha-web
kubectl -n cka-q17 get pods -l app=ha-web -o wide
```


## Q18. TopologySpreadConstraints selector and maxSkew repair

Namespace: `cka-q18`

```bash
kubectl -n cka-q18 patch deploy pay-api --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/topologySpreadConstraints/0/labelSelector/matchLabels/app","value":"pay-api"}
]'
kubectl -n cka-q18 rollout status deploy/pay-api
kubectl -n cka-q18 get pods -l app=pay-api -o wide
```


## Q19. ResourceQuota conflict from excessive requests

Namespace: `cka-q19`

```bash
kubectl -n cka-q19 set resources deploy/quota-api   --requests=cpu=100m,memory=64Mi   --limits=cpu=200m,memory=128Mi
kubectl -n cka-q19 rollout status deploy/quota-api
kubectl -n cka-q19 describe quota compute-quota
```


## Q20. PriorityClass and preemption policy repair

Namespace: `cka-q20`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: business-critical
value: 100000
preemptionPolicy: PreemptLowerPriority
globalDefault: false
description: "Business critical workload priority for CKA practice"
EOF
kubectl -n cka-q20 rollout restart deploy/critical-api
kubectl -n cka-q20 rollout status deploy/critical-api
```
