# AGENTS.md - sign-and-publish-examples

## Project Overview
Repository of CircleCI examples demonstrating signing and publishing artifacts with various tools. Each example shows a complete workflow from CircleCI to signing to verification.

## Architecture & Structure
Each example is self-contained in its own directory:
- **`cosign/`** - Sigstore/cosign example (bash scripts)
  - `blob/` - Blob artifact signing & verification
  - `image/` - Container image signing & verification
  - `validate-verification-info.sh` - Policy validation
  - `README.md` - Example-specific documentation
- **`pypi/`** - PyPI publishing example (Python; in development)
- **`.circleci/config.yml`** - Shared CircleCI pipeline
- **`_local/`** - Local development utilities

## Build/Test/Lint Commands
**Cosign example:**
- Local sign: `./cosign/blob/sign.sh <artifact>` (requires cosign, OIDC)
- Verify: `./cosign/blob/verify.sh <artifact> <bundle>`
- Install cosign: `go install github.com/sigstore/cosign/v3/cmd/cosign@v3.0.3`
- Run workflows: Push to trigger `.circleci/config.yml` (main=production, others=staging)

**PyPI example:**
- Add commands as example develops

## Code Style & Conventions
**Cosign (Bash):**
- POSIX-compatible scripts, kebab-case filenames
- `${VAR:-default}` for optional env vars, UPPER_CASE for env var names
- Exit 1 on usage errors; validate args at start, handle errors via `set -e`
- Document usage in script headers with examples
- Branch-based env selection: main=production, others=staging

**PyPI (Python):**
- Use black for code formatting
- Follow Python conventions when implemented

## Workflow to follow
- Always use conventional commits
- Always commit your work after its validated
- Always keep things simple and readable
