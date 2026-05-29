# dce-build-and-push

Reusable GitHub Actions workflow for building and pushing Docker images to ECR.

## Reusable workflow

- Path: `.github/workflows/reusable-build-and-push.yml`
- Trigger: `workflow_call`
- Inputs for per-repo variation:
  - `repository_name` (required)
  - `version_tag_this_branch`
  - `base_image_name`
  - `ecr_pull_through_prefix`
  - `context`
  - `dockerfile`
  - `version_command` (required; language-specific version lookup)
- Required secrets:
  - `AWS_PUSH_TO_ECR_OIDC_ROLE`
  - `AWS_DEFAULT_REGION`
  - `AWS_ACCOUNT_ID`

## Consumer usage

In each consuming repository, add a workflow under `.github/workflows/`:

```yaml
name: Build and Push Image to ECR

on:
  workflow_dispatch:
  push:
    branches: [main, stage, "*/*"]

jobs:
  zizmor:
    uses: your-org/dce-build-and-push/.github/workflows/zizmor.yml@v1

  build_and_push:
    uses: your-org/dce-build-and-push/.github/workflows/reusable-build-and-push.yml@v1
    with:
      repository_name: hdce/cryo
      version_tag_this_branch: main
      base_image_name: node:24-alpine
      ecr_pull_through_prefix: docker-hub/library
      context: ./app
      dockerfile: ./app/Dockerfile
      version_command: jq -r .version ./app/package.json
    secrets:
      AWS_PUSH_TO_ECR_OIDC_ROLE: ${{ secrets.AWS_PUSH_TO_ECR_OIDC_ROLE }}
      AWS_DEFAULT_REGION: ${{ secrets.AWS_DEFAULT_REGION }}
      AWS_ACCOUNT_ID: ${{ secrets.AWS_ACCOUNT_ID }}
```

> Replace `your-org/dce-build-and-push` and `@v1` with your actual organization/repository and release tag.

A ready-to-copy example is also available at `examples/caller-build-and-push.yml`.

### Version command examples

- Node.js: `jq -r .version ./app/package.json`
- Python: `python -m doki.version`
- PHP (Composer): `jq -r .version composer.json`

`version_command` is required and should print a single version string to stdout.

## Resolving action refs to SHAs

Use `zizmor` to detect unpinned references, then resolve each action ref with:

```sh
scripts/action-ref-sha.sh <owner/repo> [ref]
```

Examples:

```sh
scripts/action-ref-sha.sh actions/checkout v6
scripts/action-ref-sha.sh docker/build-push-action v6
scripts/action-ref-sha.sh aws-actions/configure-aws-credentials main
scripts/action-ref-sha.sh actions/checkout
```

If `[ref]` is omitted, the script resolves the latest tag.
For release-safe pinning, pass an explicit release tag such as `v2`.

The script outputs only the resolved 40-character SHA.

## Versioning recommendation

Tag stable releases and pin consumers to tags (for example `@v1`, `@v1.2.0`) to control rollout across projects.
