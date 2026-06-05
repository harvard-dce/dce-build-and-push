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

The primary purpose of this repository is to provide a single shared build-and-push workflow that application repositories can reuse.
In most cases, caller repositories only need the `reusable-build-and-push.yml` workflow.

In each consuming repository, add a workflow under `.github/workflows/`:

```yaml
name: Build and Push Image to ECR

on:
  workflow_dispatch:
  push:
    branches: [main, stage, "*/*"]

jobs:
  build_and_push:
    uses: harvard-dce/dce-build-and-push/.github/workflows/reusable-build-and-push.yml@v1
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

> Replace `harvard-dce/dce-build-and-push` and `@v1` with your actual organization/repository and release tag.

A ready-to-copy example is also available at `examples/caller-build-and-push.yml`.

### Optional: caller-side zizmor workflow

Reusing `.github/workflows/zizmor.yml` from this repository is optional for callers.
A caller typically only needs this if it has additional workflows of its own that should be scanned.

If you enable it in a caller repository, expect to do some caller-specific setup over time (for example a local `zizmor.yml`/`.github/zizmor.yml` to tune or ignore rules for that repository).

```yaml
jobs:
  zizmor:
    uses: harvard-dce/dce-build-and-push/.github/workflows/zizmor.yml@v1
```

### Version command examples

- Node.js: `jq -r .version ./app/package.json`
- Python: `python -m doki.version`
- PHP (Composer): `jq -r .version composer.json`

`version_command` is required and should print a single version string to stdout.

## Resolving action refs to SHAs

Use `zizmor` to detect unpinned references, then resolve each action ref with:

```sh
scripts/action-ref-sha.sh
scripts/action-ref-sha.sh <owner/repo> [ref]
```

Examples:

```sh
# Resolve all action@tag entries from .github/action-pins.txt
scripts/action-ref-sha.sh

# Resolve one action ref
scripts/action-ref-sha.sh actions/checkout v6
scripts/action-ref-sha.sh docker/build-push-action v6
scripts/action-ref-sha.sh aws-actions/configure-aws-credentials main
scripts/action-ref-sha.sh actions/checkout
```

With no args, the script outputs `action tag sha` lines for every entry in `.github/action-pins.txt`.
If `[ref]` is omitted in single-action mode, the script resolves the latest tag.
For release-safe pinning, pass an explicit release tag such as `v2`.

## Supply-chain maintenance pattern

- Runtime workflows stay pinned to immutable SHAs (`uses: owner/repo@<40-char-sha>`).
- `.github/workflows/actions-inventory.yml` is an intentionally disabled inventory workflow that tracks semver/tag refs for advisory visibility.
- `.github/action-pins.txt` is the source-of-truth map of `action tag sha`.
- `.github/workflows/check-action-pin-consistency.yml` enforces synchronization between tag refs in inventory and SHA refs in runtime workflows.
- To update pins, resolve tags to SHAs with:

```sh
scripts/action-ref-sha.sh <owner/repo> <tag>
```

Then update `.github/action-pins.txt` and corresponding pinned `uses:` entries.

### Example: update one action pin

```sh
# 1) Resolve the SHA for the desired tag
scripts/action-ref-sha.sh docker/build-push-action v6

# 2) Update .github/action-pins.txt line:
# docker/build-push-action v6 <new_sha>

# 3) Update pinned workflow refs to the same <new_sha>
#    (for example in .github/workflows/reusable-build-and-push.yml)

# 4) Validate consistency
scripts/check-action-pin-consistency.sh
```

The script outputs only the resolved 40-character SHA.

## Versioning recommendation

Tag stable releases and pin consumers to tags (for example `@v1`, `@v1.2.0`) to control rollout across projects.
