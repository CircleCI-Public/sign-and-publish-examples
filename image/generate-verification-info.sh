#!/bin/bash

# Generate verification info file for a signed container image
#
# usage: generate-verification-info.sh <image> <output>
#
# image: the signed image reference (tag or digest)
# output: path to output verification info JSON
#
# Environment variables:
#   SIGSTORE_ENV - "staging" or "production" (default: production)
#   PIPELINE_DEFINITION_ID - required
#
# example: generate-verification-info.sh ttl.sh/myimage:1h ./verification.json

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: generate-verification-info.sh <image> <output>"
    exit 1
fi

image="$1"
output="$2"

SIGSTORE_ENV="${SIGSTORE_ENV:-production}"

if [ -z "${PIPELINE_DEFINITION_ID:-}" ]; then
  echo "Error: PIPELINE_DEFINITION_ID is required"
  exit 1
fi

if [ "$SIGSTORE_ENV" = "staging" ]; then
  rekor_search_base="https://search.sigstage.dev"
  rekor_url="https://rekor.sigstage.dev"
else
  rekor_search_base="https://search.sigstore.dev"
  rekor_url="https://rekor.sigstore.dev"
fi

oidc_issuer="https://oidc.circleci.com/org/${CIRCLE_ORGANIZATION_ID}"
certificate_identity="https://circleci.com/api/v2/projects/${CIRCLE_PROJECT_ID}/pipeline-definitions/${PIPELINE_DEFINITION_ID}"

# First verify the image (this validates the signature)
echo "Verifying image signature..."
cosign verify "$image" \
  --certificate-oidc-issuer "$oidc_issuer" \
  --certificate-identity "$certificate_identity" \
  --rekor-url "$rekor_url" > /dev/null 2>&1 || {
    echo "Error: Image verification failed"
    exit 1
  }
echo "Verification successful"

# Show signature tree
echo "DEBUG: cosign tree output:"
cosign tree "$image" 2>&1 || true

# Download the signature to get full bundle data
echo "DEBUG: running cosign download signature..."
sig_data=$(cosign download signature "$image" 2>&1 | head -1)

echo "DEBUG: sig_data length: ${#sig_data}"
echo "DEBUG: sig_data first 500 chars:"
echo "${sig_data:0:500}"
echo "DEBUG: sig_data keys:"
echo "$sig_data" | jq 'keys' 2>/dev/null || echo "DEBUG: failed to parse sig_data as JSON"

# Initialize variables
log_index=""
rekor_search_url=""
source_repo_uri=""
source_repo_ref=""
build_signer_uri=""
runner_env=""

if [ -n "$sig_data" ]; then
  # Check bundle format - new v0.3 format vs legacy format
  media_type=$(echo "$sig_data" | jq -r '.mediaType // ""' 2>/dev/null || true)

  if [[ "$media_type" == *"sigstore.bundle"* ]]; then
    # New Sigstore bundle v0.3 format
    echo "DEBUG: Using new bundle v0.3 format"

    # Extract log index from verificationMaterial.tlogEntries[0].logIndex
    log_index=$(echo "$sig_data" | jq -r '.verificationMaterial.tlogEntries[0].logIndex // ""' 2>/dev/null || true)
    echo "DEBUG: log_index=$log_index"

    # Extract certificate from verificationMaterial.certificate.rawBytes (base64 DER)
    cert_raw=$(echo "$sig_data" | jq -r '.verificationMaterial.certificate.rawBytes // ""' 2>/dev/null || true)
  else
    # Legacy format
    echo "DEBUG: Using legacy bundle format"
    log_index=$(echo "$sig_data" | jq -r '.Bundle.Payload.logIndex // ""' 2>/dev/null || true)
    cert_raw=$(echo "$sig_data" | jq -r '.Cert.Raw // ""' 2>/dev/null || true)
  fi

  echo "DEBUG: log_index=$log_index"
  echo "DEBUG: cert_raw length=${#cert_raw}"

  # Decode cert and extract OID extensions using openssl
  if [ -n "$cert_raw" ]; then
    cert_text=$(echo "$cert_raw" | base64 -d 2>/dev/null | openssl x509 -inform DER -text -noout 2>/dev/null || true)

    if [ -n "$cert_text" ]; then
      echo "DEBUG: cert_text length=${#cert_text}"

      # Extract OID values - strip DER encoding prefixes
      source_repo_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.12:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
      source_repo_ref=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.14:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
      build_signer_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.9:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^h]*//' || true)
      runner_env=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.11:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
    fi
  fi

  echo "DEBUG: source_repo_uri=$source_repo_uri"
  echo "DEBUG: source_repo_ref=$source_repo_ref"
  echo "DEBUG: build_signer_uri=$build_signer_uri"
  echo "DEBUG: runner_env=$runner_env"
fi

# Build Rekor search URL if we have a log index
if [ -n "$log_index" ]; then
  rekor_search_url="${rekor_search_base}/?logIndex=${log_index}"
fi

# Generate verification info JSON using jq for proper escaping
jq -n \
  --arg image "$image" \
  --arg signed_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg sigstore_environment "$SIGSTORE_ENV" \
  --arg log_index "$log_index" \
  --arg rekor_search_url "$rekor_search_url" \
  --arg certificate_identity "$certificate_identity" \
  --arg certificate_oidc_issuer "$oidc_issuer" \
  --arg source_repository_uri "$source_repo_uri" \
  --arg source_repository_ref "$source_repo_ref" \
  --arg build_signer_uri "$build_signer_uri" \
  --arg runner_environment "$runner_env" \
  '{
    image: $image,
    signed_at: $signed_at,
    sigstore_environment: $sigstore_environment,
    transparency_log: {
      log_index: (if $log_index == "" then null else ($log_index | tonumber) end),
      search_url: $rekor_search_url
    },
    verification: {
      certificate_identity: $certificate_identity,
      certificate_oidc_issuer: $certificate_oidc_issuer
    },
    provenance: {
      source_repository_uri: $source_repository_uri,
      source_repository_ref: $source_repository_ref,
      build_signer_uri: $build_signer_uri,
      runner_environment: $runner_environment
    },
    verify_command: ("cosign verify " + $image + " --certificate-identity=\u0027" + $certificate_identity + "\u0027 --certificate-oidc-issuer=\u0027" + $certificate_oidc_issuer + "\u0027")
  }' > "$output"

echo "Verification info written to: $output"
