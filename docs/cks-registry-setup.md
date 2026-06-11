# CKS Local Registry Setup — Phase 2B

**Date:** 2026-06-11  
**Branch:** feat/cks-phase1-pipeline  
**Status:** Compose-level registry implemented. k3d bridge is a documented gap (Phase 2B-registry-k3d).

---

## 1. Architecture

```
Docker Desktop (Windows)
└── docker compose (ckx-network bridge)
    ├── nginx          :80   (proxy, only public port 127.0.0.1:30081)
    ├── jumphost       :22   (ckad9999 — privileged, CKS toolbox)
    ├── k8s-api-server :6443 (DinD, privileged)
    │   └── Docker-in-Docker daemon
    │       └── k3d cluster (k3s server + agents as containers)
    ├── facilitator    :3000
    ├── redis          :6379
    └── registry       :5000  ← Phase 2B (ckx-network internal only)
```

### What the registry is

- Image: `registry:2` (Docker Distribution, CNCF project)
- Hostname on `ckx-network`: `registry`
- Port: `5000` (internal only — `expose`, not `ports`)
- Storage: `registry-data` named volume (persists across `docker compose restart`)
- No authentication configured — open for local practice use only

### What the registry is NOT (yet)

The registry lives on `ckx-network`. k3d node containers run inside the DinD (`k8s-api-server`) Docker daemon and are on a separate Docker bridge network (DinD-internal). They **cannot** resolve `registry:5000` by DNS name. This means:

- **jumphost tools (trivy, cosign, syft, podman, skopeo)** CAN use the registry — they run directly on `ckx-network`.
- **k3d pods** CANNOT pull images from `registry:5000` without additional bridging — see Section 4.

---

## 2. How Lab Setup Scripts Use the Registry

Lab setup scripts (`scripts/setup/qX_setup.sh`) run on the jumphost via the facilitator. The jumphost has Docker CLI access and all CKS tools installed. Setup scripts that need to populate the registry should follow this pattern:

### 2.1 Push a vulnerable image for scanning

> **Status:** `docker push/pull` to `registry:5000` works as of Phase 2B-insecure-registry (2026-06-11). No login required. See Section 7 for details.

```bash
#!/bin/bash
# q1_setup.sh — push a vulnerable image to the local registry
# Requires Phase 2B-insecure-registry jumphost rebuild to use docker push.

REGISTRY="registry:5000"

# Pull a known vulnerable image and re-tag to the local registry
docker pull nginx:1.19.0
docker tag nginx:1.19.0 ${REGISTRY}/webserver:v1.0-vulnerable
docker push ${REGISTRY}/webserver:v1.0-vulnerable

# Verify the image is available
curl -s http://${REGISTRY}/v2/webserver/tags/list
```

### 2.2 Push a signed image for cosign verification tasks

```bash
#!/bin/bash
# q2_setup.sh — push and sign an image

REGISTRY="registry:5000"

docker pull alpine:3.18
docker tag alpine:3.18 ${REGISTRY}/app:signed
docker push ${REGISTRY}/app:signed

# Generate a keypair (key files written to /tmp/exam/q2/)
mkdir -p /tmp/exam/q2
COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix /tmp/exam/q2/cosign

# Sign the image (insecure registry — no TLS)
COSIGN_PASSWORD="" cosign sign \
  --key /tmp/exam/q2/cosign.key \
  --allow-insecure-registry \
  ${REGISTRY}/app:signed
```

### 2.3 Verification script pattern for supply chain tasks

```bash
#!/bin/bash
# q1_s1_validate_trivy_scan.sh — candidate ran trivy and found CVEs

# Check candidate wrote results to expected output file
RESULT_FILE="/tmp/exam/q1/trivy-report.txt"
if [ ! -f "$RESULT_FILE" ]; then
  echo "FAIL: trivy report not found at $RESULT_FILE"
  exit 1
fi

# Verify the candidate identified the correct CVE
if grep -q "CVE-2021-23017" "$RESULT_FILE"; then
  echo "PASS: CVE-2021-23017 identified in report"
  exit 0
else
  echo "FAIL: CVE-2021-23017 not found in report"
  exit 1
fi
```

---

## 3. Jumphost Usage — Candidate-Facing Commands

From the jumphost terminal (`ckad9999`), candidates use:

```bash
# List images in the registry
curl -s http://registry:5000/v2/_catalog

# List tags for an image
curl -s http://registry:5000/v2/<image>/tags/list

# Trivy scan from registry
trivy image --insecure registry:5000/webserver:v1.0-vulnerable

# Cosign verify signature
cosign verify \
  --key /tmp/exam/q2/cosign.pub \
  --allow-insecure-registry \
  registry:5000/app:signed

# Syft SBOM generation
syft registry:5000/app:signed --allow-insecure-registry -o spdx-json > /tmp/exam/q2/sbom.json

# Skopeo image inspection
skopeo inspect --tls-verify=false docker://registry:5000/webserver:v1.0-vulnerable
```

The `--insecure` / `--allow-insecure-registry` / `--tls-verify=false` flags are required because the registry runs plain HTTP (no TLS).

---

## 4. k3d Pod Image Pull — Confirmed Working (Phase 2C)

**Status: RESOLVED** — `kind-cluster/scripts/env-setup` updated (2026-06-11).

### Design

DinD's FORWARD chain has policy ACCEPT and DOCKER-USER is empty. k3d nodes on the DinD-internal bridge network can reach `172.19.0.x` (ckx-network) via the DinD host's routing — **no iptables changes, no socat proxy needed.**

`env-setup` now:
1. Resolves `registry` to its ckx-network IP at cluster-creation time: `getent hosts registry`
2. Appends a k3d `registries.config` block to the cluster config, pointing containerd mirrors at the resolved IP
3. k3d writes this config to `/etc/rancher/k3s/registries.yaml` in every node at startup

```yaml
# appended to /tmp/k3d-config.yaml by env-setup
registries:
  config: |
    mirrors:
      "registry.localhost:5000":
        endpoint:
          - "http://172.19.0.7:5000"   # resolved at cluster creation time
```

### Image ref convention for CKS labs

- **Jumphost push:** `docker push registry:5000/<image>:<tag>`
- **Pod image ref:** `registry.localhost:5000/<image>:<tag>`
- **Jumphost scan:** `trivy image --insecure registry:5000/<image>:<tag>`
- **Jumphost cosign:** `cosign verify --allow-insecure-registry ... registry:5000/<image>:<tag>`

The two hostnames are different aliases for the same physical registry instance. `registry` is ckx-network DNS; `registry.localhost` is the containerd mirror alias.

### Confirmed acceptance gate (tested 2026-06-11)

- [x] k3d pod pulls `registry.localhost:5000/ckx/phase2c-test:latest` → phase `Running`, logs printed
- [x] Jumphost pushed the same image to `registry:5000` (single registry instance)
- [x] `docker compose config --quiet` exits 0
- [x] No new external ports added
- [x] UI returns HTTP 200

### Re-creation requirement

The registry mirror config is written into containerd at cluster-creation time. **Existing k3d clusters created before Phase 2C must be deleted and recreated** to pick up the mirror config. The facilitator's env-setup handles this automatically for fresh exam sessions. To force a recreate manually:

```sh
# Inside the k8s-api-server container
k3d cluster delete cluster
env-setup 0 cluster
```

### Graceful degradation

If `registry` DNS is not yet resolvable when `env-setup` runs (race condition during compose startup), the log line `WARNING: registry not resolved` is printed and k3d pods cannot use `registry.localhost:5000`. The cluster starts normally; only the registry mirror is missing. This is safe — existing labs using public images are unaffected.

---

## 5. Registry Persistence and Lifecycle

| Event | Registry state |
|---|---|
| `docker compose restart registry` | Images preserved (volume) |
| `docker compose down` / `up -d` | Images preserved (named volume `registry-data`) |
| `docker compose down -v` | **Images deleted** — named volume removed |
| `docker compose build` (other services) | Registry unaffected |
| k3d cluster recreated | Registry unaffected (it's in compose, not in DinD) |

Lab setup scripts should be idempotent: check if the image/tag already exists before pushing.

```bash
# Idempotent push check
if ! curl -sf http://registry:5000/v2/webserver/tags/list | grep -q "v1.0-vulnerable"; then
  docker push registry:5000/webserver:v1.0-vulnerable
fi
```

---

## 6. Health Check

The registry exposes a standard v2 API health endpoint:

```bash
# From any service on ckx-network
curl -s http://registry:5000/v2/
# Returns: {}  (HTTP 200 = healthy)
```

The compose healthcheck polls this endpoint every 30 seconds.

---

## 7. docker push/pull — Confirmed Working (Phase 2B-insecure-registry)

**Status: RESOLVED** — `jumphost/Dockerfile` daemon.json updated and jumphost rebuilt (2026-06-11).

### What was done

The jumphost runs its own `dockerd`. Docker defaults to HTTPS for all registries, which caused plain-HTTP pushes to fail. The daemon config was updated to trust `registry:5000` as an insecure registry:

```json
{ "exec-opts": ["native.cgroupdriver=cgroupfs"], "insecure-registries": ["registry:5000"] }
```

The single-line change in `jumphost/Dockerfile`:

```dockerfile
# Before
RUN echo '{ "exec-opts": ["native.cgroupdriver=cgroupfs"] }' > /etc/docker/daemon.json

# After
RUN echo '{ "exec-opts": ["native.cgroupdriver=cgroupfs"], "insecure-registries": ["registry:5000"] }' > /etc/docker/daemon.json
```

### Confirmed working operations (tested 2026-06-11)

| Operation | Status |
|---|---|
| `wget http://registry:5000/v2/` | ✓ HTTP 200 |
| `docker push registry:5000/<image>:<tag>` | ✓ Push exit 0 |
| `docker pull registry:5000/<image>:<tag>` | ✓ Pull exit 0 |
| `trivy image --insecure registry:5000/...` | ✓ Resolves registry |
| `cosign sign --allow-insecure-registry ...` | ✓ Flag supported |
| `syft registry:5000/... --allow-insecure-registry` | ✓ Flag supported |
| Registry external port binding | ✓ NONE — internal only |

### Confirmed push/pull workflow for lab setup scripts

```bash
#!/bin/bash
# Example lab setup script pattern — fully operational after Phase 2B-insecure-registry

REGISTRY="registry:5000"

# Pull an image and push to local registry (no login required)
docker pull nginx:1.25
docker tag nginx:1.25 ${REGISTRY}/webserver:v1.25
docker push ${REGISTRY}/webserver:v1.25

# Verify
curl -s http://${REGISTRY}/v2/_catalog
# → {"repositories":["webserver"]}

curl -s http://${REGISTRY}/v2/webserver/tags/list
# → {"name":"webserver","tags":["v1.25"]}
```

### Impact

- Only `registry:5000` is treated as insecure — no other registries change trust.
- Existing CKS labs (cks-001, cks-002, cks-003) are unaffected.
- No new public ports added.
- No docker login required for the internal registry.
