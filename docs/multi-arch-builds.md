# Multi-Architecture Image Builds

The Fabricator cluster is heterogeneous by design — Raspberry Pi 5 nodes are `arm64`, while any
PC or mini-server joined to the cluster is `amd64`. An image built on one of those machines runs
only on machines of that architecture, so any image this repository publishes has to be built for
both and shipped under a single tag.

This guide covers how that is done with the in-cluster ARC runners: what to change in the `arc`
Helm chart, what the build workflow looks like, and how to verify the result.

## 1. Why not just emulate

`docker buildx` can build any architecture anywhere via QEMU (`--platform linux/amd64,linux/arm64`
on a single runner). It works, and it is the wrong default here: emulated builds run roughly 5-20x
slower than native, and the slow side of that trade is a Raspberry Pi emulating x86. A compile that
takes three minutes natively can take the better part of an hour.

Since the cluster already contains machines of both architectures, the better approach is to let
each architecture build itself:

```
                    ┌──────────────────────┐
   push to master ──┤ build (matrix)       │
                    ├──────────────────────┤
                    │ arc-amd64 runner ────┼──▶ image pushed by digest ─┐
                    │ (amd64 node)         │                            │
                    ├──────────────────────┤                            │
                    │ arc-arm64 runner ────┼──▶ image pushed by digest ─┤
                    │ (arm64 node)         │                            │
                    └──────────────────────┘                            ▼
                                                          ┌──────────────────────────┐
                                                          │ merge                    │
                                                          │ buildx imagetools create │
                                                          │  → one tag, both arches  │
                                                          └──────────────────────────┘
```

Each leg builds one platform natively. Neither pushes a tag — they push *by digest*, so they cannot
overwrite each other. A final job combines the digests into a manifest list and publishes the tag.
A `docker pull` of that tag then resolves to whichever architecture the puller is running.

## 2. Prerequisites

- The ARC controller and at least one scale set already deployed from `core/arc` (see
  [cicd.md](./cicd.md)).
- At least one schedulable node per architecture. Check what the cluster actually has:

  ```bash
  kubectl get nodes -L kubernetes.io/arch
  ```

  If every node reports `arm64`, the `amd64` leg of the matrix will sit in `Pending` forever —
  see [section 9](#9-fallback-qemu-for-a-missing-architecture).
- A registry to push to. The examples use GHCR (`ghcr.io`), which accepts the workflow's built-in
  `GITHUB_TOKEN` — no extra secret needed.

## 3. Step 1 — Arch-pinned runner scale sets

A runner pod with no `nodeSelector` lands on whatever node the scheduler picks, so a build on it
produces an unpredictable architecture. The fix is one scale set per architecture, each pinned to
its arch and each running a Docker daemon.

### 3.1 Declare the extra scale sets

Helm requires an `alias` to install the same subchart more than once. In `core/arc/Chart.yaml`:

```yaml
dependencies:
  - name: gha-runner-scale-set-controller
    version: 0.13.1
    repository: oci://ghcr.io/actions/actions-runner-controller-charts
  - name: gha-runner-scale-set            # existing: general-purpose, runs-on: arc
    version: 0.13.1
    repository: oci://ghcr.io/actions/actions-runner-controller-charts
  - name: gha-runner-scale-set            # new: runs-on: arc-amd64
    version: 0.13.1
    repository: oci://ghcr.io/actions/actions-runner-controller-charts
    alias: gha-runner-scale-set-amd64
  - name: gha-runner-scale-set            # new: runs-on: arc-arm64
    version: 0.13.1
    repository: oci://ghcr.io/actions/actions-runner-controller-charts
    alias: gha-runner-scale-set-arm64
```

The single controller manages all of them — never duplicate the controller dependency.

### 3.2 Configure them

In `core/arc/values.yaml`, one block per alias:

```yaml
gha-runner-scale-set-amd64:
  ## REQUIRED. The chart derives the scale set name from
  ## `.Values.runnerScaleSetName | default .Release.Name`, and under an umbrella
  ## chart .Release.Name is "arc" for every subchart - without this, two
  ## AutoscalingRunnerSets would both be named "arc" and the install fails.
  ## This is also the value workflows put in `runs-on:`.
  runnerScaleSetName: "arc-amd64"
  githubConfigUrl: "https://github.com/sondn98/fabricator"
  githubConfigSecret:
    github_token: "<specified in runtime>"
  maxRunners: 2
  minRunners: 0
  runnerGroup: "default"
  controllerServiceAccount:
    name: arc-gha-rs-controller
    namespace: arc

  ## Gives each runner pod a privileged `docker:dind` sidecar and points
  ## DOCKER_HOST at it. The runner image ships the docker CLI and the buildx
  ## plugin but no daemon, so builds need this.
  containerMode:
    type: "dind"

  template:
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
        - name: runner
          image: ghcr.io/actions/actions-runner:latest
          command: ["/home/runner/run.sh"]

gha-runner-scale-set-arm64:
  runnerScaleSetName: "arc-arm64"
  githubConfigUrl: "https://github.com/sondn98/fabricator"
  githubConfigSecret:
    github_token: "<specified in runtime>"
  maxRunners: 2
  minRunners: 0
  runnerGroup: "default"
  controllerServiceAccount:
    name: arc-gha-rs-controller
    namespace: arc
  containerMode:
    type: "dind"
  template:
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
      containers:
        - name: runner
          image: ghcr.io/actions/actions-runner:latest
          command: ["/home/runner/run.sh"]
```

Notes on the choices above:

- **Stock runner image.** Build jobs need only docker + buildx, both of which the upstream
  `actions-runner` image already contains. The custom image in `docker/arc-runner/` exists for the
  helmfile jobs and is not needed here.
- **No `serviceAccountName`.** Build runners have no reason to talk to the Kubernetes API, so they
  keep the chart's default no-permission ServiceAccount. Do not point them at `arc-runner`, which
  is bound to `cluster-admin`.
- **`containerMode: dind` implies privileged pods.** The sidecar runs `privileged: true` — that is
  how a Docker daemon works inside Kubernetes. If your policy forbids it, see
  [section 10](#10-alternative-buildkit-without-privileged-pods).

### 3.3 Supply a token for each scale set

Every scale set authenticates to GitHub separately. `provisioning/playbook.yml` currently injects
one token; extend it to cover the new ones:

```yaml
    - name: Deploy ARC helm chart
      kubernetes.core.helm:
        name: arc
        chart_ref: "{{ playbook_dir }}/../core/arc"
        release_namespace: arc
        create_namespace: true
        dependency_update: true
        wait: true
        values:
          gha-runner-scale-set:
            githubConfigSecret:
              github_token: "{{ lookup('env', 'GITHUB_ARC_ACCESS_TOKEN') }}"
          gha-runner-scale-set-amd64:
            githubConfigSecret:
              github_token: "{{ lookup('env', 'GITHUB_ARC_ACCESS_TOKEN') }}"
          gha-runner-scale-set-arm64:
            githubConfigSecret:
              github_token: "{{ lookup('env', 'GITHUB_ARC_ACCESS_TOKEN') }}"
        context: "{{ hostvars[groups['server'][0]]['cluster_context'] | default('k3s-ansible') }}"
```

The same PAT works for all three as long as it has access to the repository. `githubConfigSecret`
also accepts a plain string — the name of a Secret you created yourself — if you would rather not
pass tokens through Ansible.

### 3.4 Deploy and verify

```bash
cd provisioning && task provision
```

Then confirm both scale sets registered:

```bash
kubectl get autoscalingrunnersets -n arc
# NAME        MINIMUM RUNNERS   MAXIMUM RUNNERS   CURRENT RUNNERS
# arc         0                 3                 0
# arc-amd64   0                 2                 0
# arc-arm64   0                 2                 0

kubectl get autoscalinglisteners -n arc      # one listener per scale set, all Running
```

They should also appear under *Settings → Actions → Runners* in the repository, listed by the
`runnerScaleSetName` values.

## 4. Step 2 — The build workflow

Save as `.github/workflows/image.yml`. It builds `docker/arc-runner` as the worked example; change
`IMAGE` and `CONTEXT` for other images, or lift them into a matrix if you publish several.

```yaml
name: Image

on:
  push:
    branches:
      - master
    paths:
      - "docker/arc-runner/**"
      - ".github/workflows/image.yml"
  workflow_dispatch:

permissions:
  contents: read

env:
  IMAGE: ghcr.io/sondn98/fabricator-arc-runner
  CONTEXT: docker/arc-runner

jobs:
  build:
    name: Build ${{ matrix.arch }}
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - arch: amd64
            runner: arc-amd64
          - arch: arm64
            runner: arc-arm64
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          persist-credentials: false

      - name: Set up Buildx
        uses: docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c # v4.2.0

      - name: Log in to GHCR
        uses: docker/login-action@abd2ef45e78c5afb21d64d4ca52ee8550d9572c7 # v4.5.1
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # One platform per job - the runner is already on a node of that
      # architecture, so this builds natively with no emulation.
      - name: Build and push by digest
        id: build
        uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a # v7.3.0
        with:
          context: ${{ env.CONTEXT }}
          platforms: linux/${{ matrix.arch }}
          outputs: type=image,name=${{ env.IMAGE }},push-by-digest=true,name-canonical=true,push=true
          cache-from: type=gha,scope=${{ matrix.arch }}
          cache-to: type=gha,mode=max,scope=${{ matrix.arch }}

      # Hand the digest to the merge job as an empty file named after it.
      - name: Export digest
        env:
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          set -euo pipefail
          mkdir -p /tmp/digests
          touch "/tmp/digests/${DIGEST#sha256:}"

      - name: Upload digest
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: digest-${{ matrix.arch }}
          path: /tmp/digests/*
          if-no-files-found: error
          retention-days: 1

  merge:
    name: Publish manifest list
    needs: build
    runs-on: arc
    permissions:
      contents: read
      packages: write
    steps:
      - name: Download digests
        uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
        with:
          path: /tmp/digests
          pattern: digest-*
          merge-multiple: true

      - name: Set up Buildx
        uses: docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c # v4.2.0

      - name: Log in to GHCR
        uses: docker/login-action@abd2ef45e78c5afb21d64d4ca52ee8550d9572c7 # v4.5.1
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Combines the per-arch digests into one manifest list and tags it.
      - name: Create manifest list
        working-directory: /tmp/digests
        run: |
          set -euo pipefail
          docker buildx imagetools create \
            --tag "${IMAGE}:${GITHUB_SHA}" \
            --tag "${IMAGE}:latest" \
            $(printf "${IMAGE}@sha256:%s " *)

      - name: Inspect published image
        run: docker buildx imagetools inspect "${IMAGE}:${GITHUB_SHA}"
```

Why it is shaped this way:

- **`push-by-digest=true`** uploads layers and a manifest but claims no tag. Without it, both legs
  would push `:latest` and the second would silently replace the first — the classic "my multi-arch
  image only has one arch" bug.
- **`name-canonical=true`** is required alongside it so the pushed manifest carries the canonical
  image name.
- **`fail-fast: false`** keeps an arm64 failure from cancelling an in-flight amd64 build, which
  makes debugging one architecture much easier.
- **`merge` runs on `arc`**, the general-purpose scale set — it only manipulates registry metadata,
  so it needs neither a specific architecture nor a Docker daemon.
- **Cache is scoped per architecture** (`scope=${{ matrix.arch }}`). Sharing one scope would make
  the two legs evict each other's layers on every run.

## 5. Step 3 — Verify

```bash
docker buildx imagetools inspect ghcr.io/sondn98/fabricator-arc-runner:latest
```

A correct result lists both platforms:

```
Name:      ghcr.io/sondn98/fabricator-arc-runner:latest
MediaType: application/vnd.oci.image.index.v1+json

Manifests:
  Name:      ghcr.io/sondn98/fabricator-arc-runner:latest@sha256:...
  Platform:  linux/amd64

  Name:      ghcr.io/sondn98/fabricator-arc-runner:latest@sha256:...
  Platform:  linux/arm64
```

If only one platform appears, the other leg either failed or never ran — check the matrix job
results before looking anywhere else.

## 6. Writing architecture-agnostic Dockerfiles

Buildx sets these build args automatically per platform; use them instead of hardcoding:

| Build arg | Example value | Use |
| --- | --- | --- |
| `TARGETARCH` | `arm64`, `amd64` | Picking release assets — most projects name them this way |
| `TARGETOS` | `linux` | Rarely needed here |
| `TARGETPLATFORM` | `linux/arm64` | When a tool wants the combined form |
| `TARGETVARIANT` | `v7` | 32-bit ARM only |

`docker/arc-runner/Dockerfile` already follows this pattern:

```dockerfile
ARG TARGETARCH=arm64
RUN curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" ...
```

Two things to watch for:

- **Naming mismatches.** Some projects publish `x86_64`/`aarch64` rather than `amd64`/`arm64`. Map
  them explicitly rather than hoping:

  ```dockerfile
  RUN case "${TARGETARCH}" in \
        amd64) ARCH=x86_64 ;; \
        arm64) ARCH=aarch64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
      esac \
   && curl -fsSL "https://example.com/tool-${ARCH}.tar.gz" -o /tmp/tool.tar.gz
  ```

  Failing loudly on an unknown architecture beats silently producing a broken image.
- **Base images must themselves be multi-arch.** Check before relying on one:

  ```bash
  docker buildx imagetools inspect ghcr.io/actions/actions-runner:2.336.0
  ```

## 7. Publishing several images

Fold the image list into the matrix and key the digest artifacts by both dimensions:

```yaml
    strategy:
      fail-fast: false
      matrix:
        image:
          - { name: arc-runner, context: docker/arc-runner }
          - { name: enterprise-gateway, context: docker/enterprise_gateway }
        include:
          - { arch: amd64, runner: arc-amd64 }
          - { arch: arm64, runner: arc-arm64 }
```

Then use `digest-${{ matrix.image.name }}-${{ matrix.arch }}` for the artifact name and give the
merge job a matching matrix over `image`, with `pattern: digest-${{ matrix.image.name }}-*`.

## 8. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Matrix leg queues forever, no pod appears | No node of that architecture, or `nodeSelector` matches nothing | `kubectl get nodes -L kubernetes.io/arch`; add a node or drop the leg |
| Runner pod stuck `Pending` | Node exists but is tainted or out of resources | `kubectl describe pod -n arc <pod>` and read the events |
| `Cannot connect to the Docker daemon` | `containerMode: dind` not set on that scale set | Add it, redeploy, and confirm the pod has two containers |
| `denied: permission_denied` on push | Job missing `packages: write` | Add it at job level — the workflow default is `contents: read` |
| Published tag lists only one platform | A leg failed, or `push-by-digest` was omitted so tags overwrote each other | Check both legs; verify the `outputs:` line |
| `imagetools create` complains about unexpected manifests | Provenance attestations pushed alongside the image | Add `provenance: false` to the build step |
| Build is inexplicably slow | The job landed on the wrong arch and is emulating | Confirm `runs-on` matches the intended scale set; `uname -m` in a debug step |
| Two `AutoscalingRunnerSet`s named `arc` | `runnerScaleSetName` missing from an aliased block | Set it — it does not default per alias |

## 9. Fallback: QEMU for a missing architecture

Until a node of the second architecture exists, one runner can emulate it. Expect it to be slow,
and treat it as temporary:

```yaml
      - name: Set up QEMU
        uses: docker/setup-qemu-action@96fe6ef7f33517b61c61be40b68a1882f3264fb8 # v4.2.0

      - name: Build both platforms on one runner
        uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a # v7.3.0
        with:
          context: ${{ env.CONTEXT }}
          platforms: linux/amd64,linux/arm64
          tags: ${{ env.IMAGE }}:latest
          push: true
```

Note this needs no digest/merge dance — buildx produces the manifest list itself. Registering QEMU
binfmt handlers requires a privileged container, which the dind sidecar already provides.

## 10. Alternative: BuildKit without privileged pods

If privileged dind is unacceptable, run BuildKit as its own workload and have the runner drive it
remotely. One builder with a node per architecture:

```bash
docker buildx create --name fabricator --driver kubernetes \
  --platform linux/amd64 \
  --driver-opt namespace=buildkit,nodeselector=kubernetes.io/arch=amd64

docker buildx create --name fabricator --append \
  --driver kubernetes \
  --platform linux/arm64 \
  --driver-opt namespace=buildkit,nodeselector=kubernetes.io/arch=arm64
```

`docker buildx build --platform linux/amd64,linux/arm64` then routes each platform to the matching
BuildKit pod and builds both natively in a single job — no per-arch runner, no digest merge. The
runner needs only the buildx CLI and API access to the `buildkit` namespace (a small Role, not
`cluster-admin`), and BuildKit itself can run rootless. The trade-off is a second workload to
deploy and maintain.

## 11. See also

- [cicd.md](./cicd.md) — the `core` helmfile workflow, runner image, and ARC RBAC
- [hardware.md](./hardware.md) — what is physically in the cluster
- [Docker docs: distribute builds across multiple runners](https://docs.docker.com/build/ci/github-actions/multi-platform/#distribute-build-across-multiple-runners)
