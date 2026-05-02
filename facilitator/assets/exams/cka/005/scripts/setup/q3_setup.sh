#!/bin/bash
set -euo pipefail
NS="rev1-q03"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q3
rm -rf /tmp/exam/q3/nginx-chart

# Build minimal nginx chart
mkdir -p /tmp/exam/q3/nginx-chart/templates
cat > /tmp/exam/q3/nginx-chart/Chart.yaml <<'CHART'
apiVersion: v2
name: nginx-chart
description: Minimal nginx chart for CKA practice
version: 1.0.0
appVersion: "1.27"
CHART

cat > /tmp/exam/q3/nginx-chart/values.yaml <<'VALUES'
replicaCount: 1
image:
  repository: nginx
  tag: "1.27"
  pullPolicy: IfNotPresent
VALUES

cat > /tmp/exam/q3/nginx-chart/templates/deployment.yaml <<'TMPL'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
      - name: nginx
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: 80
TMPL

# Package chart and expose as a fixed name the question references
helm package /tmp/exam/q3/nginx-chart -d /tmp/exam/q3/ >/dev/null 2>&1
mv /tmp/exam/q3/nginx-chart-*.tgz /tmp/exam/q3/chart.tgz

# Clean previous release
helm uninstall web-frontend -n "$NS" 2>/dev/null || true
sleep 3

# Install rev 1 (healthy, wait for it)
helm install web-frontend /tmp/exam/q3/nginx-chart -n "$NS" --wait --timeout 120s >/dev/null 2>&1

# Upgrade to rev 2 with bad image tag (ImagePullBackOff)
helm upgrade web-frontend /tmp/exam/q3/nginx-chart -n "$NS" --set image.tag=NOT-A-REAL-TAG-9999 >/dev/null 2>&1 || true

# Stage corrected values file for candidate
cat > /tmp/exam/q3/good-values.yaml <<'GOODVALS'
replicaCount: 3
image:
  repository: nginx
  tag: "1.27"
  pullPolicy: IfNotPresent
GOODVALS

echo "Q3 setup complete"
