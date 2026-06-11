#!/bin/bash
set -euo pipefail

LAB_DIR="${1:-}"
REGISTRY="${2:-}"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

[ -n "$LAB_DIR" ] || fail "Usage: validate_ckx_cks_lab.sh facilitator/assets/exams/cks/NNN [registry.json]"
[ -d "$LAB_DIR" ] || fail "Lab directory not found: $LAB_DIR"

if [ -z "$REGISTRY" ]; then
  for f in facilitator/assets/exams/labs.json facilitator/assets/exams/lab.json labs.json lab.json; do
    if [ -f "$f" ]; then
      REGISTRY="$f"
      break
    fi
  done
fi

[ -n "$REGISTRY" ] || fail "Registry not found. Checked facilitator/assets/exams/labs.json, facilitator/assets/exams/lab.json, labs.json, lab.json"
[ -f "$REGISTRY" ] || fail "Registry not found: $REGISTRY"

[ -f "$LAB_DIR/config.json" ] || fail "Missing config.json"
[ -f "$LAB_DIR/assessment.json" ] || fail "Missing assessment.json"
[ -f "$LAB_DIR/answers.md" ] || fail "Missing answers.md"
[ -d "$LAB_DIR/scripts/setup" ] || fail "Missing scripts/setup directory"
[ -d "$LAB_DIR/scripts/validation" ] || fail "Missing scripts/validation directory"

python3 -m json.tool "$REGISTRY" >/dev/null || fail "Invalid registry JSON: $REGISTRY"
python3 -m json.tool "$LAB_DIR/config.json" >/dev/null || fail "Invalid config.json"
python3 -m json.tool "$LAB_DIR/assessment.json" >/dev/null || fail "Invalid assessment.json"
pass "JSON syntax valid"

find "$LAB_DIR/scripts" -type f -name '*.sh' -exec bash -n {} \; || fail "Shell syntax validation failed"
pass "Shell syntax valid"

python3 - "$LAB_DIR" "$REGISTRY" <<'PY'
import json
import os
import pathlib
import re
import sys

lab_dir = pathlib.Path(sys.argv[1])
registry_path = pathlib.Path(sys.argv[2])
config = json.loads((lab_dir / "config.json").read_text())
assessment = json.loads((lab_dir / "assessment.json").read_text())
registry = json.loads(registry_path.read_text())

errors = []
warnings = []

normalized = str(lab_dir).replace("\\", "/").rstrip("/")
if not re.search(r"facilitator/assets/exams/cks/\d{3}$", normalized):
    errors.append("lab directory should be facilitator/assets/exams/cks/NNN")

if (lab_dir / "assets.tar.gz").exists():
    errors.append("assets.tar.gz must not be committed inside the lab folder")

if config.get("totalMarks") != 100:
    errors.append("config.totalMarks must be 100")

folder_id = lab_dir.name
expected_lab = f"cks-{folder_id}"
lab_id = config.get("lab")
if lab_id != expected_lab:
    errors.append(f"config.lab must be {expected_lab}, got {lab_id}")

expected_answers = f"assets/exams/cks/{folder_id}/answers.md"
if config.get("answers") != expected_answers:
    errors.append(f"config.answers must be {expected_answers}")

if config.get("questions") != "assessment.json":
    errors.append("config.questions must be assessment.json")

worker_nodes = config.get("workerNodes")
if worker_nodes not in (1, 2):
    warnings.append(f"workerNodes is {worker_nodes}; current local CK-X labs should normally use 1 or 2")

questions = assessment.get("questions")
if not isinstance(questions, list) or not questions:
    errors.append("assessment.questions must be a non-empty list")
    questions = []

setup_dir = lab_dir / "scripts" / "setup"
validation_dir = lab_dir / "scripts" / "validation"
seen_q = set()
seen_scripts = set()
total = 0

# Tier 2 / Tier 3 topics that must not appear as real tasks on the
# current k3d backend. If matched, the question text must carry a
# bridge/simulation marker.
unsupported_patterns = [
    r"\bkubeadm\b",
    r"\betcdctl\s+snapshot\s+restore\b",
    r"/etc/kubernetes/manifests",
    r"/etc/kubernetes/pki",
    r"\bapparmor\b",
    r"\bfalco\b",
    r"\bgvisor\b",
    r"\brunsc\b",
    r"--audit-policy-file",
    r"--audit-log-path",
    r"\bEncryptionConfiguration\b",
    r"\bkube-?apiserver\b.*\bflag",
    r"\bkubelet\s+config(uration)?\s+harden",
]

bridge_markers = [
    "simulated",
    "simulation",
    "bridge",
    "runbook",
    "/tmp/exam/",
    "do not execute",
    "do not run",
    "not enforced",
    "not running",
    "write a script",
    "write an executable script",
    "copied manifest",
    "sample certificate",
    "planted",
]

for index, q in enumerate(questions, start=1):
    qid = str(q.get("id", ""))
    if qid != str(index):
        errors.append(f"question id sequence mismatch: expected {index}, got {qid}")
    if qid in seen_q:
        errors.append(f"duplicate question id {qid}")
    seen_q.add(qid)

    if q.get("machineHostname") != "ckad9999":
        errors.append(f"q{qid}: machineHostname must be ckad9999")

    if not q.get("namespace"):
        errors.append(f"q{qid}: namespace is required")

    concepts = q.get("concepts")
    if not isinstance(concepts, list) or not concepts:
        errors.append(f"q{qid}: concepts must be a non-empty array")

    setup = setup_dir / f"q{qid}_setup.sh"
    if not setup.exists():
        errors.append(f"q{qid}: missing setup script {setup.name}")
    elif not os.access(setup, os.X_OK):
        errors.append(f"q{qid}: setup script is not executable: {setup.name}")

    verifications = q.get("verification") or []
    if not (2 <= len(verifications) <= 5):
        errors.append(f"q{qid}: verification count must be 2 to 5, got {len(verifications)}")

    question_text = str(q.get("question", ""))
    lower_question = question_text.lower()
    if any(re.search(pattern, question_text, flags=re.IGNORECASE) for pattern in unsupported_patterns):
        if not any(marker in lower_question for marker in bridge_markers):
            warnings.append(
                f"q{qid}: appears to use a Tier 2/Tier 3 topic (AppArmor/Falco/gVisor/kubeadm/control-plane internals) "
                f"as a real task on the current k3d backend; mark as simulated bridge task or redesign"
            )

    if re.search(r"\bcreate\s+(a\s+)?pod\b", lower_question) and len(verifications) <= 2:
        warnings.append(f"q{qid}: likely toy create-only task; hard CKS mocks should be hardening/troubleshooting heavy")

    for expected_vid, v in enumerate(verifications, start=1):
        vid = str(v.get("id", ""))
        if vid != str(expected_vid):
            warnings.append(f"q{qid}: verification ids should be sequential strings; expected {expected_vid}, got {vid}")
        name = v.get("verificationScriptFile")
        if not name:
            errors.append(f"q{qid}: missing verificationScriptFile")
            continue
        if name in seen_scripts:
            errors.append(f"duplicate validation script reference {name}")
        seen_scripts.add(name)
        p = validation_dir / name
        if not p.exists():
            errors.append(f"q{qid}: missing validation script {name}")
        elif not os.access(p, os.X_OK):
            errors.append(f"q{qid}: validation script is not executable: {name}")
        if str(v.get("expectedOutput")) != "0":
            errors.append(f"q{qid}: expectedOutput must be 0 for {name}")
        try:
            weight = int(v.get("weightage"))
            if weight <= 0:
                errors.append(f"q{qid}: weightage must be positive for {name}")
            total += weight
        except Exception:
            errors.append(f"q{qid}: invalid weightage for {name}")

if total != 100:
    errors.append(f"total validation weightage must be 100, got {total}")

# Orphan check: validation scripts on disk not referenced by any question
on_disk = {p.name for p in validation_dir.glob("*.sh")}
orphans = sorted(on_disk - seen_scripts)
for orphan in orphans:
    errors.append(f"orphan validation script not referenced in assessment.json: {orphan}")

entries = registry.get("labs", []) if isinstance(registry, dict) else []
expected_asset = f"assets/exams/cks/{folder_id}"
matching = [e for e in entries if e.get("id") == expected_lab]
if not matching:
    errors.append(f"registry missing lab id {expected_lab}")
else:
    entry = matching[0]
    if entry.get("assetPath") != expected_asset:
        errors.append(f"registry assetPath must be {expected_asset}")
    if str(entry.get("category", "")) != "CKS":
        warnings.append(f"registry category should be CKS, got {entry.get('category')}")
    duration = entry.get("examDurationInMinutes")
    name = str(entry.get("name", ""))
    if duration == 120 and re.search(r"mock|exam", name, flags=re.IGNORECASE):
        if not (15 <= len(questions) <= 18):
            warnings.append(
                f"full 120-minute CKS mock has {len(questions)} questions; "
                "default is 16, allowed range 15-18 only when explicitly requested"
            )

for warning in warnings:
    print(f"WARNING: {warning}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print(
    f"OK: structural validation passed, registry={registry_path}, "
    f"questions={len(questions)}, weightage={total}, validations={len(seen_scripts)}"
)
PY

pass "CK-X CKS lab validation completed"
