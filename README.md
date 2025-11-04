> [!CAUTION]
> Do not use it for your production workflows yet!

# GitHub Builder

This repository provides official Docker-maintained [reusable GitHub Actions workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
to securely build container images using Docker best practices. The workflows
sign BuildKit-generated SLSA-compliant provenance attestations and align with
the principles behind [Docker Hardened Images](https://docs.docker.com/dhi/how-to/use/),
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
      packages: write # needed to push images to GitHub Container Registry
    with:
      meta-images: name/app
      meta-tags: |
        type=ref,event=branch
        type=ref,event=pr
        type=semver,pattern={{version}}
      build-output: ${{ github.event_name != 'pull_request' && 'registry' || 'cacheonly' }}
      build-platforms: linux/amd64,linux/arm64
    secrets:
      registry-auths: |
        - registry: docker.io
          username: ${{ vars.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
```

You can find the list of available inputs in [`.github/workflows/build.yml`](.github/workflows/build.yml).
