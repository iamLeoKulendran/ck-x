# CKA 2026 Topic Map for CK-X Lab Generation

## Official-Style Domain Model

- Cluster Architecture, Installation & Configuration: 25%
- Workloads & Scheduling: 15%
- Services & Networking: 20%
- Storage: 10%
- Troubleshooting: 30%

## Quality Target

Generate original CKA/Killer.sh-grade scenarios. Do not copy official exam, Killer.sh, paid, private, NDA-protected, or leaked content.

Questions should be serious admin scenarios: troubleshooting-heavy, multi-step, exact, time-pressured, and validated by real end state.

## Cluster Architecture, Installation & Configuration

Use practical tasks involving:

- RBAC.
- kubeadm workflow concepts.
- cluster lifecycle.
- control-plane awareness.
- Helm and Kustomize.
- CRDs/operators where reasonable.
- CNI/CSI/CRI concepts through symptoms.
- certificate and kubeconfig troubleshooting.

## Workloads & Scheduling

Use practical tasks involving:

- Deployments, ReplicaSets, StatefulSets, DaemonSets.
- Jobs and CronJobs.
- rollouts and rollbacks.
- probes, resources, ConfigMaps, and Secrets.
- nodeSelector, affinity, anti-affinity, taints, tolerations.
- PriorityClass and scheduling failures.

## Services & Networking

Use practical tasks involving:

- Services, selectors, endpoints, EndpointSlices.
- DNS and CoreDNS symptoms.
- NetworkPolicy ingress and egress.
- Ingress or Gateway API only when simulator support is confirmed.
- service-to-pod reachability troubleshooting.

## Storage

Use practical tasks involving:

- StorageClasses.
- PersistentVolumes and PersistentVolumeClaims.
- binding failures.
- storageClassName mismatch.
- reclaimPolicy.
- volume mounts.
- StatefulSet volumeClaimTemplates.

## Troubleshooting

Use practical tasks involving:

- Pending Pods.
- CrashLoopBackOff.
- ImagePullBackOff.
- failed rollouts.
- failed probes.
- Service and DNS failures.
- PVC binding issues.
- node readiness symptoms where accessible.
- logs and events.
- kubeconfig and certificate failures.
- etcd backup command preparation only unless kubeadm backend exists.
