#!/bin/bash
set -euo pipefail
NS="rev1-q16"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q16
rm -f /tmp/exam/q16/list.sh

# Remove existing CRD and CRs (idempotent)
kubectl delete crd databasebackups.ops.example.com --ignore-not-found=true 2>/dev/null || true
sleep 1

# Stage CRD manifest for candidate to install
cat > /tmp/exam/q16/databasebackup-crd.yaml <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databasebackups.ops.example.com
spec:
  group: ops.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["targetDB", "schedule", "retentionDays"]
            properties:
              targetDB:
                type: string
              schedule:
                type: string
              retentionDays:
                type: integer
  scope: Namespaced
  names:
    plural: databasebackups
    singular: databasebackup
    kind: DatabaseBackup
    shortNames:
    - dbbackup
EOF

echo "Q16 setup complete"
