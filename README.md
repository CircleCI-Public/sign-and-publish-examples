# sign-and-publish-examples

Examples of signing and verifying artifacts using [Sigstore](https://www.sigstore.dev/) with CircleCI OIDC tokens.

## Overview

This project demonstrates how to use **cosign** to sign blob artifacts in CircleCI pipelines using keyless signing with Sigstore. It supports both production and staging Sigstore environments.

## Project Structure

- **`blob/sign.sh`** - Script to sign a blob artifact using cosign
- **`blob/verify.sh`** - Script to verify a signed blob artifact
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

## CircleCI Workflow

The pipeline automatically selects the Sigstore environment based on branch:

- **`main` branch** → Production Sigstore
- **Other branches** → Staging Sigstore

## Certificate Identity

When verifying, the certificate identity follows this format:

```
https://circleci.com/api/v2/projects/<PROJECT_ID>/pipeline-definitions/<PIPELINE_DEFINITION_ID>
```

The OIDC issuer follows this format:

```
https://oidc.circleci.com/org/<ORGANIZATION_ID>
```
