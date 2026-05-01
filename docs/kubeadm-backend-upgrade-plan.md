# CK-X Optional kubeadm Backend Upgrade Plan

Status: planning document only. No implementation is included here.

Date: 2026-05-02

## 1. Executive Summary

CK-X currently provides a strong local Kubernetes exam simulator using Docker
Compose, a web UI, a remote desktop, a candidate jumphost, Redis active exam
state, persistent attempt history, and a k3d/K3s Kubernetes backend. This is
already useful for many CKA/CKAD/CKS workflows: workloads, scheduling, services,
networking, storage, RBAC, kubectl troubleshooting, and simulated control-plane
tasks.

CK-X needs an optional kubeadm backend because several serious CKA/CKS cluster
administration scenarios require a kubeadm-shaped cluster:

- Real kubeadm upgrade practice.
- Real static pod manifest troubleshooting.
- Real etcd snapshot and restore practice.
- Real kubelet configuration troubleshooting.
- Real certificate inspection and renewal.
- Real node join, drain, cordon, and uncordon workflows.
- Real control-plane component repair.
- More authentic CKS hardening and audit/logging practice.

The current k3d/K3s backend must remain the default until kubeadm mode is fully
stable. k3d starts faster, is easier to run locally, consumes fewer resources,
and already supports existing labs. kubeadm mode should be introduced behind a
cluster driver switch:

```text
CLUSTER_DRIVER=k3d
CLUSTER_DRIVER=kubeadm
```

Default:

```text
CLUSTER_DRIVER=k3d
```

CK-X must continue to be described accurately: it is an independent training
simulator and is not official CNCF, Linux Foundation, PSI, Kubernetes,
Killer.sh, or paid exam content. The kubeadm backend should make local practice
more realistic, but it should not claim to exactly reproduce the official exam
environment.

## 2. Current Architecture Summary

### Current Docker Compose Services

The current root topology is defined in `docker-compose.yaml`.

| Service | Current Responsibility |
| --- | --- |
| `nginx` | Local-only reverse proxy bound to `127.0.0.1:${CKX_HTTP_PORT:-30081}`. It proxies the web UI, facilitator API, and VNC websocket paths. |
| `webapp` | Serves the browser UI from `app/`: landing page, exam page, Previous Attempts, and VNC integration. |
| `facilitator` | Backend API for lab registry, exam lifecycle, assets, scoring, and attempt history. |
| `redis` | Active exam/session state and current result cache. |
| `jumphost` | Candidate SSH host with hostname `ckad9999`, kubectl, helm, aliases, and exam setup/cleanup scripts. |
| `k8s-api-server` | Historical service name for the current Kubernetes host. It builds from `kind-cluster/` but actually runs Docker-in-Docker and creates k3d/K3s clusters. |
| `remote-desktop` | noVNC desktop used by the exam UI. |
| `remote-terminal` | SSH terminal support service used by the web UI stack. |

### Current k3d/K3s Flow

The current Kubernetes backend lives mostly under:

```text
kind-cluster/
kind-cluster/Dockerfile
kind-cluster/entrypoint.sh
kind-cluster/scripts/env-setup
kind-cluster/scripts/env-cleanup
kind-cluster/scripts/k3d-install.sh
kind-cluster/scripts/k3d-node-shell
```

Important current facts:

- `k8s-api-server` is a privileged Docker-in-Docker container.
- `kind-cluster/entrypoint.sh` starts Docker, starts SSH, installs k3d, and
  touches `/ready`.
- `kind-cluster/scripts/env-setup` creates or reuses a k3d cluster using
  `k3d cluster create`.
- `kind-cluster/scripts/env-cleanup` deletes the k3d cluster.
- `kind-cluster/scripts/k3d-node-shell` lets the candidate run:

```bash
ssh controlplane
ssh node01
ssh node02
```

These commands enter nested k3d/K3s node containers, not kubeadm VMs.

### Current Exam Start Flow

The facilitator starts an exam through `facilitator/src/services/jumphostService.js`.

Current flow:

1. Facilitator marks exam status as `PREPARING` in Redis.
2. Facilitator restarts the VNC session.
3. Facilitator SSHes into `jumphost`.
4. It runs:

```bash
prepare-exam-env <workerNodes> <examId>
```

5. `jumphost/scripts/prepare-exam-env.sh` SSHes from the jumphost into
   `candidate@k8s-api-server` and runs:

```bash
env-setup <workerNodes> <clusterName>
```

6. The k3d cluster is created or reused.
7. Kubeconfig is written to the shared `kube-config` volume:

```text
/home/candidate/.kube/kubeconfig
/home/candidate/.kube/config
```

8. The jumphost downloads `assets.tar.gz` from the facilitator.
9. The jumphost extracts setup and validation scripts to:

```text
/tmp/exam-assets
```

10. Setup scripts run:

```bash
for script in /tmp/exam-assets/scripts/setup/q*_setup.sh; do $script; done
```

11. Facilitator marks the exam as `READY`.

### Current Validation Flow

On submission:

1. Facilitator calls `evaluateExamOnJumphost`.
2. Each validation script is executed on the jumphost from:

```text
/tmp/exam-assets/scripts/validation/
```

3. The current backend explicitly sets:

```bash
export KUBECONFIG=/home/candidate/.kube/kubeconfig
```

4. Each script returns `0` for pass and non-zero for fail.
5. Facilitator calculates `totalScore`, `totalPossibleScore`,
   `percentageScore`, and rank.
6. Redis stores the active result.
7. `attemptHistoryService` appends a persistent attempt record.

### Current Attempt History

Attempt history is separate from Redis and stored under the facilitator service:

```text
/usr/src/app/data/attempt-history.json
```

It is backed by the Docker named volume:

```text
attempt-history
```

This volume must not be deleted by kubeadm backend work.

### Current Lab Asset Flow

The active registry is:

```text
facilitator/assets/exams/labs.json
```

Lab assets live under:

```text
facilitator/assets/exams/<category>/<NNN>/
```

The facilitator entrypoint packages each lab `scripts/` directory into
`assets.tar.gz` at container startup. Lab generation and kubeadm backend work
must not require manual `assets.tar.gz` commits.

## 3. Target kubeadm Architecture

### Target Topology

The target kubeadm backend should simulate a 2-node kubeadm cluster:

```text
controlplane
node01
```

`controlplane`:

- Runs systemd.
- Runs containerd.
- Runs kubelet.
- Runs kubeadm.
- Runs kubectl.
- Owns static pod manifests.
- Runs etcd as a kubeadm-managed static pod.
- Runs kube-apiserver, kube-controller-manager, and kube-scheduler as static
  pods.
- Stores control-plane certificates and kubeconfigs in kubeadm-standard paths.

`node01`:

- Runs systemd.
- Runs containerd.
- Runs kubelet.
- Runs kubeadm.
- Runs kubectl for diagnostics.
- Joins the control plane with `kubeadm join`.

### Docker Representation

Recommended first design:

- Add a new isolated directory:

```text
kubeadm-cluster/
```

- Add a Compose overlay or profile for kubeadm mode rather than modifying the
  current k3d service in-place.
- Represent `controlplane` and `node01` as separate privileged containers.
- Use a shared internal Docker network for the kubeadm nodes.
- Keep all node ports internal; do not publish kubeadm node ports to the host.
- Continue to use nginx as the only host-exposed entrypoint.

Recommended service names for the POC:

```text
kubeadm-controlplane
kubeadm-node01
```

Recommended hostnames inside containers:

```text
controlplane
node01
```

### Container Privileges And Runtime Requirements

kubeadm-in-container is more demanding than k3d. Each kubeadm node container
will likely require:

- `privileged: true`
- writable cgroup mounts
- systemd as PID 1
- `/sys/fs/cgroup` mounted appropriately
- `containerd` running inside the node container
- `kubelet` managed by systemd
- kernel modules and sysctls required by Kubernetes networking
- swap disabled or kubelet configured to reject/handle swap consistently

The implementation should prefer a systemd-capable base image. Ubuntu 24.04 or
Debian 12 are practical candidates for the POC because package availability,
systemd behavior, and Kubernetes installation docs are straightforward. The
existing `jumphost` already uses Ubuntu 22.04, but kubeadm nodes should be
isolated in a new image rather than overloading the jumphost.

### Candidate SSH Model

The candidate workflow should remain familiar:

```bash
ssh ckad9999
kubectl get nodes
ssh controlplane
ssh node01
```

For kubeadm mode:

- `ssh controlplane` should SSH from the jumphost directly to the
  `kubeadm-controlplane` service.
- `ssh node01` should SSH from the jumphost directly to the `kubeadm-node01`
  service.
- The current `jumphost/ssh_config` should become driver-aware.
- k3d mode should keep using `k3d-node-shell`.
- kubeadm mode should use normal SSH to real node containers.

### Kubeconfig Sharing

The existing `kube-config` Docker volume should remain the common path for
candidate kubeconfig:

```text
/home/candidate/.kube/kubeconfig
/home/candidate/.kube/config
```

For kubeadm mode:

- After `kubeadm init`, copy `/etc/kubernetes/admin.conf` from `controlplane`
  into the shared kubeconfig volume.
- Rewrite the API server endpoint to use the internal service DNS name or a
  stable Compose network alias reachable from the jumphost.
- Ensure ownership and permissions are compatible with candidate use.
- Keep both `config` and `kubeconfig` paths populated for compatibility with
  existing facilitator validation flow.

## 4. Cluster Driver Design

### Driver Values

Supported cluster driver values:

```text
CLUSTER_DRIVER=k3d
CLUSTER_DRIVER=kubeadm
```

Default:

```text
CLUSTER_DRIVER=k3d
```

### Boundary Principle

Do not scatter `if kubeadm` logic across the UI. Keep driver selection in the
environment preparation and node-access layer.

Stable public behavior should remain:

- Same landing page.
- Same lab registry.
- Same exam start endpoint.
- Same exam status endpoint.
- Same evaluation endpoint.
- Same Previous Attempts endpoint.
- Same attempt-history file.
- Same nginx localhost-only entrypoint.

### Dispatch Design

Recommended dispatch point:

```text
jumphost/scripts/prepare-exam-env.sh
jumphost/scripts/cleanup-exam-env.sh
```

These scripts already sit between the facilitator and the cluster backend. They
should dispatch based on `CLUSTER_DRIVER`.

Future shape:

```bash
case "${CLUSTER_DRIVER:-k3d}" in
  k3d)
    ssh candidate@k8s-api-server "env-setup-k3d ..."
    ;;
  kubeadm)
    ssh candidate@kubeadm-controlplane "env-setup-kubeadm ..."
    ;;
  *)
    echo "Unsupported CLUSTER_DRIVER"
    exit 1
    ;;
esac
```

Do not rename existing APIs. The facilitator should continue to run:

```bash
prepare-exam-env <workerNodes> <examId>
```

If facilitator awareness is needed later, add optional logging metadata only:

```text
clusterDriver: k3d | kubeadm
```

It should not change API shape unless a later UI feature needs to display the
driver.

### Compose Boundary

Recommended Compose design:

- Keep `docker-compose.yaml` stable for k3d default mode.
- Add `docker-compose.kubeadm.yaml` or a Compose profile for kubeadm services.
- Use `profiles: ["kubeadm"]` for kubeadm node services if practical.
- Keep nginx unchanged.
- Keep webapp/facilitator/redis/remote-desktop unchanged for the first POC.

Example future invocation:

```bash
CLUSTER_DRIVER=kubeadm docker compose -f docker-compose.yaml -f docker-compose.kubeadm.yaml --profile kubeadm up -d --build
```

### Rollback Strategy

Rollback must be simple:

```bash
CLUSTER_DRIVER=k3d docker compose up -d
```

If kubeadm services fail, the user should be able to:

- Stop kubeadm-specific services.
- Keep Redis and attempt-history intact.
- Return to k3d mode.
- Run existing labs unchanged.

No rollback path may require:

```bash
docker compose down -v
```

## 5. Kubernetes Version Strategy

### Official Version Availability Verification

Verified from official Kubernetes sources on 2026-05-02:

- The Kubernetes releases page lists maintained release branches for the latest
  three minor versions and currently includes `1.36`, `1.35`, and `1.34`.
- Kubernetes `1.36.0` is listed as released on 2026-04-22.
- Kubernetes `1.35.3` is listed as the latest `1.35` patch release, released on
  2026-03-19.
- The official v1.36 release blog confirms Kubernetes v1.36 was released on
  2026-04-22.

Official references:

- https://kubernetes.io/releases/
- https://kubernetes.io/blog/2026/04/22/kubernetes-v1-36-release/
- https://v1-35.docs.kubernetes.io/releases/1.35/
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- https://kubernetes.io/docs/setup/production-environment/container-runtimes/
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/

### Initial And Upgrade Target

Initial kubeadm cluster:

```text
v1.35.3
```

Upgrade practice target:

```text
v1.36.0 initially, then the latest supported v1.36 patch once available
```

Use patch variables rather than hardcoding only minor versions:

```text
KUBEADM_INITIAL_VERSION=v1.35.3
KUBEADM_UPGRADE_VERSION=v1.36.0
```

When newer v1.36 patches become available, update:

```text
KUBEADM_UPGRADE_VERSION=v1.36.x
```

### Package Pinning

Pin all Kubernetes binaries/packages explicitly:

- `kubeadm`
- `kubelet`
- `kubectl`
- `crictl`
- CNI plugins
- containerd version

Do not use floating `stable.txt` during exam startup. Floating versions make
labs non-reproducible.

Recommended:

- Resolve exact URLs at image build time.
- Store versions in one file:

```text
kubeadm-cluster/versions.env
```

Example:

```text
KUBEADM_INITIAL_VERSION=v1.35.3
KUBEADM_UPGRADE_VERSION=v1.36.0
CRICTL_VERSION=v1.35.0
RUNC_VERSION=<pinned>
CONTAINERD_VERSION=<pinned>
CNI_PLUGINS_VERSION=<pinned>
```

### Image Pre-Pulling

Pre-pull Kubernetes control-plane images during setup or image build:

```bash
kubeadm config images pull --kubernetes-version "${KUBEADM_INITIAL_VERSION}"
```

For upgrade practice, also cache upgrade target images:

```bash
kubeadm config images pull --kubernetes-version "${KUBEADM_UPGRADE_VERSION}"
```

If image build-time pre-pull is not possible because containerd is not running
inside the image build, do it in an early runtime cache step and persist
containerd data in a kubeadm-specific volume.

### kubeadm Upgrade Constraints

The target real upgrade path should follow kubeadm-supported minor upgrade
behavior:

```text
v1.35.x -> v1.36.x
```

The plan must support:

- `kubeadm upgrade plan`
- `kubeadm upgrade apply`
- kubelet upgrade on controlplane
- kubelet upgrade on node01
- `kubectl drain`
- `kubectl uncordon`
- version skew checks

### Version Skew Considerations

The implementation must respect Kubernetes version skew rules:

- kubeadm must be compatible with the target upgrade operation.
- kubelet must not be newer than the API server.
- kubectl can be within the supported skew range, but for training clarity it
  should usually match the control-plane version.
- During upgrade labs, temporary skew is expected and should be validated.

### Future Version Updates

Future version updates should be done by editing a single version file and
running a validation matrix:

- k3d regression.
- kubeadm fresh cluster start.
- kubeadm upgrade scenario.
- one setup script.
- one validation script.
- Previous Attempts check.

## 6. Resource Optimization Plan

### Minimum Local Resources

Minimum practical Docker Desktop / WSL2 allocation for kubeadm mode:

```text
CPU: 4 cores
Memory: 8 GB
Disk: 30 GB free
```

Recommended:

```text
CPU: 6 to 8 cores
Memory: 12 to 16 GB
Disk: 50 GB free
```

k3d mode should remain available for lower-resource systems.

### Image Caching Strategy

Build reusable images:

```text
ck-x-kubeadm-node-base
ck-x-kubeadm-controlplane
ck-x-kubeadm-worker
```

Cache at image build time where possible:

- systemd dependencies.
- containerd.
- kubeadm.
- kubelet.
- kubectl.
- crictl.
- CNI plugin binaries.
- common debugging tools.

Avoid downloading Kubernetes packages during every exam start.

### Package Caching Strategy

Use pinned package repositories and versions.

For Debian/Ubuntu-based images:

- Add Kubernetes package repositories during image build.
- Install exact package versions if the package repo exposes v1.35/v1.36
  packages.
- Alternatively download exact binaries from `dl.k8s.io` and install systemd
  unit files from the official Kubernetes release tooling templates.

### Runtime Download Avoidance

At exam start, the kubeadm backend should avoid:

- apt updates.
- package installs.
- downloading kubeadm/kubelet/kubectl.
- downloading CNI binaries.
- downloading common control-plane images if already cached.

Acceptable runtime actions:

- Reset per-attempt kubeadm state.
- Start containerd and kubelet.
- Run `kubeadm init`.
- Run `kubeadm join`.
- Apply CNI manifest from a local file.

### Per-Attempt Cleanup

Cleanup must target only kubeadm cluster state:

- kubeadm reset.
- remove kubelet state.
- remove CNI state.
- remove local kubeconfig copies for the active attempt.
- clear per-attempt temp files.
- optionally clear kubeadm-specific data volumes if explicitly part of reset.

Cleanup must not delete:

- `attempt-history`.
- `facilitator/assets/exams`.
- generated labs.
- Docker volumes unrelated to kubeadm cluster state.
- host Docker images globally.

Avoid global cleanup commands:

```bash
docker system prune -a --volumes
docker volume prune
docker image prune -a
```

### Startup Time Optimization

Target startup goals:

- k3d mode: unchanged.
- kubeadm first cold start: acceptable if slower.
- kubeadm warm start: under 5 minutes if possible.

Optimization ideas:

- Cache images.
- Keep CNI manifest local.
- Use two nodes only by default.
- Keep addon set minimal.
- Do not install metrics-server unless labs require it.
- Avoid expensive desktop restarts unrelated to cluster init.

### Disk Usage Considerations

kubeadm mode will use more disk than k3d mode. Track:

- containerd content store.
- Kubernetes images.
- etcd data.
- logs.
- package caches.
- old images after upgrade labs.

Add a future safe cleanup command specific to kubeadm backend only, for example:

```bash
scripts/cleanup-kubeadm-cache.sh
```

This script must clearly warn and must never remove attempt history.

## 7. Implementation Phases

### Phase 1: Repository Audit And Design Finalization

- Freeze the current stable k3d behavior as baseline.
- Document current service contracts and exam flow.
- Confirm all current validation commands pass.
- Identify all places that assume `k8s-api-server`, k3d, or K3s paths.
- Decide final Compose strategy: overlay file or profile.
- Decide base OS image for kubeadm nodes.

Deliverable:

```text
docs/kubeadm-backend-upgrade-plan.md
```

### Phase 2: Isolated kubeadm Docker Proof Of Concept

- Create an isolated POC directory, not wired into the main exam flow.
- Prove one control-plane and one worker container can run kubeadm.
- Prove containerd + kubelet + systemd inside containers are stable.
- Prove `kubectl get nodes` works from outside the nodes.

Deliverable:

```text
kubeadm-cluster/poc/
```

### Phase 3: Build controlplane Image

- Create a systemd-capable kubeadm control-plane image.
- Install pinned containerd, kubelet, kubeadm, kubectl, crictl, CNI binaries.
- Configure containerd systemd cgroup driver.
- Add SSH server.
- Add candidate/root access consistent with internal-only local use.
- Add scripts for init/reset/status.

### Phase 4: Build Worker Node Image

- Reuse base image.
- Install same pinned runtime and Kubernetes components.
- Configure systemd, containerd, kubelet.
- Add SSH server.
- Add scripts for join/reset/status.

### Phase 5: kubeadm init/join Automation

- Generate kubeadm config files.
- Run `kubeadm init` on `controlplane`.
- Generate join token.
- Run `kubeadm join` on `node01`.
- Wait for nodes to appear.
- Handle retry and cleanup on failure.

### Phase 6: CNI Installation

- Choose a CNI plugin and pin version.
- Store CNI manifest locally in repo or image.
- Apply CNI after `kubeadm init`.
- Wait for CoreDNS and CNI pods to become Running.

Recommended first CNI:

```text
Calico or Flannel
```

First POC recommendation:

```text
Flannel for simplicity and lower resource use
```

Later CKS/network-policy recommendation:

```text
Calico if NetworkPolicy fidelity is required
```

### Phase 7: kubeconfig Sharing With jumphost

- Copy `controlplane:/etc/kubernetes/admin.conf` to the `kube-config` volume.
- Write both:

```text
/home/candidate/.kube/config
/home/candidate/.kube/kubeconfig
```

- Rewrite API endpoint to a Compose-reachable internal hostname.
- Set ownership and permissions for candidate.
- Validate from `jumphost`:

```bash
kubectl get nodes
```

### Phase 8: SSH Integration For controlplane And node01

- Update `jumphost/ssh_config` to support driver-aware host entries.
- In kubeadm mode:

```text
Host controlplane -> kubeadm-controlplane
Host node01 -> kubeadm-node01
```

- In k3d mode, preserve current `RemoteCommand /usr/local/bin/k3d-node-shell`.
- Ensure `ssh controlplane` and `ssh node01` work from VNC terminal.

### Phase 9: Integrate With Facilitator Exam Start

- Keep facilitator command unchanged:

```bash
prepare-exam-env <workerNodes> <examId>
```

- Add environment variable:

```text
CLUSTER_DRIVER=${CLUSTER_DRIVER:-k3d}
```

- Have `prepare-exam-env` dispatch to kubeadm or k3d backend.
- Preserve Redis status names.
- Preserve VNC restart behavior.
- Preserve lab asset download.

### Phase 10: Integrate Setup/Validation Scripts

- Existing setup and validation scripts should continue using `kubectl`.
- For kubeadm-specific labs, add clear guidance for scripts that SSH into
  `controlplane` or `node01`.
- Ensure setup and validation scripts can distinguish driver-specific paths only
  when necessary.
- Avoid breaking existing labs that assume k3d/K3s.

### Phase 11: Add Real Cluster Maintenance Practice Support

Create new kubeadm-specific CKA labs after backend stability:

- kubeadm upgrade v1.35.x to v1.36.x.
- etcd snapshot and restore.
- static pod manifest repair.
- kubelet config repair.
- certificate expiration and renewal.
- node drain/cordon/uncordon.
- worker node join troubleshooting.
- control-plane component log troubleshooting.
- CKS audit/logging and hardening scenarios.

### Phase 12: Add Quality Gates And Regression Testing

Add automated or semi-automated checks:

- k3d mode smoke test.
- kubeadm mode smoke test.
- kubeadm upgrade test.
- SSH checks.
- kubeconfig checks.
- setup/validation script checks.
- Previous Attempts check.
- no-public-port check.
- no-history-delete check.

### Phase 13: Documentation And User Migration Guide

Add user docs:

- How to run k3d mode.
- How to run kubeadm mode.
- Resource requirements.
- Known limitations.
- How to reset kubeadm cluster state safely.
- How to return to k3d mode.
- How to create kubeadm-specific labs.

## 8. File-Level Change Plan

### `docker-compose.yaml`

Modify minimally:

- Add `CLUSTER_DRIVER=${CLUSTER_DRIVER:-k3d}` to `jumphost`.
- Add `CLUSTER_DRIVER=${CLUSTER_DRIVER:-k3d}` to `facilitator` only if logging
  or metadata needs it.
- Do not remove the existing `k8s-api-server` service.
- Do not change nginx public binding.

### `docker-compose.kubeadm.yaml` or Compose Profile

Create:

```text
docker-compose.kubeadm.yaml
```

Expected content:

- `kubeadm-controlplane` service.
- `kubeadm-node01` service.
- kubeadm-specific volumes.
- internal network aliases.
- no public ports.
- healthchecks for SSH/systemd/kubelet readiness.

### `kubeadm-cluster/`

Create:

```text
kubeadm-cluster/
|-- Dockerfile.base
|-- Dockerfile.controlplane
|-- Dockerfile.worker
|-- versions.env
|-- scripts/
|   |-- kubeadm-init.sh
|   |-- kubeadm-join.sh
|   |-- kubeadm-reset.sh
|   |-- kubeadm-status.sh
|   |-- write-kubeconfig.sh
|   `-- wait-ready.sh
|-- config/
|   |-- kubeadm-init.yaml
|   |-- kubeadm-join.yaml.template
|   |-- containerd-config.toml
|   |-- kubelet-config.yaml
|   `-- cni/
|       `-- flannel.yaml
`-- README.md
```

### `kind-cluster/`

Preserve as the k3d backend.

Optional future cleanup:

- Rename comments from "KIND" to "k3d/K3s" for clarity.
- Rename `env-setup` to `env-setup-k3d` only if wrapper compatibility is
  preserved.

Do not break current `env-setup` during early kubeadm work.

### `jumphost/ssh_config`

Modify to support both drivers.

Preferred implementation:

- Generate SSH config at container startup from `CLUSTER_DRIVER`.
- Or keep a single config with host aliases that resolve depending on Compose
  services.

k3d mode:

```text
Host controlplane
  HostName k8s-api-server
  RemoteCommand /usr/local/bin/k3d-node-shell k3d-cluster-server-0 controlplane
```

kubeadm mode:

```text
Host controlplane
  HostName kubeadm-controlplane
  User candidate
```

### `jumphost/scripts/prepare-exam-env.sh`

Modify:

- Read `CLUSTER_DRIVER`.
- Dispatch to k3d or kubeadm setup.
- Preserve current lab asset download and setup script execution.
- Keep kubeconfig export compatible.

### `jumphost/scripts/cleanup-exam-env.sh`

Modify:

- Read `CLUSTER_DRIVER`.
- Dispatch to driver-specific cleanup.
- Remove only per-exam temporary files and cluster state.
- Remove current dangerous global prune behavior in a later safety fix or guard
  it behind an explicit opt-in.
- Never remove attempt history.

### `facilitator/src/services/jumphostService.js`

Minimal change only if needed:

- Keep calling `prepare-exam-env`.
- Optionally log `CLUSTER_DRIVER`.
- Optionally store cluster driver in exam metadata for debugging.
- Do not change API responses in the first kubeadm POC.

### `facilitator/src/services/attemptHistoryService.js`

No required change.

Optional later:

- Include `clusterDriver` in attempt records if useful for comparing k3d vs
  kubeadm lab runs.

### Shared `kube-config` Volume

Keep existing volume:

```yaml
kube-config:/home/candidate/.kube
```

Ensure kubeadm mode writes both:

```text
config
kubeconfig
```

### `docs/`

Create or update:

- `docs/kubeadm-backend-upgrade-plan.md`
- `docs/kubeadm-backend-user-guide.md` after implementation
- `docs/cka-lab-generation-guide.md` with kubeadm-specific lab guidance after
  kubeadm mode is stable

### Validation Scripts

Existing lab validation scripts should not need changes unless they assume K3s
paths.

Future kubeadm-specific labs should validate real kubeadm paths:

```text
/etc/kubernetes/manifests
/etc/kubernetes/pki
/var/lib/etcd
/var/lib/kubelet/config.yaml
```

## 9. kubeadm Node Design

### controlplane Container Responsibilities

The controlplane container should:

- Run systemd as PID 1.
- Start containerd.
- Start kubelet.
- Run kubeadm init.
- Host static pod manifests.
- Host etcd data.
- Host Kubernetes certificates.
- Host admin kubeconfig.
- Run SSH server for `ssh controlplane`.
- Provide diagnostic tools.

Required paths:

```text
/etc/kubernetes/admin.conf
/etc/kubernetes/kubelet.conf
/etc/kubernetes/controller-manager.conf
/etc/kubernetes/scheduler.conf
/etc/kubernetes/manifests/
/etc/kubernetes/pki/
/etc/kubernetes/pki/etcd/
/var/lib/etcd/
/var/lib/kubelet/
/etc/containerd/config.toml
```

### node01 Container Responsibilities

The node01 container should:

- Run systemd as PID 1.
- Start containerd.
- Start kubelet.
- Run kubeadm join.
- Run SSH server for `ssh node01`.
- Support drain/cordon/uncordon workflows.
- Provide kubelet/containerd troubleshooting paths.

Required paths:

```text
/var/lib/kubelet/
/etc/kubernetes/kubelet.conf
/etc/containerd/config.toml
```

### systemd/cgroup Approach

Use a systemd-based container pattern:

- `privileged: true`
- cgroup filesystem mounted correctly.
- systemd cgroup driver for containerd and kubelet.
- kubeadm default cgroup driver behavior should align with official docs:
  kubeadm defaults to systemd cgroup driver for modern Kubernetes.

The official Kubernetes docs state that matching kubelet and runtime cgroup
drivers is critical, and systemd is recommended when systemd is the init system.

### containerd Configuration

containerd should:

- Use systemd cgroups.
- Listen on:

```text
unix:///run/containerd/containerd.sock
```

- Be the only CRI endpoint visible to kubeadm.
- Use a stable pause image compatible with the chosen Kubernetes version.

### kubelet Configuration

kubelet should:

- Run as a systemd service.
- Use containerd CRI endpoint.
- Use systemd cgroup driver.
- Use kubeadm-managed config under:

```text
/var/lib/kubelet/config.yaml
```

### kubeadm Config Files

Use explicit kubeadm config files rather than long command lines.

Control-plane config should define:

- Kubernetes version.
- node registration name `controlplane`.
- CRI socket.
- pod subnet compatible with chosen CNI.
- API server cert SANs for internal service names.
- kubelet cgroup driver if needed.

Worker join config should define:

- node registration name `node01`.
- CRI socket.
- discovery token or file.

### Static Pod Manifest Location

kubeadm standard path:

```text
/etc/kubernetes/manifests/
```

This enables real tasks involving:

- kube-apiserver manifest repair.
- kube-controller-manager manifest repair.
- kube-scheduler manifest repair.
- etcd manifest repair.

### etcd Data Location

kubeadm standard path:

```text
/var/lib/etcd/
```

This enables real etcd snapshot and restore practice.

### Certificate Locations

kubeadm standard paths:

```text
/etc/kubernetes/pki/
/etc/kubernetes/pki/etcd/
```

This enables real certificate inspection and renewal practice.

### Kubeconfig Files

kubeadm standard paths:

```text
/etc/kubernetes/admin.conf
/etc/kubernetes/kubelet.conf
/etc/kubernetes/controller-manager.conf
/etc/kubernetes/scheduler.conf
```

Candidate shared paths:

```text
/home/candidate/.kube/config
/home/candidate/.kube/kubeconfig
```

### CNI Plugin Choice And Rationale

First POC recommendation:

```text
Flannel
```

Rationale:

- Lower complexity.
- Fast startup.
- Good enough for initial kubeadm cluster lifecycle validation.
- Lower resource usage on Windows Docker Desktop / WSL2.

Future CKS recommendation:

```text
Calico
```

Rationale:

- Better NetworkPolicy fidelity.
- More useful for CKS hardening and policy labs.

Decision:

- Start with Flannel in Phase 2.
- Add Calico as an optional later profile after kubeadm cluster lifecycle is
  stable.

## 10. Exam Scenario Enablement

After kubeadm backend is stable, CK-X can support real versions of these
scenarios.

### kubeadm Upgrade

Possible real tasks:

- Run `kubeadm upgrade plan`.
- Upgrade control plane from v1.35.x to v1.36.x.
- Upgrade kubelet and kubectl.
- Drain and upgrade worker node.
- Validate version skew and node readiness.

### etcd Backup/Restore

Possible real tasks:

- Use `ETCDCTL_API=3`.
- Inspect etcd certificates.
- Create snapshot from the real kubeadm etcd pod.
- Restore snapshot.
- Point etcd static pod manifest to restored data.
- Recover API server readiness.

### Static Pods

Possible real tasks:

- Fix broken kube-apiserver manifest flags.
- Restore kube-scheduler manifest.
- Repair etcd manifest volume mounts.
- Detect crash-looping control-plane components.

### kubelet Troubleshooting

Possible real tasks:

- Fix `/var/lib/kubelet/config.yaml`.
- Fix kubelet systemd drop-ins.
- Restart kubelet.
- Investigate kubelet logs.
- Repair node readiness.

### Certificates

Possible real tasks:

- Inspect certificate expiration with `kubeadm certs check-expiration`.
- Renew certificates.
- Rebuild kubeconfigs.
- Fix broken cert paths in static pod manifests.

### Node Maintenance

Possible real tasks:

- Drain node.
- Cordon/uncordon node.
- Safely move workloads.
- Repair node join.
- Re-run `kubeadm join`.

### Cluster Component Logs

Possible real tasks:

- Use `journalctl -u kubelet`.
- Use `crictl ps`.
- Use `crictl logs`.
- Inspect static pod container logs.

### CKS Hardening Scenarios

Possible future tasks:

- Audit policy/logging configuration.
- API server admission settings.
- Pod Security Admission.
- RBAC least privilege.
- NetworkPolicy hardening.
- kubelet API hardening.
- certificate and kubeconfig hygiene.

## 11. Safety And Data Preservation

Hard safety rules:

- Do not delete `attempt-history`.
- Do not run `docker compose down -v` in normal flows.
- Do not expose kubeadm node ports publicly.
- Keep nginx as the only host-published entrypoint.
- Keep nginx bound to localhost.
- Do not run global Docker prune commands in exam cleanup.
- Isolate kubeadm volumes from existing k3d state.
- Preserve all existing labs.
- Preserve current UI, APIs, and history behavior.

Recommended kubeadm-specific volumes:

```text
kubeadm-controlplane-data
kubeadm-node01-data
kubeadm-containerd-cache
```

These must be separate from:

```text
attempt-history
kube-config
```

Kubeadm cleanup may reset kubeadm-specific data only.

## 12. Validation And Test Plan

### Compose Validation

Current k3d mode:

```bash
docker compose config
docker compose up -d --build
docker compose ps
```

kubeadm mode:

```bash
CLUSTER_DRIVER=kubeadm docker compose -f docker-compose.yaml -f docker-compose.kubeadm.yaml --profile kubeadm config
CLUSTER_DRIVER=kubeadm docker compose -f docker-compose.yaml -f docker-compose.kubeadm.yaml --profile kubeadm up -d --build
CLUSTER_DRIVER=kubeadm docker compose -f docker-compose.yaml -f docker-compose.kubeadm.yaml --profile kubeadm ps
```

### Container Checks

```bash
docker compose ps
docker compose logs --tail=100 facilitator
docker compose logs --tail=100 nginx
docker compose logs --tail=100 jumphost
docker compose logs --tail=100 kubeadm-controlplane
docker compose logs --tail=100 kubeadm-node01
```

### Candidate SSH Checks

```bash
docker compose exec -T jumphost bash -lc "ssh -o StrictHostKeyChecking=no controlplane hostname"
docker compose exec -T jumphost bash -lc "ssh -o StrictHostKeyChecking=no node01 hostname"
```

From VNC terminal:

```bash
ssh ckad9999
ssh controlplane
ssh node01
```

### Kubernetes Checks From Candidate Shell

```bash
kubectl version
kubectl get nodes -o wide
kubectl get pods -A
kubectl -n kube-system get pods
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

### kubeadm Checks

On `controlplane`:

```bash
kubeadm version
kubeadm upgrade plan
ls -l /etc/kubernetes/manifests
ls -l /etc/kubernetes/pki
ls -l /etc/kubernetes/pki/etcd
```

On `node01`:

```bash
kubeadm version
test -f /etc/kubernetes/kubelet.conf
```

### kubelet Checks

On each node:

```bash
systemctl status kubelet --no-pager
journalctl -u kubelet --no-pager -n 100
test -f /var/lib/kubelet/config.yaml
```

### containerd Checks

On each node:

```bash
systemctl status containerd --no-pager
crictl info
crictl ps
```

### CoreDNS Readiness

```bash
kubectl -n kube-system rollout status deployment/coredns --timeout=180s
kubectl -n kube-system get pods -l k8s-app=kube-dns
```

### CNI Health

For Flannel:

```bash
kubectl -n kube-flannel get pods -o wide
kubectl get nodes
```

For Calico later:

```bash
kubectl -n calico-system get pods -o wide
kubectl get networkpolicy -A
```

### Sample Lab Setup Script

After exam assets are downloaded:

```bash
bash -n /tmp/exam-assets/scripts/setup/q1_setup.sh
/tmp/exam-assets/scripts/setup/q1_setup.sh
```

### Sample Validation Script

```bash
bash -n /tmp/exam-assets/scripts/validation/q1_s1_validate_*.sh
/tmp/exam-assets/scripts/validation/q1_s1_validate_*.sh
echo $?
```

### Previous Attempts Check

```bash
curl http://127.0.0.1:30081/facilitator/api/v1/exams/attempts
```

Expected:

- HTTP 200.
- `success: true`.
- `data.version: 1`.
- `data.attempts` is an array.

### k3d Regression Check

After kubeadm work, k3d mode must still pass:

```bash
CLUSTER_DRIVER=k3d docker compose up -d --build
docker compose ps
curl http://127.0.0.1:30081
curl http://127.0.0.1:30081/facilitator/api/v1/assements/
docker compose exec -T jumphost bash -lc "kubectl get nodes"
docker compose exec -T jumphost bash -lc "printf 'k get no\t\nexit\n' | script -q -e -c 'ssh controlplane' /tmp/k3d-tab-test.log"
```

### No Public Port Check

```bash
docker compose config
docker compose ps
```

Expected:

- Only nginx publishes a host port.
- Published nginx bind remains `127.0.0.1:30081` unless explicitly overridden
  by `CKX_HTTP_PORT`.

## 13. Risks And Mitigations

### Docker Desktop Resource Limits

Risk:

- kubeadm mode may exceed laptop CPU or memory limits.

Mitigation:

- Keep k3d default.
- Use 2-node kubeadm only.
- Document minimum and recommended WSL2 memory.
- Pre-cache images.
- Keep addons minimal.

### Privileged Containers

Risk:

- kubeadm nodes require privileged containers, increasing local security risk.

Mitigation:

- Keep localhost-only nginx.
- Do not expose node SSH ports publicly.
- Document local-only use.
- Keep kubeadm mode opt-in.

### systemd In Containers

Risk:

- systemd can behave differently in Docker Desktop / WSL2 than on Linux VMs.

Mitigation:

- Use a proven systemd container pattern.
- Keep POC isolated.
- Validate on Windows Docker Desktop / WSL2.
- Avoid wiring into exam flow until stable.

### cgroup v2 Issues

Risk:

- kubelet/containerd cgroup mismatch can make nodes NotReady.

Mitigation:

- Use systemd cgroup driver for containerd and kubelet.
- Follow official Kubernetes cgroup driver guidance.
- Add explicit validation for `/var/lib/kubelet/config.yaml` and
  containerd config.

### Slow Startup

Risk:

- kubeadm cluster startup may take too long for a smooth exam experience.

Mitigation:

- Preinstall packages.
- Pre-pull images.
- Store CNI manifest locally.
- Avoid downloading during exam start.
- Provide warm-up time for kubeadm labs.

### CNI Instability

Risk:

- CNI may fail under nested container networking.

Mitigation:

- Start with Flannel for the POC.
- Add Calico later only after core lifecycle is stable.
- Add CNI readiness checks.

### kubeadm Version/Package Availability

Risk:

- package repositories or exact versions can move.

Mitigation:

- Pin versions.
- Prefer official `dl.k8s.io` binaries or official package repositories.
- Store version values centrally.
- Re-verify availability before each minor version upgrade.

### Windows/WSL2 Filesystem Performance

Risk:

- bind mounts from Windows paths can slow kubeadm state writes.

Mitigation:

- Use Docker named volumes for kubeadm node state.
- Avoid writing etcd data to Windows bind mounts.
- Keep source code bind mounts out of node data paths.

### Accidental History Deletion

Risk:

- cleanup scripts could delete Docker volumes.

Mitigation:

- Remove global prune commands from normal cleanup.
- Never target `attempt-history`.
- Add tests confirming history survives `docker compose down/up`.

### Breaking Existing k3d Labs

Risk:

- Driver dispatch could alter current lab behavior.

Mitigation:

- Default remains k3d.
- Keep facilitator APIs stable.
- Keep existing `env-setup` path until wrapper is tested.
- Add k3d regression checks before every kubeadm merge.

## 14. Acceptance Criteria

The kubeadm backend is not stable until all of these are true:

- `CLUSTER_DRIVER=k3d` works unchanged.
- Existing k3d labs start, run setup scripts, run validation scripts, and record
  attempts.
- `CLUSTER_DRIVER=kubeadm` starts a 2-node cluster.
- `kubectl get nodes` works from `ckad9999`.
- `kubectl get pods -A` works from `ckad9999`.
- `ssh controlplane` works.
- `ssh node01` works.
- `kubeadm version` works on both nodes.
- Controlplane has real kubeadm paths:
  - `/etc/kubernetes/manifests`
  - `/etc/kubernetes/pki`
  - `/var/lib/etcd`
- kubeadm upgrade practice from v1.35.x to v1.36.x works.
- Static pod manifest troubleshooting works.
- etcd snapshot/restore practice works.
- kubelet troubleshooting works.
- setup scripts run in kubeadm mode.
- validation scripts run in kubeadm mode.
- Previous Attempts records results.
- `docker compose down` followed by `docker compose up -d` preserves attempt
  history.
- No new public ports are added.
- nginx remains the only host-published entrypoint.
- kubeadm cleanup does not delete k3d state or attempt history.

## 15. Recommended First Implementation Task

Smallest safe first coding task:

Create an isolated kubeadm proof-of-concept that does not modify or replace the
existing k3d backend.

Recommended first task scope:

- Add:

```text
kubeadm-cluster/poc/
docker-compose.kubeadm-poc.yaml
```

- Build one systemd-capable kubeadm node image.
- Start only a single `kubeadm-controlplane` container.
- Install pinned versions:
  - Kubernetes v1.35.3 components.
  - containerd.
  - crictl.
  - CNI binaries.
- Start systemd and containerd.
- Validate:

```bash
docker compose -f docker-compose.kubeadm-poc.yaml config
docker compose -f docker-compose.kubeadm-poc.yaml up -d --build
docker compose -f docker-compose.kubeadm-poc.yaml exec kubeadm-controlplane systemctl status containerd --no-pager
docker compose -f docker-compose.kubeadm-poc.yaml exec kubeadm-controlplane kubeadm version
docker compose -f docker-compose.kubeadm-poc.yaml exec kubeadm-controlplane kubelet --version
docker compose -f docker-compose.kubeadm-poc.yaml exec kubeadm-controlplane kubectl version --client=true
```

Do not integrate with facilitator yet.

Do not modify existing k3d scripts yet.

Do not add kubeadm mode to the UI yet.

Only after this POC proves the node image can run systemd, containerd, kubeadm,
kubelet, and kubectl reliably on Windows Docker Desktop / WSL2 should the
project proceed to a 2-node kubeadm cluster.

