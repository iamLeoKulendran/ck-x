This repository is a CK-X Simulator project for generating CKA 2026 and CKS 2026 mock exams and practice question sets.

Project skills:
- For CKA content: /cka-exam-generator-2026
- For CKS content: /cks-exam-generator-2026

Primary goal:
- Generate hard, original, CKA/Killer.sh-grade practice content.
- CK-X is the execution and validation platform, not the quality ceiling.
- Prefer realistic troubleshooting and administration scenarios over toy create-only tasks.

Repository rules:
- Detect facilitator/assets/exams/labs.json first; if absent, detect lab.json or root-level registry only as fallback.
- Create CKA labs under facilitator/assets/exams/cka/NNN/.
- Use the next available numeric lab folder unless a lab ID is explicitly provided.
- Do not overwrite existing labs without asking.
- Update labs.json or lab.json safely.
- Back up the lab registry before modifying it.
- Set executable permission on all setup and validation scripts.

CK-X file rules:
- Each lab must include config.json, assessment.json, answers.md.
- Each lab must include scripts/setup/qX_setup.sh.
- Each lab must include scripts/validation/qX_sY_validate_name.sh.
- machineHostname must normally be ckad9999.
- Do not use k8s-api-server as machineHostname unless this repo explicitly requires it.
- Setup scripts must be idempotent and non-interactive.
- Validation scripts must return exit 0 for success and non-zero for failure.
- Each question can have 2 to 5 validation scripts.
- Hard troubleshooting questions should usually have 3 to 5 validation scripts.
- Total marks must equal exactly 100.
- Every validation must check a positive final state.
- Avoid pure-negative validations that can pass before the student solves anything.
- Security/RBAC validations should check allowed and denied behavior where relevant.

CKS exam rules:
- All CKS content must be original. Do not copy Killer.sh, PSI, CNCF, Linux Foundation, or real exam content.
- "Killer.sh-style" means format, rigor, timing, scoring, and review workflow only.
- Default difficulty: Hard.
- Full CKS mock: 16 questions, 120 minutes by default.
- Allowed range: 15 to 18 questions only when explicitly requested.
- Use current CKS domain weights: Cluster Setup 15%, Cluster Hardening 15%, System Hardening 10%, Minimize Microservice Vulnerabilities 20%, Supply Chain Security 20%, Monitoring/Logging/Runtime Security 20%.
- Create CKS labs under facilitator/assets/exams/cks/NNN/ and register them in facilitator/assets/exams/labs.json with id cks-NNN and category CKS.
- machineHostname must be ckad9999.
- RBAC and policy validations must test both allowed and denied behavior where practical.
- No validation may pass on the freshly broken setup state.
- Do not commit generated assets.tar.gz.

CKS backend capability rules (current k3d backend):
- k3d-safe now (real tasks): NetworkPolicy, RBAC, ServiceAccount hardening, Pod Security Admission labels, SecurityContext, seccomp RuntimeDefault, ValidatingAdmissionPolicy, Gatekeeper/Kyverno if installed by setup, Ingress TLS if installed by setup, trivy/kubesec/cosign/syft static tasks, audit-log analysis from planted files.
- Requires host capability later (bridge only): AppArmor, Falco/eBPF, gVisor RuntimeClass.
- Requires kubeadm later (bridge only): real API server flag hardening, real audit logging config, EncryptionConfiguration with etcdctl verification, kubelet config hardening, kube-bench remediation against real control-plane files, static pod manifest troubleshooting.
- Do not create impossible real tasks on k3d. Clearly label bridge/simulation tasks and validate them through files under /tmp/exam/qN/.
- Jumphost toolbox (pinned in jumphost/Dockerfile): trivy 0.71.0, kube-bench 0.15.6, kubesec 2.14.2, cosign 3.1.1, syft 1.45.1, etcdctl 3.6.12, yq 4.53.3.
- CKS skill validator: .claude/skills/cks-exam-generator-2026/scripts/validate_ckx_cks_lab.sh
- CKS generation guide: docs/cks-lab-generation-guide.md

CKA exam rules:
- Default difficulty: Medium to Hard.
- Use Hard, Medium, or Easy only when explicitly requested.
- Full 2-hour actual-style mock exam: 17 questions by default.
- Allowed actual-style range: 17 to 19 questions.
- Generate 25 questions only if explicitly requested.
- Use current CKA domains and weights.
- Use terminal-based, performance-based Kubernetes tasks.
- Prefer realistic broken-state troubleshooting over simple create-only tasks.

Current backend rules:
- Current CK-X backend is k3d/K3s, not real kubeadm.
- Do not generate real kubeadm upgrade/init/join/certificate-renewal/live-etcd-restore/live-static-pod-edit tasks for the current backend.
- Use bridge tasks only when clearly labeled as simulation and validated through files, scripts, copied artifacts, logs, or safe diagnostics.

Source material rules:
- Generate original CKA-aligned tasks by default.
- Legally usable private PDFs, Markdown notes, and practice files provided by the user may be used as source material.
- Do not scrape, fetch, publish, copy, leak, or reproduce unauthorized, leaked, confidential, paid, private, NDA-protected, real exam, or Killer.sh content.
- If source material is provided, transform concepts into original CK-X scenarios for private practice.

Validation before final response:
- Validate all JSON files.
- Run bash -n for all .sh files.
- chmod +x setup and validation scripts.
- Verify all verificationScriptFile references exist.
- Verify total weightage equals 100.
- Verify 2 to 5 validation scripts per question.
- Run false-positive audit.
- Write validation-report.md when generating labs.
- ZIP archive is optional for backup/export only; CK-X runtime does not require it.