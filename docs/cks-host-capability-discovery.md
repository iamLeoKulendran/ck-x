# CKS Host Capability Discovery — Phase 2A

**Date:** 2026-06-11  
**Branch:** feat/cks-phase1-pipeline  
**Scope:** Read-only discovery. No docker-compose, Dockerfile, or lab content was modified.

---

## 1. Host Facts

| Property | Value |
|---|---|
| WSL2 kernel | `6.6.87.2-microsoft-standard-WSL2` (built Thu Jun 5 18:30:46 UTC 2025) |
| Architecture | x86_64 |
| Docker runtime | Docker Desktop 29.5.2 (Windows-side, connects via `npipe:////./pipe/dockerDesktopLinuxEngine`) |
| Docker socket in WSL2 | **Not mounted** — Docker Desktop WSL integration is not active for this distro; `docker` CLI is only reachable via `/mnt/c/Program Files/Docker/Docker/resources/bin/docker-compose` or the Windows path |
| k3d / kubectl | Not in WSL2 PATH; both run inside the `k8s-api-server` DinD container |
| Compose external port | `127.0.0.1:30081:80` only — localhost-only, no public exposure |
| `k8s-api-server` container | `FROM docker:dind`, `privileged: true` — k3d cluster runs entirely inside this DinD container |
| `jumphost` container | `privileged: true` — tools available: trivy 0.71.0, kube-bench 0.15.6, kubesec 2.14.2, cosign 3.1.1, syft 1.45.1, etcdctl 3.6.12, yq 4.53.3 |

### Kernel config summary (from `/proc/config.gz`)

| Config | Value |
|---|---|
| `CONFIG_SECURITY_APPARMOR` | `y` — compiled in |
| `CONFIG_LSM` | `landlock,lockdown,yama,loadpin,safesetid,integrity,selinux,apparmor,tomoyo` |
| `CONFIG_BPF` / `CONFIG_BPF_SYSCALL` | `y` / `y` |
| `CONFIG_BPF_JIT` / `CONFIG_BPF_JIT_ALWAYS_ON` | `y` / `y` |
| `CONFIG_BPF_LSM` | `y` |
| `CONFIG_BPF_UNPRIV_DEFAULT_OFF` | `y` (privileged eBPF only — correct for Falco) |
| `CONFIG_AUDIT` / `CONFIG_AUDITSYSCALL` | `y` / `y` |
| `CONFIG_SECCOMP` / `CONFIG_SECCOMP_FILTER` | `y` / `y` |

---

## 2. Capability Status

### 2.1 AppArmor

| Check | Result |
|---|---|
| `CONFIG_SECURITY_APPARMOR=y` | **Yes** — compiled into this kernel |
| AppArmor in `CONFIG_LSM` list | **Yes** — `apparmor` appears in the LSM list |
| `/sys/module/apparmor/parameters/enabled` | **`N`** — module loaded but not active |
| AppArmor secfs mounted (`/sys/kernel/security/apparmor/`) | **No** |
| `aa-status` | "apparmor module is loaded" but inactive |

**Status: NEEDS WSL CONFIG**

AppArmor is fully compiled into the kernel and present in the LSM list, but the boot-time LSM activation line does not include `security=apparmor`. It requires a one-time change to `%USERPROFILE%\.wslconfig` on Windows:

```ini
[wsl2]
kernelCommandLine = lsm=lockdown,yama,apparmor,bpf security=apparmor
```

Then: `wsl --shutdown` → restart Docker Desktop.

**Risks:**
- Affects all WSL2 distros on this machine (shared kernel boot args).
- Docker Desktop restart required — existing running exam sessions will be lost.
- If the kernel command line is malformed, WSL2 will not boot until corrected.
- AppArmor namespace behavior inside DinD (`privileged: true`) has not been tested; profile loading inside k3d node containers requires `apparmor_parser` present in the node image.

**Fallback:** Bridge tasks — candidate writes a profile and the `apparmor_parser` load command to `/tmp/exam/qN/`; validation checks file contents. Already established pattern in this repo.

---

### 2.2 Falco / eBPF (Modern eBPF driver)

| Check | Result |
|---|---|
| BTF vmlinux | **Present** — `/sys/kernel/btf/vmlinux` (6,050,732 bytes) |
| `CONFIG_BPF_SYSCALL=y` | **Yes** |
| `CONFIG_BPF_JIT_ALWAYS_ON=y` | **Yes** — JIT always on |
| `CONFIG_BPF_LSM=y` | **Yes** |
| `/proc/sys/net/core/bpf_jit_enable` | `1` — JIT enabled |
| `/proc/sys/kernel/perf_event_paranoid` | `2` — requires privileged for eBPF attach (Falco DaemonSet runs privileged) |
| Unprivileged BPF | Disabled (`CONFIG_BPF_UNPRIV_DEFAULT_OFF=y`) — correct for Falco |

**Status: AVAILABLE — but DinD nesting requires active testing**

The kernel has everything Falco modern eBPF needs (BTF + BPF_SYSCALL + JIT). Falco's modern eBPF driver does **not** need a kernel module — it only needs privileged access to BPF syscalls and BTF.

**Nesting concern (must verify):**  
The topology is: Docker Desktop VM → DinD (`k8s-api-server`, `privileged: true`) → k3d k3s nodes → Falco DaemonSet pods. Falco modern eBPF attaches to the **host kernel's** BPF subsystem. Inside a `privileged` DinD container, BPF programs can be loaded against the real kernel (Docker Desktop's Moby Linux kernel, which shares the WSL2 kernel). Falco should observe syscalls from all processes on that kernel, including k3d workload containers.

However, **Falco container lifecycle events** (new container created, etc.) require access to the container runtime socket. Inside k3d, that means containerd's socket inside the DinD container — not Docker Desktop's socket. This is a more constrained scope but sufficient for CKS labs that demonstrate rule triggering and log analysis.

**What has NOT been tested yet:**
- Whether `bpf()` syscall succeeds inside a privileged pod running inside k3d inside DinD.
- Whether Falco's eBPF program loads without EPERM at that nesting depth.
- Whether container lifecycle metadata reaches Falco at all in this topology.

**Fallback:** Plant a pre-generated Falco alert log file via setup script; candidate analyzes it for suspicious events. This is a legitimate and commonly used bridge pattern.

---

### 2.3 gVisor / RuntimeClass

| Check | Result |
|---|---|
| gVisor `runsc` present | **No** — not installed anywhere in the current image stack |
| containerd shim `containerd-shim-runsc-v1` | **No** |
| RuntimeClass `gvisor` registered | **No** |
| KVM availability | **Unlikely** — WSL2 hypervisor does not expose KVM to guests by default |
| gVisor `systrap` platform | **Should work** — systrap uses ptrace+seccomp, no KVM needed on x86_64 |

**Status: NEEDS CUSTOM NODE IMAGE**

gVisor does not depend on the host kernel flags checked above. It requires:
1. `runsc` binary + `containerd-shim-runsc-v1` installed inside the **k3d node image** (the k3s node containers that run inside DinD).
2. containerd inside those nodes configured with a `runsc` runtime handler.
3. A Kubernetes `RuntimeClass` object pointing at `runsc`.

The current k3d node image is the upstream `rancher/k3s` image; the DinD `kind-cluster/Dockerfile` is the **host** for those containers, not the node image itself. A custom k3d node image must be built (or the entrypoint script must inject `runsc` into nodes post-start).

**systrap platform note:** WSL2 does not expose `/dev/kvm`, so gVisor must use the `systrap` platform (`runsc --platform=systrap`). This is fully supported on x86_64 and does not require KVM. Performance is slower than `ptrace` or `kvm` but functionally complete for CKS labs.

**Fallback:** Bridge task — candidate writes a `RuntimeClass` manifest and the pod spec annotation; validation checks the manifest files under `/tmp/exam/qN/`. No real pod runs in gVisor isolation.

---

### 2.4 Local Registry (`registry:2`)

| Check | Result |
|---|---|
| Port 5000 occupied | **No** — confirmed free |
| Port 5001 occupied | **No** — confirmed free |
| Existing `registry` service in docker-compose | **No** |
| New public ports needed | **No** — registry can be on internal `ckx-network` only |
| k3d registry support | **Yes** — k3d supports `--registry-use` for pre-existing registries and `--registry-create` for inline creation |

**Status: AVAILABLE — lowest risk, ready to implement**

A `registry:2` container added to `docker-compose.yaml` on the internal `ckx-network` with no new external port bindings satisfies the "no new public ports" constraint. The registry is reachable from within the compose network as `registry:5000` and from k3d nodes as `k8s-api-server:5000` (same bridge network) or via k3d's registry mapping.

k3d must be configured to trust the insecure registry; this is done in the k3d cluster creation config (`registries:` block in `k3d-config.yaml`) or via containerd `config_path`. The `env-setup` script handles cluster creation and is where this would be wired.

No new user-facing ports. No changes to nginx. No changes to the exam lifecycle contracts.

---

## 3. Capability Summary Table

| Capability | Status | Blocker | Fallback available |
|---|---|---|---|
| AppArmor | **Needs WSL config** | `security=apparmor` not in boot cmdline; requires Windows `.wslconfig` edit + Docker restart | Yes — bridge tasks |
| Falco / eBPF | **Available — needs DinD test** | No kernel blocker; DinD nesting feasibility unverified | Yes — planted log analysis |
| gVisor RuntimeClass | **Needs custom node image** | `runsc` not in k3d node image; no KVM (systrap needed) | Yes — bridge tasks |
| Local registry | **Available — safe to implement** | None | N/A |

---

## 4. Recommended Phase 2B Implementation Order

**Order: registry → Falco → AppArmor → gVisor**

### Step 1: Local registry (2B-registry)
- Zero kernel risk; no restarts needed; enables supply chain labs immediately.
- Add `registry:2` service to `docker-compose.yaml` (internal network, port 5000, no external binding).
- Update `kind-cluster/scripts/env-setup` to pass `--registry-use` to k3d cluster creation.
- Gate: a k3d pod can pull from `registry:5000` inside the compose network.

### Step 2: Falco eBPF (2B-falco)
- Proof-of-concept: deploy Falco modern eBPF DaemonSet manifest into k3d (inside DinD).
- Write a minimal lab setup that installs Falco and triggers a simple rule (e.g., shell inside a container).
- **Do not commit real Falco lab until this proof passes end-to-end.**
- If eBPF attach fails at DinD depth, document the exact error and promote the bridge (planted logs) to permanent fallback.

### Step 3: AppArmor (2B-apparmor)
- Requires user action (`.wslconfig` edit) — document exact steps clearly.
- After enabling, verify `cat /sys/module/apparmor/parameters/enabled` → `Y` inside the DinD container.
- Build a minimal test: load a profile via `apparmor_parser` inside a k3d node; run a pod with `securityContext.appArmorProfile`.
- If any step fails, bridge tasks are available and well-precedented.

### Step 4: gVisor RuntimeClass (2B-gvisor)
- Build a custom k3d node image that adds `runsc` + shim + containerd config.
- Smallest CKS coverage footprint of the four; defer if time-constrained.
- systrap platform avoids KVM dependency.

---

## 5. Safe Rollback Notes

| Item | Rollback |
|---|---|
| Local registry | Remove the service from `docker-compose.yaml`; stop and remove the container. No cluster state affected. |
| Falco DaemonSet | `kubectl delete daemonset falco -n falco` inside k3d; no host-level changes. |
| AppArmor `.wslconfig` | Remove the `kernelCommandLine` line from `%USERPROFILE%\.wslconfig`; `wsl --shutdown`; restart Docker Desktop. All WSL2 distros return to default LSM stack. |
| gVisor node image | Revert `kind-cluster/Dockerfile` or the custom node image tag; rebuild and restart the `k8s-api-server` service. Existing cluster data lost on rebuild (expected for k3d). |

---

## 6. Do-Not-Proceed Warnings

> **WARNING — AppArmor:** Do not edit `.wslconfig` during an active exam session. The required `wsl --shutdown` will terminate all running WSL2 processes and Docker Desktop containers, destroying the in-progress k3d cluster and any unsaved exam state. Schedule this change when no exam is running and all exam history is committed.

> **WARNING — Falco eBPF testing:** Do not deploy Falco DaemonSet on a cluster running an active exam. Falco's eBPF probe loads syscall intercept programs into the kernel. While generally safe, unexpected behavior in a privileged DinD environment has not been characterized. Run Falco tests on a fresh cluster with no exam data at risk.

> **WARNING — gVisor node image:** Building a custom k3d node image requires rebuilding the `k8s-api-server` service (`docker compose build k8s-api-server`). The existing k3d cluster inside it will be destroyed on next `up`. Ensure all attempt history is preserved in the `attempt-history` volume before rebuilding.

> **WARNING — Nested BPF unverified:** The BPF/BTF availability facts above were read from the WSL2 userspace. Whether BPF programs can be successfully loaded from within a privileged container inside DinD has not been tested on this host. Treat Falco eBPF as "likely works" not "confirmed works" until a proof-of-concept succeeds.
