[![Test build workflow](https://img.shields.io/github/actions/workflow/status/docker/github-builder-experimental/.test-build.yml?label=test%20build&logo=github&style=flat-square)](https://github.com/docker/github-builder-experimental/actions?workflow=.test-build)
[![Test bake workflow](https://img.shields.io/github/actions/workflow/status/docker/github-builder-experimental/.test-bake.yml?label=test%20bake&logo=github&style=flat-square)](https://github.com/docker/github-builder-experimental/actions?workflow=.test-bake)

> [!CAUTION]
> Do not use it for your production workflows yet!

## :test_tube: Experimental

This repository is considered **EXPERIMENTAL** and under active development
until further notice. It is subject to non-backward compatible changes or
removal in any future version.

___

* [Overview](#overview)
* [Key Advantages](#key-advantages)
  * [Performance](#performance)
  * [Security](#security)
  * [Isolation & Reliability](#isolation--reliability)
* [Usage](#usage)
  * [Build reusable workflow](#build-reusable-workflow)
    * [Inputs](#inputs)
    * [Secrets](#secrets)
  * [Bake reusable workflow](#bake-reusable-workflow)
    * [Inputs](#inputs)
    * [Secrets](#secrets)

## Overview

This repository provides official Docker-maintained [reusable GitHub Actions workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
to securely build container images and artifacts using Docker best practices.
The reusable workflows incorporate functionality from our GitHub Actions like
[`docker/build-push-action`](https://github.com/docker/build-push-action/),
[`docker/metadata-action`](https://github.com/docker/metadata-action/), etc.,
into a single workflow:

```yaml
name: ci

permissions:
  contents: read

on:
  push:
    branches:
      - 'main'
    tags:
      - 'v*'
  pull_request:

  build:
    uses: docker/github-builder-experimental/.github/workflows/build.yml@main
    permissions:
      contents: read # to fetch the repository content
      id-token: write # for signing attestation(s) with GitHub OIDC Token
    with:
      output: image
      push: ${{ github.event_name != 'pull_request' }}
      meta-images: name/app
    secrets:
      registry-auths: |
        - registry: docker.io
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
```

This workflow provides a trusted BuildKit instance and generates signed
SLSA-compliant provenance attestations, guaranteeing the build happened from
the source commit and all build steps ran in isolated sandboxed environments
from immutable sources. This enables GitHub projects to follow a seamless path
toward higher levels of security and trust.

## Key Advantages

### Performance

* **Native parallelization for multi-platform builds.**  
  Workflows can automatically distribute builds across runners based on target
  platform to be built, improving throughput for other architectures without
  requiring emulation or [custom CI logic](https://docs.docker.com/build/ci/github-actions/multi-platform/#distribute-build-across-multiple-runners)
  or self-managed runners.

* **Optimized cache warming & reuse.**  
  The builder can use the GitHub Actions cache backend to persist layers across
  branches, PRs, and rebuilds. This significantly reduces cold-start times and
  avoids repeating expensive dependency installations, even for external
  contributors' pull requests.

* **Centralized build configuration.**  
  Repositories no longer need to configure buildx drivers, tune storage, or
  adjust resource limits. The reusable workflows encapsulate the recommended
  configuration, providing fast, consistent builds across any project that
  opts in.

### Security

* **Trusted workflows in the Docker organization.**  
  Builds are executed by reusable workflows defined in the [**@docker**](https://github.com/docker)
  organization, not by arbitrary user-defined workflow steps. Consumers can
  rely on GitHub's trust model and repository protections on the Docker side
  (branch protection, code review, signing, etc.) to reason about who controls
  the build logic.

* **Verifiable, immutable sources.**  
  The workflows use the GitHub OIDC token and the exact commit SHA to obtain
  source and to bind it into SLSA provenance. This ensures that the build is
  tied to the repository contents as checked in—no additional CI step can
  silently swap out what is being built.

* **Signed SLSA provenance for every build.**  
  BuildKit generates [SLSA-compliant provenance attestation](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)
  artifacts that are signed with an identity bound to the GitHub workflow.
  Downstream consumers can verify:
  - which builder commit produced the image  
  - which source code commit produced the image  
  - which workflow and job executed the build  
  - what inputs and build parameters were used  

* **Protection from user workflow tampering.**  
  The build steps are pre-defined and optimized in the reusable workflow, and
  cannot be altered by user configuration. This protects against tampering:
  preventing untrusted workflow steps from modifying build logic, injecting
  unexpected flags, or producing misleading provenance.

### Isolation & Reliability

* **Separation between user CI logic and build logic.**  
  The user's workflow orchestrates *when* to build but not *how* to build.
  The actual build steps live in the Docker-maintained reusable workflows,
  which cannot be modified from the consuming repository.

* **Immutable, reproducible build pipeline.**  
  Builds are driven by declarative inputs (repository commit, build
  configuration, workflow version). This leads to:
  - reproducibility (same workflow + same inputs → same outputs)  
  - auditability (inputs and workflow identity recorded in provenance)  
  - reliability (less dependence on ad-hoc per-repo CI scripting)  

* **Reduced CI variability and config drift.**  
  By reusing the same workflows, projects avoid maintaining custom build logic
  per repository. Caching, provenance, SBOM generation, and build settings
  behave uniformly across all adopters.

* **Higher assurance for downstream consumers.**  
  Because artifacts are produced by a workflow in the [**@docker**](https://github.com/docker)
  organization, with SLSA provenance attached, consumers can verify both the
  *source commit* and the *builder identity* before trusting or promoting an
  image, an essential part of supply-chain hardening.

## Usage

### Build reusable workflow

The [`build.yml` reusable workflow](.github/workflows/build.yml) lets you build
container images and artifacts from a Dockerfile with a user experience similar
to [`docker/build-push-action`](https://github.com/docker/build-push-action/).
It provides a Docker-maintained, opinionated build pipeline that applies best
practices for security, performance, and reliability by default, including
isolated execution and signed SLSA provenance while keeping per-repository
configuration minimal.

```yaml
name: ci

permissions:
  contents: read

on:
  push:
    branches:
      - 'main'
    tags:
      - 'v*'
  pull_request:

  build:
    uses: docker/github-builder-experimental/.github/workflows/build.yml@main
    permissions:
      contents: read # to fetch the repository content
      id-token: write # for signing attestation(s) with GitHub OIDC Token
    with:
      output: image
      push: ${{ github.event_name != 'pull_request' }}
      platforms: linux/amd64,linux/arm64
      meta-images: name/app
      meta-tags: |
        type=ref,event=branch
        type=ref,event=pr
        type=semver,pattern={{version}}
    secrets:
      registry-auths: |
        - registry: docker.io
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

  # Optional job to verify the pushed images' signatures. This is already done
  # in the `build` job and can be omitted. It's provided here as an example of
  # how to use the `verify.yml` reusable workflow.
  build-verify:
    uses: docker/github-builder-experimental/.github/workflows/verify.yml@main
    if: ${{ github.event_name != 'pull_request' }}
    needs:
      - build
    with:
      builder-outputs: ${{ toJSON(needs.build.outputs) }}
    secrets:
      registry-auths: |
        - registry: docker.io
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
```

#### Inputs

> [!NOTE]
> `List` type is a newline-delimited string
> ```yaml
> cache-from: |
>   user/app:cache
>   type=local,src=path/to/dir
> ```
> 
> `CSV` type is a comma-delimited string
> ```yaml
> tags: name/app:latest,name/app:1.0.0
> ```

| Name                   | Type     | Default                        | Description                                                                                                                                                                                                                                                                                                                           |
|------------------------|----------|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `runner`               | String   | `auto`                         | [Ubuntu GitHub Hosted Runner](https://github.com/actions/runner-images?tab=readme-ov-file#available-images) to build on (one of `auto`, `amd64`, `arm64`). The `auto` runner selects the best-matching runner based on target `platforms`. You can set it to `amd64` if your build doesn't require emulation (e.g. cross-compilation) |
| `distribute`           | Bool     | `true`                         | Whether to distribute the build across multiple runners (one platform per runner)                                                                                                                                                                                                                                                     |
| `setup-qemu`           | Bool     | `false`                        | Runs the `setup-qemu-action` step to install QEMU static binaries                                                                                                                                                                                                                                                                     |
| `artifact-name`        | String   | `docker-github-builder-assets` | Name of the uploaded GitHub artifact (for `local` output)                                                                                                                                                                                                                                                                             |
| `artifact-upload`      | Bool     | `false`                        | Upload build output GitHub artifact (for `local` output)                                                                                                                                                                                                                                                                              |
| `annotations`          | List     |                                | List of annotations to set to the image (for `image` output)                                                                                                                                                                                                                                                                          |
| `build-args`           | List     | `auto`                         | List of [build-time variables](https://docs.docker.com/engine/reference/commandline/buildx_build/#build-arg). If you want to set a build-arg through an environment variable, use the `envs` input                                                                                                                                    |
| `cache`                | Bool     | `false`                        | Enable [GitHub Actions cache](https://docs.docker.com/build/cache/backends/gha/) exporter                                                                                                                                                                                                                                             |
| `cache-scope`          | String   | target name or `buildkit`      | Which [scope cache object belongs to](https://docs.docker.com/build/cache/backends/gha/#scope) if `cache` is enabled. This is the cache blob prefix name used when pushing cache to GitHub Actions cache backend                                                                                                                      |
| `cache-mode`           | String   | `min`                          | [Cache layers to export](https://docs.docker.com/build/cache/backends/#cache-mode) if cache enabled (`min` or `max`). In `min` cache mode, only layers that are exported into the resulting image are cached, while in `max` cache mode, all layers are cached, even those of intermediate steps                                      |
| `context`              | String   | `.`                            | Context to build from in the Git working tree                                                                                                                                                                                                                                                                                         |
| `file`                 | String   | `{context}/Dockerfile`         | Path to the Dockerfile                                                                                                                                                                                                                                                                                                                |
| `labels`               | List     |                                | List of labels for an image (for `image` output)                                                                                                                                                                                                                                                                                      |
| `output`               | String   |                                | Build output destination (one of [`image`](https://docs.docker.com/build/exporters/image-registry/) or [`local`](https://docs.docker.com/build/exporters/local-tar/)). Unlike the `build-push-action`, it only accepts `image` or `local`. The reusable workflow takes care of setting the `outputs` attribute                        |
| `platforms`            | List/CSV |                                | List of [target platforms](https://docs.docker.com/engine/reference/commandline/buildx_build/#platform) to build                                                                                                                                                                                                                      |
| `push`                 | Bool     | `false`                        | [Push](https://docs.docker.com/engine/reference/commandline/buildx_build/#push) image to the registry (for `image` output)                                                                                                                                                                                                            |
| `sbom`                 | Bool     | `false`                        | Generate [SBOM](https://docs.docker.com/build/attestations/sbom/) attestation for the build                                                                                                                                                                                                                                           |
| `shm-size`             | String   |                                | Size of [`/dev/shm`](https://docs.docker.com/engine/reference/commandline/buildx_build/#shm-size) (e.g., `2g`)                                                                                                                                                                                                                        |
| `sign`                 | String   | `auto`                         | Sign attestation manifest for `image` output or artifacts for `local` output, can be one of `auto`, `true` or `false`. The `auto` mode will enable signing if `push` is enabled for pushing the `image` or if `artifact-upload` is enabled for uploading the `local` build output as GitHub Artifact                                  |
| `target`               | String   |                                | Sets the target stage to build                                                                                                                                                                                                                                                                                                        |
| `ulimit`               | List     |                                | [Ulimit](https://docs.docker.com/engine/reference/commandline/buildx_build/#ulimit) options (e.g., `nofile=1024:1024`)                                                                                                                                                                                                                |
| `set-meta-annotations` | Bool     | `false`                        | Append OCI Image Format Specification annotations generated by `docker/metadata-action`                                                                                                                                                                                                                                               |
| `set-meta-labels`      | Bool     | `false`                        | Append OCI Image Format Specification labels generated by `docker/metadata-action`                                                                                                                                                                                                                                                    |
| `meta-images`          | List     |                                | [List of images](https://github.com/docker/metadata-action?tab=readme-ov-file#images-input) to use as base name for tags (required for image output)                                                                                                                                                                                  |
| `meta-tags`            | List     |                                | [List of tags](https://github.com/docker/metadata-action?tab=readme-ov-file#tags-input) as key-value pair attributes                                                                                                                                                                                                                  |
| `meta-flavor`          | List     |                                | [Flavor](https://github.com/docker/metadata-action?tab=readme-ov-file#flavor-input) defines a global behavior for `meta-tags`                                                                                                                                                                                                         |

#### Secrets

| Name             | Default               | Description                                                                    |
|------------------|-----------------------|--------------------------------------------------------------------------------|
| `registry-auths` |                       | Raw authentication to registries, defined as YAML objects (for `image` output) |
| `github-token`   | `${{ github.token }}` | GitHub Token used to authenticate against the repository for Git context       |

### Bake reusable workflow

The [`bake.yml` reusable workflow](.github/workflows/build.yml) lets you build
container images and artifacts from a [Bake definition](https://docs.docker.com/build/bake/)
with a user experience similar to [`docker/bake-action`](https://github.com/docker/bake-action/).
It provides a Docker-maintained, opinionated build pipeline that applies best
practices for security, performance, and reliability by default, including
isolated execution and signed SLSA provenance while keeping per-repository
configuration minimal.

```yaml
name: ci

permissions:
  contents: read

on:
  push:
    branches:
      - 'main'
    tags:
      - 'v*'
  pull_request:

  bake:
    uses: docker/github-builder-experimental/.github/workflows/bake.yml@main
    permissions:
      contents: read # to fetch the repository content
      id-token: write # for signing attestation(s) with GitHub OIDC Token
    with:
      output: image
      push: ${{ github.event_name != 'pull_request' }}
      meta-images: name/app
      meta-tags: |
        type=ref,event=branch
        type=ref,event=pr
        type=semver,pattern={{version}}
    secrets:
      registry-auths: |
        - registry: docker.io
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

  # Optional job to verify the pushed images' signatures. This is already done
  # in the `bake` job and can be omitted. It's provided here as an example of
  # how to use the `verify.yml` reusable workflow.
  bake-verify:
    uses: docker/github-builder-experimental/.github/workflows/verify.yml@main
    if: ${{ github.event_name != 'pull_request' }}
    needs:
      - bake
    with:
      builder-outputs: ${{ toJSON(needs.bake.outputs) }}
    secrets:
      registry-auths: |
        - registry: docker.io
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
```

#### Inputs

> `List` type is a newline-delimited string
> ```yaml
> set: target.args.mybuildarg=value
> ```
> ```yaml
> set: |
>   target.args.mybuildarg=value
>   foo*.args.mybuildarg=value
> ```

| Name                   | Type   | Default                        | Description                                                                                                                                                                                                                                                                                                                           |
|------------------------|--------|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `runner`               | String | `auto`                         | [Ubuntu GitHub Hosted Runner](https://github.com/actions/runner-images?tab=readme-ov-file#available-images) to build on (one of `auto`, `amd64`, `arm64`). The `auto` runner selects the best-matching runner based on target `platforms`. You can set it to `amd64` if your build doesn't require emulation (e.g. cross-compilation) |
| `distribute`           | Bool   | `true`                         | Whether to distribute the build across multiple runners (one platform per runner)                                                                                                                                                                                                                                                     |
| `setup-qemu`           | Bool   | `false`                        | Runs the `setup-qemu-action` step to install QEMU static binaries                                                                                                                                                                                                                                                                     |
| `artifact-name`        | String | `docker-github-builder-assets` | Name of the uploaded GitHub artifact (for `local` output)                                                                                                                                                                                                                                                                             |
| `artifact-upload`      | Bool   | `false`                        | Upload build output GitHub artifact (for `local` output)                                                                                                                                                                                                                                                                              |
| `cache`                | Bool   | `false`                        | Enable [GitHub Actions cache](https://docs.docker.com/build/cache/backends/gha/) exporter                                                                                                                                                                                                                                             |
| `cache-scope`          | String | target name or `buildkit`      | Which [scope cache object belongs to](https://docs.docker.com/build/cache/backends/gha/#scope) if `cache` is enabled. This is the cache blob prefix name used when pushing cache to GitHub Actions cache backend                                                                                                                      |
| `cache-mode`           | String | `min`                          | [Cache layers to export](https://docs.docker.com/build/cache/backends/#cache-mode) if cache enabled (`min` or `max`). In `min` cache mode, only layers that are exported into the resulting image are cached, while in `max` cache mode, all layers are cached, even those of intermediate steps                                      |
| `context`              | String | `.`                            | Context to build from in the Git working tree                                                                                                                                                                                                                                                                                         |
| `files`                | List   | `{context}/docker-bake.hcl`    | List of bake definition files                                                                                                                                                                                                                                                                                                         |
| `output`               | String |                                | Build output destination (one of [`image`](https://docs.docker.com/build/exporters/image-registry/) or [`local`](https://docs.docker.com/build/exporters/local-tar/)).                                                                                                                                                                |
| `push`                 | Bool   | `false`                        | Push image to the registry (for `image` output)                                                                                                                                                                                                                                                                                       |
| `sbom`                 | Bool   | `false`                        | Generate [SBOM](https://docs.docker.com/build/attestations/sbom/) attestation for the build                                                                                                                                                                                                                                           |
| `set`                  | List   |                                | List of [target values to override](https://docs.docker.com/engine/reference/commandline/buildx_bake/#set) (e.g., `targetpattern.key=value`)                                                                                                                                                                                          |
| `sign`                 | String | `auto`                         | Sign attestation manifest for `image` output or artifacts for `local` output, can be one of `auto`, `true` or `false`. The `auto` mode will enable signing if `push` is enabled for pushing the `image` or if `artifact-upload` is enabled for uploading the `local` build output as GitHub Artifact                                  |
| `target`               | String | `default`                      | Bake target to build                                                                                                                                                                                                                                                                                                                  |
| `vars`                 | List   |                                | [Variables](https://docs.docker.com/build/bake/variables/) to set in the Bake definition as list of key-value pair                                                                                                                                                                                                                    |
| `set-meta-annotations` | Bool   | `false`                        | Append OCI Image Format Specification annotations generated by `docker/metadata-action`                                                                                                                                                                                                                                               |
| `set-meta-labels`      | Bool   | `false`                        | Append OCI Image Format Specification labels generated by `docker/metadata-action`                                                                                                                                                                                                                                                    |
| `meta-images`          | List   |                                | [List of images](https://github.com/docker/metadata-action?tab=readme-ov-file#images-input) to use as base name for tags (required for image output)                                                                                                                                                                                  |
| `meta-tags`            | List   |                                | [List of tags](https://github.com/docker/metadata-action?tab=readme-ov-file#tags-input) as key-value pair attributes                                                                                                                                                                                                                  |
| `meta-labels`          | List   |                                | [List of custom labels](https://github.com/docker/metadata-action?tab=readme-ov-file#overwrite-labels-and-annotations)                                                                                                                                                                                                                |
| `meta-annotations`     | List   |                                | [List of custom annotations](https://github.com/docker/metadata-action?tab=readme-ov-file#overwrite-labels-and-annotations)                                                                                                                                                                                                           |
| `meta-flavor`          | List   |                                | [Flavor](https://github.com/docker/metadata-action?tab=readme-ov-file#flavor-input) defines a global behavior for `meta-tags`                                                                                                                                                                                                         |

#### Secrets

| Name             | Default               | Description                                                                    |
|------------------|-----------------------|--------------------------------------------------------------------------------|
| `registry-auths` |                       | Raw authentication to registries, defined as YAML objects (for `image` output) |
| `github-token`   | `${{ github.token }}` | GitHub Token used to authenticate against the repository for Git context       |
