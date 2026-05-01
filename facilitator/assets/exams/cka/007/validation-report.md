# Validation Report - Practice Question - Workloads and Scheduling -1

## Static validation

- Questions: 20
- Total weightage: 100
- Setup scripts: 20
- Validation scripts: 60
- JSON validation: passed
- Bash syntax validation: passed
- Reference validation: passed
- Executable bit validation: passed
- Validation count rule: passed
- False-positive audit: static audit passed; each validation includes positive expected-state checks and explicit pass/fail paths

## Runtime validation

- Runtime cluster testing: not performed in this environment. Run setup scripts and validation scripts inside the target Kubernetes simulator cluster.

## Topic coverage

- Deployment troubleshooting and rolling updates: Q1-Q2
- StatefulSet identity, DNS, PVC templates, headless Service: Q3-Q4
- DaemonSet scheduling and control-plane tolerations: Q5-Q6
- Job/CronJob restartPolicy, concurrency, schedule/timeZone: Q7-Q8
- Probe failures and CrashLoopBackOff/readiness endpoint repair: Q9-Q10
- ConfigMap/Secret injection: Q11-Q12
- nodeName, nodeSelector, nodeAffinity: Q13-Q15
- Taints/tolerations including NoSchedule, PreferNoSchedule, NoExecute: Q16
- podAntiAffinity and topologySpreadConstraints: Q17-Q18
- Resource requests/limits and ResourceQuota conflict: Q19
- PriorityClass and preemption policy: Q20

## Errors
- None
