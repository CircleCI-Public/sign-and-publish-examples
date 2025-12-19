#!/bin/bash

# verify image
#
# usage: verify.sh <image>
#
# image: path to image to verify
#
# Environment variables:
#   SIGSTORE_ENV - "staging" or "production" (default: production)
#   PIPELINE_DEFINITION_ID - required, get from CCI Project Setup
#
# example: verify.sh ttl.sh/00000000-0000-0000-0000-000000000000:1h
# example: SIGSTORE_ENV=staging verify.sh ttl.sh/00000000-0000-0000-0000-000000000000:1h

if [ "$#" -ne 1 ]; then
    echo "Usage: verify.sh <image>"
    exit 1
fi

image="$1"

# Default to production
SIGSTORE_ENV="${SIGSTORE_ENV:-production}"

# You will have to get this info from your CCI Project Setup
if [ -z "$PIPELINE_DEFINITION_ID" ]; then
  echo "Error: PIPELINE_DEFINITION_ID is required"
  exit 1
fi

echo "Using SIGSTORE_ENV: $SIGSTORE_ENV"

if [ "$SIGSTORE_ENV" = "staging" ]; then
  TUF_MIRROR="https://tuf-repo-cdn.sigstage.dev"
  TUF_ROOT="https://tuf-repo-cdn.sigstage.dev/root.json"
  # use of cosign initialize requires use of root sha256
  # to regen this value curl -s https://tuf-repo-cdn.sigstage.dev/root.json | shasum -a 256
  TUF_ROOT_SHA256="bde9c2949e64d059c18d8f93566a64dafc6d2e8e259a70322fb804831dfd0b5b"
  REKOR_URL="https://rekor.sigstage.dev"
else
  # Production uses default TUF root (no initialization needed)
  TUF_MIRROR=""
  TUF_ROOT=""
  TUF_ROOT_SHA256=""
  REKOR_URL="https://rekor.sigstore.dev"
fi

# Initialize TUF root if using staging
if [ -n "$TUF_MIRROR" ]; then
  cosign initialize --mirror="$TUF_MIRROR" --root="$TUF_ROOT" --root-checksum="$TUF_ROOT_SHA256"
fi

cosign verify "${image}" \
  --rekor-url "$REKOR_URL" \
  --certificate-oidc-issuer "https://oidc.circleci.com/org/${CIRCLE_ORGANIZATION_ID}" \
  --certificate-identity "https://circleci.com/api/v2/projects/${CIRCLE_PROJECT_ID}/pipeline-definitions/${PIPELINE_DEFINITION_ID}"
