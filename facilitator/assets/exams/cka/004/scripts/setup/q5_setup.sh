#!/bin/bash
set -euo pipefail
NS=cka-q05
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
mkdir -p /tmp/exam/q5
rm -f /tmp/exam/q5/sort_by_age.sh /tmp/exam/q5/sort_by_uid.sh
kubectl run q5-a --image=nginx:1.25 -n "$NS" --restart=Never --dry-run=client -o yaml | kubectl apply -f -
kubectl run q5-b --image=nginx:1.25 -n "$NS" --restart=Never --dry-run=client -o yaml | kubectl apply -f -
exit 0
