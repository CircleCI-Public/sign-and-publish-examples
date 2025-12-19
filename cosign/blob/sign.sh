#!/bin/bash

# sign artifact
#
# usage: sign.sh <artifact>
#
# artifact: path to artifact to sign
#
# Environment variables:
#   SIGSTORE_ENV - "staging" or "production" (default: production)
#
# example: sign.sh ./artifact
# example: SIGSTORE_ENV=staging sign.sh ./artifact

if [ "$#" -ne 1 ]; then
    echo "Usage: sign.sh <artifact>"
    exit 1
fi

artifact="$1"

# Default to production
SIGSTORE_ENV="${SIGSTORE_ENV:-production}"

echo "Using SIGSTORE_ENV: $SIGSTORE_ENV"

if [ "$SIGSTORE_ENV" = "staging" ]; then
  TUF_MIRROR="https://tuf-repo-cdn.sigstage.dev"
  TUF_ROOT="https://tuf-repo-cdn.sigstage.dev/root.json"
  # use of cosign initialize requires use of root sha256
  # to regen this value curl -s https://tuf-repo-cdn.sigstage.dev/root.json | shasum -a 256
  TUF_ROOT_SHA256="bde9c2949e64d059c18d8f93566a64dafc6d2e8e259a70322fb804831dfd0b5b"
  FULCIO_URL="https://fulcio.sigstage.dev"
  REKOR_URL="https://rekor.sigstage.dev"
else
  # Production uses default TUF root (no initialization needed)
  TUF_MIRROR=""
  TUF_ROOT=""
  TUF_ROOT_SHA256=""
  FULCIO_URL="https://fulcio.sigstore.dev"
  REKOR_URL="https://rekor.sigstore.dev"
fi

export SIGSTORE_ID_TOKEN=$(circleci run oidc get --claims '{"aud": "sigstore"}')

# Initialize TUF root if using staging
if [ -n "$TUF_MIRROR" ]; then
  cosign initialize --mirror="$TUF_MIRROR" --root="$TUF_ROOT" --root-checksum="$TUF_ROOT_SHA256"
fi

cosign sign-blob "${artifact}" \
  --fulcio-url "$FULCIO_URL" \
  --rekor-url "$REKOR_URL" \
  --oidc-issuer "https://oidc.circleci.com/org/${CIRCLE_ORGANIZATION_ID}" \
  --yes \
  --bundle "${artifact}.bundle" \
  --use-signing-config=false



