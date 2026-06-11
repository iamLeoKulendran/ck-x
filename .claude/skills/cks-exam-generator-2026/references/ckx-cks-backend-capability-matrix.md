# CK-X CKS Backend Capability Matrix

Current backend: k3d/K3s (single cluster in DinD), jumphost `ckad9999`, no kubeadm, no host AppArmor/eBPF control. Classify every question against this matrix before generating it.

## Tier 1 — k3d-safe now: generate as REAL runnable tasks

| Capability | Notes |
| --- | --- |
| NetworkPolicy | k3s enforces natively via built-in controller |
| RBAC | full support; verify with `kubectl auth can-i` |
| ServiceAccount hardening | automount, minimal SAs, token projection |
| Pod Security Admission labels | enforced natively in k3s v1.31+ |
| SecurityContext | runAsNonRoot, capabilities, readOnlyRootFilesystem, etc. |
| seccomp RuntimeDefault | via pod/container securityContext |
| ValidatingAdmissionPolicy | CEL-based, built into current Kubernetes |
| Gatekeeper / Kyverno | only if installed by the question's setup script |
| Ingress TLS | only if setup installs/uses available ingress controller |
| trivy / kubesec / cosign / syft | installed on jumphost; static analysis tasks |
| etcdctl / yq / jq / helm | installed on jumphost |
| Audit-log analysis | from planted log files under /tmp/exam/qN/ |
| Dockerfile / manifest security review | from planted files |
| Secrets management | create, mount, find leaks, decode, rotate |
| Binary verification | sha256sum of real binaries (kubectl, k3s) |

## Tier 2 — requires host capability later: BRIDGE ONLY

| Capability | Why blocked | Allowed bridge form |
| --- | --- | --- |
| AppArmor | k3d nodes lack host AppArmor control | author profile + manifest to files; validate files; label as not enforced |
| Falco / eBPF | no host kernel instrumentation | author Falco rule files; validate structure; label as not running |
| gVisor RuntimeClass | runsc not installed in k3d nodes | author RuntimeClass + pod manifests to files; label as not runnable |

## Tier 3 — requires kubeadm backend later: BRIDGE ONLY

| Capability | Why blocked | Allowed bridge form |
| --- | --- | --- |
| Real API server flag hardening | no /etc/kubernetes/manifests in k3s | fix COPIED apiserver manifest under /tmp/exam/qN/ |
| Real audit logging config | cannot wire --audit-policy-file | write audit policy YAML to file; validate content |
| EncryptionConfiguration + etcdctl verify | cannot restart apiserver with config | write config + verification script; validate files |
| kubelet config hardening | k3s embeds kubelet | fix copied kubelet config file |
| kube-bench remediation on real files | no real control-plane files | analyze planted kube-bench output; write remediation files |
| Static pod manifest troubleshooting | no live static pod path | repair copied manifests under /tmp/exam/qN/ |

## Bridge Task Requirements

Every Tier 2/Tier 3 task MUST:

1. Say explicitly in the question text that it is simulated.
2. Tell the candidate not to execute destructive commands.
3. Work against artifacts under `/tmp/exam/qN/`.
4. Be validated through files, scripts, copied artifacts, logs, or safe diagnostics only.
5. Not exceed ~2-3 questions in a 16-question mock unless explicitly requested.
