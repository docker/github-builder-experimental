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

### Usage

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
      id-token: write # for signing attestation manifests with GitHub OIDC Token
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

### Inputs

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

| Name                   | Type        | Default                        | Description                                                                                                                                                                                                                                                                                                                           |
|------------------------|-------------|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `runner`               | String      | `auto`                         | [Ubuntu GitHub Hosted Runner](https://github.com/actions/runner-images?tab=readme-ov-file#available-images) to build on (one of `auto`, `amd64`, `arm64`). The `auto` runner selects the best-matching runner based on target `platforms`. You can set it to `amd64` if your build doesn't require emulation (e.g. cross-compilation) |
| `setup-qemu`           | Bool        | `false`                        | Runs the `setup-qemu-action` step to install QEMU static binaries                                                                                                                                                                                                                                                                     |
| `setup-qemu-image`     | String      | `tonistiigi/binfmt:latest`     | QEMU static binaries Docker image to use                                                                                                                                                                                                                                                                                              |
| `artifact-name`        | String      | `docker-github-builder-assets` | Name of the uploaded GitHub artifact (for `local` output)                                                                                                                                                                                                                                                                             |
| `artifact-upload`      | Bool        | `false`                        | Upload build output GitHub artifact (for `local` output)                                                                                                                                                                                                                                                                              |
| `envs`                 | List        |                                | Environment variables to inject in the reusable workflow as list of key-value pair. This is similar to the [GitHub Actions `env` context](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#env-context) but as it cannot be used when calling a reusable workflow, we need to define our own input         |
| `annotations`          | List        |                                | List of annotations to set to the image (for `image` output)                                                                                                                                                                                                                                                                          |
| `build-args`           | List        | `auto`                         | List of [build-time variables](https://docs.docker.com/engine/reference/commandline/buildx_build/#build-arg). If you want to set a build-arg through an environment variable, use the `envs` input                                                                                                                                    |
| `context`              | String      | `.`                            | Context to build from in the Git working tree                                                                                                                                                                                                                                                                                         |
| `file`                 | String      | `{context}/Dockerfile`         | Path to the Dockerfile                                                                                                                                                                                                                                                                                                                |
| `labels`               | List        |                                | List of labels for an image (for `image` output)                                                                                                                                                                                                                                                                                      |
| `output`               | String      |                                | Build output destination (one of [`image`](https://docs.docker.com/build/exporters/image-registry/) or [`local`](https://docs.docker.com/build/exporters/local-tar/)). Unlike the `build-push-action`, it only accepts `image` or `local`. The reusable workflow takes care of setting the `outputs` attribute                        |
| `platforms`            | List/CSV    |                                | List of [target platforms](https://docs.docker.com/engine/reference/commandline/buildx_build/#platform) to build                                                                                                                                                                                                                      |
| `pull`                 | Bool        | `false`                        | Always attempt to pull all referenced images                                                                                                                                                                                                                                                                                          |
| `push`                 | Bool        | `false`                        | [Push](https://docs.docker.com/engine/reference/commandline/buildx_build/#push) image to the registry (for `image` output)                                                                                                                                                                                                            |
| `sbom`                 | Bool/String |                                | Generate [SBOM](https://docs.docker.com/build/attestations/sbom/) attestation for the build                                                                                                                                                                                                                                           |
| `shm-size`             | String      |                                | Size of [`/dev/shm`](https://docs.docker.com/engine/reference/commandline/buildx_build/#shm-size) (e.g., `2g`)                                                                                                                                                                                                                        |
| `sign`                 | String      | `auto`                         | Sign attestation manifest for `image` output or artifacts for `local` output, can be one of `auto`, `true` or `false`. The `auto` mode will enable signing if `push` is enabled for pushing the `image` or if `artifact-upload` is enabled for uploading the `local` build output as GitHub Artifact                                  |
| `target`               | String      |                                | Sets the target stage to build                                                                                                                                                                                                                                                                                                        |
| `ulimit`               | List        |                                | [Ulimit](https://docs.docker.com/engine/reference/commandline/buildx_build/#ulimit) options (e.g., `nofile=1024:1024`)                                                                                                                                                                                                                |
| `set-meta-annotations` | Bool        | `false`                        | Append OCI Image Format Specification annotations generated by `docker/metadata-action`                                                                                                                                                                                                                                               |
| `set-meta-labels`      | Bool        | `false`                        | Append OCI Image Format Specification labels generated by `docker/metadata-action`                                                                                                                                                                                                                                                    |
| `meta-images`          | List        |                                | [List of images](https://github.com/docker/metadata-action?tab=readme-ov-file#images-input) to use as base name for tags (required for image output)                                                                                                                                                                                  |
| `meta-tags`            | List        | `auto`                         | [List of tags](https://github.com/docker/metadata-action?tab=readme-ov-file#tags-input) as key-value pair attributes                                                                                                                                                                                                                  |
| `meta-flavor`          | List        | `auto`                         | [Flavor](https://github.com/docker/metadata-action?tab=readme-ov-file#flavor-input) defines a global behavior for `meta-tags`                                                                                                                                                                                                         |

### Secrets

| Name              | Description                                                                    |
|-------------------|--------------------------------------------------------------------------------|
| `registry-auths`  | Raw authentication to registries, defined as YAML objects (for `image` output) |

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
      contents: read # to fetch the repository content
      id-token: write # for signing attestation manifests with GitHub OIDC Token
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

> [!TIP]
> You can find the list of available inputs in [`.github/workflows/bake.yml`](.github/workflows/bake.yml).
