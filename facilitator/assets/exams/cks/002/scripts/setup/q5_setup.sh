#!/bin/bash
set -euo pipefail

NS="cp-hardening"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/exam/q5

# Plant a COPIED, insecure kube-apiserver manifest (simulation artifact).
# Re-planting on every setup run resets the question to its broken state.
cat > /tmp/exam/q5/kube-apiserver.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
  labels:
    component: kube-apiserver
    tier: control-plane
spec:
  hostNetwork: true
  priorityClassName: system-node-critical
  containers:
  - name: kube-apiserver
    image: registry.k8s.io/kube-apiserver:v1.31.4
    command:
    - kube-apiserver
    - --advertise-address=172.18.0.3
    - --allow-privileged=true
    - --anonymous-auth=true
    - --authorization-mode=AlwaysAllow
    - --enable-admission-plugins=NamespaceLifecycle
    - --etcd-servers=https://127.0.0.1:2379
    - --secure-port=6443
    - --service-account-issuer=https://kubernetes.default.svc.cluster.local
    - --service-cluster-ip-range=10.96.0.0/12
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
    ports:
    - containerPort: 6443
      hostPort: 6443
      name: https
YAML

echo "Question 5 setup complete"
