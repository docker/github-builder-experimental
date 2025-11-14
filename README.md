> [!CAUTION]
> Do not use it for your production workflows yet!

# GitHub Builder

This repository provides official Docker-maintained [reusable GitHub Actions workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
to securely build container images using Docker best practices. The workflows
sign BuildKit-generated SLSA-compliant provenance attestations and align with
the principles behind [Docker Hardened Images](https://docs.docker.com/dhi/),
enabling open source projects to follow a seamless path toward higher levels of
security and trust.

## :test_tube: Experimental

This repository is considered **EXPERIMENTAL** and under active development
until further notice. It is subject to non-backward compatible changes or
removal in any future version.

## Build reusable workflow

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
      contents: read
      id-token: write # for signing attestation manifests with GitHub OIDC Token
      packages: write # only used if pushing to GHCR but needs to be defined as caller must provide permissions ≥ to those used in the reusable workflow
    with:
      output: ${{ github.event_name != 'pull_request' && 'registry' || 'cacheonly' }}
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

  build-verify:
    runs-on: ubuntu-latest
    if: ${{ github.event_name != 'pull_request' }}
    needs:
      - build
    steps:
      -
        name: Install Cosign
        uses: sigstore/cosign-installer@faadad0cce49287aee09b3a48701e75088a2c6ad # v4.0.0
        with:
          cosign-release: ${{ needs.build.outputs.cosign-version }}
      -
        name: Login to registry
        uses: docker/login-action@v3
        with:
          registry: docker.io
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      -
        name: Verify signatures
        uses: actions/github-script@v8
        env:
          INPUT_COSIGN-VERIFY-COMMANDS: ${{ needs.build.outputs.cosign-verify-commands }}
        with:
          script: |
            for (const cmd of core.getMultilineInput('cosign-verify-commands')) {
              await exec.exec(cmd);
            }
```

You can find the list of available inputs in [`.github/workflows/build.yml`](.github/workflows/build.yml).

## Bake reusable workflow

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
      contents: read
      id-token: write # for signing attestation manifests with GitHub OIDC Token
      packages: write # only used if pushing to GHCR but needs to be defined as caller must provide permissions ≥ to those used in the reusable workflow
    with:
      output: ${{ github.event_name != 'pull_request' && 'registry' || 'cacheonly' }}
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

  bake-verify:
    runs-on: ubuntu-latest
    if: ${{ github.event_name != 'pull_request' }}
    needs:
      - bake
    steps:
      -
        name: Install Cosign
        uses: sigstore/cosign-installer@faadad0cce49287aee09b3a48701e75088a2c6ad # v4.0.0
        with:
          cosign-release: ${{ needs.bake.outputs.cosign-version }}
      -
        name: Login to registry
        uses: docker/login-action@v3
        with:
          registry: docker.io
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      -
        name: Verify signatures
        uses: actions/github-script@v8
        env:
          INPUT_COSIGN-VERIFY-COMMANDS: ${{ needs.bake.outputs.cosign-verify-commands }}
        with:
          script: |
            for (const cmd of core.getMultilineInput('cosign-verify-commands')) {
              await exec.exec(cmd);
            }
```

You can find the list of available inputs in [`.github/workflows/bake.yml`](.github/workflows/bake.yml).
