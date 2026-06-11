#!/bin/bash
set -euo pipefail

kubectl create namespace cis-review --dry-run=client -o yaml | kubectl apply -f - >/dev/null

mkdir -p /tmp/exam/q2
rm -f /tmp/exam/q2/failed-checks.txt /tmp/exam/q2/remediation-1.2.1.txt

cat > /tmp/exam/q2/kube-bench-results.txt <<'REPORT'
[INFO] 1 Control Plane Security Configuration
[INFO] 1.1 Control Plane Node Configuration Files
[PASS] 1.1.1 Ensure that the API server pod specification file permissions are set to 600 or more restrictive
[INFO] 1.2 API Server
[FAIL] 1.2.1 Ensure that the --anonymous-auth argument is set to false
[PASS] 1.2.2 Ensure that the --token-auth-file parameter is not set
[WARN] 1.2.9 Ensure that the admission control plugin EventRateLimit is set
[FAIL] 1.2.18 Ensure that the --profiling argument is set to false
[INFO] 1.4 Scheduler
[FAIL] 1.4.1 Ensure that the --profiling argument is set to false
[INFO] 3.2 Logging
[WARN] 3.2.1 Ensure that a minimal audit policy is created
[INFO] 4 Worker Node Security Configuration
[INFO] 4.1 Worker Node Configuration Files
[PASS] 4.1.1 Ensure that the kubelet service file permissions are set to 600 or more restrictive
[INFO] 4.2 Kubelet
[FAIL] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true

== Remediations ==
1.2.1 Edit the API server pod specification file on the control plane node and set the below parameter:
--anonymous-auth=false
1.2.18 Edit the API server pod specification file on the control plane node and set the below parameter:
--profiling=false
1.4.1 Edit the Scheduler pod specification file on the control plane node and set the below parameter:
--profiling=false
4.2.6 If using a kubelet config file, edit the file to set protectKernelDefaults to true.

== Summary total ==
3 checks PASS
4 checks FAIL
2 checks WARN
REPORT

echo "Question 2 setup complete"
