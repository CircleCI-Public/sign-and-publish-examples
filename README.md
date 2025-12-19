# sign-and-publish-examples

Examples of signing and verifying artifacts using [Sigstore](https://www.sigstore.dev/) with CircleCI OIDC tokens.

## Overview

This project demonstrates how to use **cosign** to sign both blob artifacts and container images in CircleCI pipelines using keyless signing with Sigstore. It supports both production and staging Sigstore environments.

## Project Structure

- **`blob/sign.sh`** - Script to sign a blob artifact using cosign
- **`blob/verify.sh`** - Script to verify a signed blob artifact
- **`blob/generate-verification-info.sh`** - Generate verification info JSON with provenance claims
- **`image/sign.sh`** - Script to sign a container image using cosign
- **`image/verify.sh`** - Script to verify a signed container image
- **`image/generate-verification-info.sh`** - Generate verification info JSON with provenance claims
- **`validate-verification-info.sh`** - Validate provenance policies (e.g., reject SSH reruns)
- **`.circleci/config.yml`** - CircleCI pipeline configuration

## How It Works

1. CircleCI generates an OIDC token for the pipeline
2. The OIDC token is exchanged with Fulcio for a short-lived signing certificate
3. Cosign signs the artifact and records the signature in Rekor (transparency log)
4. A bundle file is produced containing the signature and verification material
5. Verification uses the bundle to validate the artifact's authenticity

## Environment Variables

| Variable                 | Description                                                    |
| ------------------------ | -------------------------------------------------------------- |
| `SIGSTORE_ENV`           | `staging` or `production` (default: production)                |
| `PIPELINE_DEFINITION_ID` | Required for verification - get from CircleCI Project Settings |
| `CIRCLE_ORGANIZATION_ID` | Automatically set by CircleCI                                  |
| `CIRCLE_PROJECT_ID`      | Automatically set by CircleCI                                  |

## Usage

### Signing

```bash
# Production (default)
./blob/sign.sh ./artifact

# Staging
SIGSTORE_ENV=staging ./blob/sign.sh ./artifact
```

### Verifying

```bash
# Production (default)
PIPELINE_DEFINITION_ID=<your-id> ./blob/verify.sh ./artifact ./artifact.bundle

# Staging
SIGSTORE_ENV=staging PIPELINE_DEFINITION_ID=<your-id> ./blob/verify.sh ./artifact ./artifact.bundle
```

### Generating Verification Info

After signing and verifying, generate a verification info JSON file:

```bash
# For blobs
./blob/generate-verification-info.sh ./artifact ./artifact.bundle ./artifact.verification.json

# For images
./image/generate-verification-info.sh ttl.sh/my-image:1h ./image-verification.json
```

### Validating Policies

Validate the verification info against security policies:

```bash
./validate-verification-info.sh ./artifact.verification.json
```

This script validates the provenance claims and rejects artifacts that don't meet policy requirements. By default, it rejects artifacts signed during SSH debug sessions (`runner_environment = "ssh-rerun"`).

You can extend the script to enforce additional policies like requiring specific branches or repositories.

### Container Image Signing

```bash
# Sign an image (production)
./image/sign.sh ttl.sh/my-image:1h

# Sign an image (staging)
SIGSTORE_ENV=staging ./image/sign.sh ttl.sh/my-image:1h
```

### Container Image Verification

```bash
# Verify an image (production)
PIPELINE_DEFINITION_ID=<your-id> ./image/verify.sh ttl.sh/my-image:1h

# Verify an image (staging)
SIGSTORE_ENV=staging PIPELINE_DEFINITION_ID=<your-id> ./image/verify.sh ttl.sh/my-image:1h
```

## CircleCI Workflows

The pipeline includes two workflows:

### Blob Sign Workflow

Signs and verifies blob artifacts, generates verification info, and validates policies.

### Container Sign Workflow

Signs and verifies container images using [ttl.sh](https://ttl.sh) for ephemeral test images, generates verification info, and validates policies.

Both workflows automatically select the Sigstore environment based on branch:

- **`main` branch** → Production Sigstore
- **Other branches** → Staging Sigstore

You can see the example pipeline running here: https://app.circleci.com/pipelines/github/CircleCI-Public/sign-and-publish-examples

## Verification Info Files

After signing, the pipeline generates a verification info JSON file that contains everything consumers need to verify your artifacts. This includes both verification parameters and provenance claims extracted from the certificate.

### Example Verification Info

```json
{
  "artifact": "my-release.tar.gz",
  "artifact_digest": "sha256:abc123...",
  "signature_bundle": "my-release.tar.gz.bundle",
  "signed_at": "2024-01-15T10:30:00Z",
  "sigstore_environment": "production",
  "transparency_log": {
    "log_index": 12345678,
    "search_url": "https://search.sigstore.dev/?logIndex=12345678"
  },
  "verification": {
    "certificate_identity": "https://circleci.com/api/v2/projects/.../pipeline-definitions/...",
    "certificate_oidc_issuer": "https://oidc.circleci.com/org/..."
  },
  "provenance": {
    "source_repository_uri": "https://github.com/your-org/your-repo",
    "source_repository_ref": "refs/heads/main",
    "build_signer_uri": "https://circleci.com/api/v2/projects/.../pipeline-definitions/...",
    "runner_environment": "circleci-hosted"
  },
  "verify_command": "cosign verify-blob ..."
}
```

## Certificate Identity

When verifying, the certificate identity follows this format:

```
https://circleci.com/api/v2/projects/<PROJECT_ID>/pipeline-definitions/<PIPELINE_DEFINITION_ID>
```

The OIDC issuer follows this format:

```
https://oidc.circleci.com/org/<ORGANIZATION_ID>
```

## Provenance Claims (Certificate Extensions)

CircleCI OIDC claims are embedded as X.509 certificate extensions by Fulcio. Consumers can validate these to verify provenance:

| Claim                 | Fulcio OID             | Description                       | Example Value                           |
| --------------------- | ---------------------- | --------------------------------- | --------------------------------------- |
| Source Repository URI | 1.3.6.1.4.1.57264.1.12 | Repository the build was based on | `https://github.com/your-org/your-repo` |
| Source Repository Ref | 1.3.6.1.4.1.57264.1.14 | Branch or tag                     | `refs/heads/main`                       |
| Build Signer URI      | 1.3.6.1.4.1.57264.1.9  | Pipeline definition that signed   | CircleCI pipeline definition URL        |
| Runner Environment    | 1.3.6.1.4.1.57264.1.11 | Where build ran                   | `circleci-hosted` or `ssh-rerun`        |

### Validating Provenance (e.g., "Was this built from main?")

Users can validate specific claims using cosign's `--certificate-identity-regexp` or by inspecting the certificate:

```bash
# Verify and ensure it came from main branch
cosign verify-blob artifact.txt \
  --bundle artifact.txt.bundle \
  --certificate-oidc-issuer "https://oidc.circleci.com/org/<ORG_ID>" \
  --certificate-identity "https://circleci.com/api/v2/projects/<PROJECT_ID>/pipeline-definitions/<DEF_ID>"

# Then inspect the certificate to check the branch:
cat artifact.txt.bundle | jq -r '.verificationMaterial.certificate.rawBytes' | \
  base64 -d | openssl x509 -inform DER -text -noout | \
  grep -A1 "1.3.6.1.4.1.57264.1.14"  # Source Repository Ref
```

For a simpler workflow, consumers can check the `provenance` section in the verification info JSON file and compare against their policy requirements before running the verify command.

### Why This Matters

This allows consumers to enforce policies like:

- **Only accept artifacts built from `main` branch** — check `source_repository_ref`
- **Only accept artifacts from a specific repository** — check `source_repository_uri`
- **Reject SSH debug session builds** — check `runner_environment`

The `validate-verification-info.sh` script demonstrates this by rejecting artifacts where `runner_environment` is `ssh-rerun`. You can extend it to add your own policy requirements.
