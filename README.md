[![Test workflow](https://img.shields.io/github/actions/workflow/status/docker/github-builder-experimental/.test.yml?label=test&logo=github&style=flat-square)](https://github.com/docker/github-builder-experimental/actions?workflow=.test)

> [!CAUTION]
> Do not use it for your production workflows yet!

## :test_tube: Experimental

This repository is considered **EXPERIMENTAL** and under active development
until further notice. It is subject to non-backward compatible changes or
removal in any future version.

___

* [About](#about)
* [Key Advantages](#key-advantages)
  * [Performance](#performance)
  * [Security](#security)
  * [Isolation & Reliability](#isolation--reliability)
* [Usage](#usage)
  * [Build reusable workflow](#build-reusable-workflow)
  * [Bake reusable workflow](#bake-reusable-workflow)

## About

This repository provides official Docker-maintained [reusable GitHub Actions workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
to securely build container images using Docker best practices. The workflows
sign BuildKit-generated SLSA-compliant provenance attestations and align with
the principles behind [Docker Hardened Images](https://docs.docker.com/dhi/),
enabling open source projects to follow a seamless path toward higher levels of
security and trust.

## Key Advantages

### Performance

* **Native parallelization for multi-platform builds.**  
  Workflows automatically distribute builds across runners based on target
  platform to be built, improving throughput for other architectures without
  requiring emulation or [custom CI logic](https://docs.docker.com/build/ci/github-actions/multi-platform/#distribute-build-across-multiple-runners)
  or self-managed runners.

* **Optimized cache warming & reuse.**  
  The builder uses the [GitHub Actions cache backend](https://docs.docker.com/build/cache/backends/gha/)
  to persist layers across branches, PRs, and rebuilds. This significantly
  reduces cold-start times and avoids repeating expensive dependency
  installations, even for external contributors' pull requests.

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
  - which commit produced the image  
  - which workflow and job executed the build  
  - what inputs and build parameters were used  

* **Protection from user workflow tampering.**  
  The user workflow never executes `docker build` directly. Instead, it calls
  a reusable workflow owned by the [**@docker**](https://github.com/docker)
  organization. This prevents untrusted workflow steps in the user repository
  from modifying the build logic, injecting unexpected flags, or producing
  misleading provenance.

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
  image—an essential part of supply-chain hardening.

## Usage

### Build reusable workflow

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
      meta-tags: |
        type=ref,event=branch
        type=ref,event=pr
        type=semver,pattern={{version}}
      build-platforms: linux/amd64,linux/arm64
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

You can find the list of available inputs in [`.github/workflows/build.yml`](.github/workflows/build.yml).

### Bake reusable workflow

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

You can find the list of available inputs in [`.github/workflows/bake.yml`](.github/workflows/bake.yml).
