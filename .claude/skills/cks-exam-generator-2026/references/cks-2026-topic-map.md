# CKS 2026 Topic Map for CK-X Lab Generation

## Official-Style Domain Model

- Cluster Setup: 15%
- Cluster Hardening: 15%
- System Hardening: 10%
- Minimize Microservice Vulnerabilities: 20%
- Supply Chain Security: 20%
- Monitoring, Logging and Runtime Security: 20%

## Quality Target

Generate original CKS/Killer.sh-grade scenarios. Do not copy official exam, Killer.sh, PSI, CNCF, Linux Foundation, paid, private, NDA-protected, or leaked content. "Killer.sh-style" means format, rigor, timing, scoring, and review workflow only.

Questions should be serious security scenarios: harden a broken workload, find and fix the violation, lock down access, analyze a planted artifact, prove the policy blocks the attack. Multi-step, exact, time-pressured, validated by real end state.

## Cluster Setup (15%)

Tier 1 runnable on k3d:

- NetworkPolicy: default-deny, namespace isolation, label-based ingress/egress, metadata endpoint blocking.
- Ingress TLS with secrets (setup installs/uses available ingress controller).
- CIS benchmark analysis from planted kube-bench output.
- Verify platform binaries with sha256sum (use real jumphost/node binaries such as `kubectl`, `k3s`).

Bridge only:

- Real API server flag review and node metadata protection at cloud level.

## Cluster Hardening (15%)

Tier 1 runnable on k3d:

- RBAC least privilege: Roles, ClusterRoles, bindings, `resourceNames`, removing wildcard verbs.
- ServiceAccount hardening: `automountServiceAccountToken: false`, dedicated minimal SAs, deleting/avoiding default SA usage.
- `kubectl auth can-i` verification of allowed and denied actions.
- Restricting anonymous and overprivileged access at RBAC level.
- Kubeconfig and certificate inspection from planted files.

Bridge only:

- Real API server `--anonymous-auth`, admission plugin flags, kubelet config hardening.
- Version upgrade tasks (no kubeadm).

## System Hardening (10%)

Tier 1 runnable on k3d:

- SecurityContext: runAsNonRoot, runAsUser/Group, drop ALL capabilities, readOnlyRootFilesystem, allowPrivilegeEscalation false.
- seccomp RuntimeDefault via securityContext.
- Minimizing host access: removing hostPath, hostNetwork, hostPID from manifests.
- Analyzing planted process/port/service listings to identify what to disable.

Bridge only:

- AppArmor profile authoring (file-validated, clearly labeled as not enforced).
- Real OS-level service/kernel hardening.

## Minimize Microservice Vulnerabilities (20%)

Tier 1 runnable on k3d:

- Pod Security Admission: namespace labels (enforce/audit/warn at baseline/restricted), compliant vs rejected pods, capturing rejection errors.
- ValidatingAdmissionPolicy (CEL): write policy + binding, prove violating resource rejected and compliant accepted.
- Gatekeeper or Kyverno policies if setup installs them.
- Secrets: proper Secret usage, mounting, env exposure review, finding secrets leaked in manifests/env/configmaps, decoding and rotating.
- Isolation review: choosing/justifying sandboxing in written form.

Bridge only:

- gVisor RuntimeClass (manifest-validated only).
- Real EncryptionConfiguration with etcdctl verification.

## Supply Chain Security (20%)

Tier 1 runnable on k3d (tools installed on jumphost):

- trivy: scan images/filesystems, extract specific CVE findings into report files, pick the image with fewest/no HIGH+CRITICAL.
- kubesec: score manifests, fix lowest-scoring issues, re-score above a threshold.
- syft: generate SBOMs, query SBOM for specific packages/versions.
- cosign: verify signatures against planted keys/signed artifacts created by setup.
- Dockerfile security review: fix planted Dockerfiles (root user, latest tags, secrets in layers, unnecessary packages).
- Manifest security review: fix planted manifests with dangerous settings.
- Registry restrictions via admission policy (VAP/Kyverno/Gatekeeper) allowing only approved registries.
- ImagePolicyWebhook config file authoring (file-validated bridge if no webhook backend).

## Monitoring, Logging and Runtime Security (20%)

Tier 1 runnable on k3d:

- Audit-log analysis from planted audit log files: find who accessed a secret, which SA deleted a resource, extract answers to files.
- Behavioral analysis from planted process/syscall traces or container logs.
- Detecting and freezing a compromised workload: identify the suspicious pod from planted evidence, scale down/isolate with NetworkPolicy, capture evidence to files.
- Immutability: enforce readOnlyRootFilesystem, remove shell access patterns, validate pod still Running.

Bridge only:

- Falco rule authoring (rule-file-validated, clearly labeled as not running).
- Real audit policy wiring into API server.

## Concept Naming for Weak-Area Tracking

Use consistent concept strings across CKS labs:

`network policies`, `ingress tls`, `cis benchmark`, `binary verification`, `rbac`, `service accounts`, `least privilege`, `pod security admission`, `security context`, `seccomp`, `admission control`, `validating admission policy`, `secrets`, `encryption`, `image scanning`, `sbom`, `image signing`, `dockerfile security`, `registry security`, `supply chain`, `audit logs`, `runtime security`, `incident response`, `immutability`, `apparmor (bridge)`, `falco (bridge)`, `gvisor (bridge)`
