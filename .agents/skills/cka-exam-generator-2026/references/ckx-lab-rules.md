# CK-X Lab Generation Rules

## Repository Root

Run Claude Code from the CK-X repository root. The root should contain:

- `.git/`
- `app/`
- `docs/`
- `facilitator/`
- `jumphost/`
- `kind-cluster/`
- `nginx/`
- `remote-desktop/`
- `remote-terminal/`

If not running from the root, stop and ask the user to reopen Claude Code from the CK-X repository root.

## Required Lab Folder

Create generated CKA labs only under:

```text
facilitator/assets/exams/cka/NNN/
```

Required files:

- `config.json`
- `assessment.json`
- `answers.md`
- `scripts/setup/qX_setup.sh`
- `scripts/validation/qX_sY_validate_name.sh`

Do not place generated lab files under app, backend source, Docker, cluster, remote desktop, remote terminal, or repository-level scripts unless the user explicitly asks for a separate task.

## Registry Detection

Check registry files in this order:

1. `facilitator/assets/exams/labs.json`
2. `facilitator/assets/exams/lab.json`
3. `labs.json`
4. `lab.json`

Use the registry file containing the top-level `labs` array. Prefer `facilitator/assets/exams/labs.json` if multiple registry files exist.

## Lab IDs

- Registry ID: `cka-NNN`
- Folder: `facilitator/assets/exams/cka/NNN`
- Asset path: `assets/exams/cka/NNN`

Choose the next numeric folder by scanning existing CKA folders and registry entries. Never overwrite an existing folder unless the user explicitly asks for replacement.

## Current Backend Limitations

The current CK-X backend is k3d/K3s, not kubeadm. Generate real runnable tasks for RBAC, workloads, scheduling, services, networking, storage, kubeconfig, logs, events, and kubectl troubleshooting.

Do not generate real current-backend tasks requiring:

- real kubeadm upgrade/init/join.
- real live etcd restore.
- real kubeadm certificate renewal.
- real edits to live `/etc/kubernetes/manifests`.
- real kubeadm control-plane component repair.

Use bridge simulations for those topics until the kubeadm backend exists.

## Weights

Total must equal 100.

Common full-mock splits:

- 17 questions: 15 x 6 marks and 2 x 5 marks.
- 18 questions: 10 x 6 marks and 8 x 5 marks.
- 19 questions: 5 x 6 marks and 14 x 5 marks.
- 25 questions: 25 x 4 marks, only when explicitly requested.

Each question should use 2 to 5 validation scripts.

## Validation Anti-False-Positive Rules

Validation must not pass before student work.

Each question needs at least one positive required end-state check.

Bad validation patterns:

- Only checking that a dangerous RBAC permission is absent.
- Only checking that a broken object is deleted.
- Only checking that a setup-created namespace exists.

Good validation patterns:

- Required object exists with exact fields.
- Workload becomes Ready or Available.
- Service has matching Endpoints.
- RBAC is checked by object spec and `kubectl auth can-i`.
- File tasks check path, content, and executable bit where needed.

## Runtime Validation Ideal

If a live cluster is available:

1. Run setup.
2. Run validation before solving and confirm the complete question does not already pass.
3. Apply answer or smoke solution.
4. Run validation again and confirm pass.

If no cluster is available, perform static validation and report that runtime validation was skipped.
