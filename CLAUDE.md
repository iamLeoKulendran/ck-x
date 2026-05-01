This repository is a CK-X Simulator project for generating CKA 2026 mock exams and practice question sets.

Always use the project skill:
/cka-exam-generator-2026

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