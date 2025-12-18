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
else
  rekor_search_base="https://search.sigstore.dev"
fi

oidc_issuer="https://oidc.circleci.com/org/${CIRCLE_ORGANIZATION_ID}"
certificate_identity="https://circleci.com/api/v2/projects/${CIRCLE_PROJECT_ID}/pipeline-definitions/${PIPELINE_DEFINITION_ID}"

# Initialize variables
log_index=""
rekor_search_url=""
source_repo_uri=""
source_repo_ref=""
build_signer_uri=""
runner_env=""

# Verify and capture the output which includes certificate and tlog info
# cosign verify --output-json returns JSON with verification details
verify_output=$(cosign verify "$image" \
  --certificate-oidc-issuer "$oidc_issuer" \
  --certificate-identity "$certificate_identity" \
  --output-json 2>/dev/null || echo "[]")

if [ "$verify_output" != "[]" ] && [ -n "$verify_output" ]; then
  # Try to extract log index from the bundle in verification output
  # The structure varies, so we try multiple paths
  log_index=$(echo "$verify_output" | jq -r '.[0].optional.Bundle.Payload.logIndex // .[0].bundle.Payload.logIndex // ""' 2>/dev/null || true)
  
  # Extract the certificate from the verification output
  # cosign verify --output-json includes the cert in various locations depending on version
  cert_base64=$(echo "$verify_output" | jq -r '
    .[0].optional.Bundle.Payload.body // "" | 
    if . != "" then (. | @base64d | fromjson | .spec.signature.publicKey.content // "") else "" end
  ' 2>/dev/null || true)
  
  # If that didn't work, try another path
  if [ -z "$cert_base64" ]; then
    cert_base64=$(echo "$verify_output" | jq -r '.[0].optional.bundle.verificationMaterial.certificate.rawBytes // ""' 2>/dev/null || true)
  fi
  
  if [ -n "$cert_base64" ]; then
    # Decode and extract certificate extensions
    cert_text=$(echo "$cert_base64" | base64 -d 2>/dev/null | openssl x509 -inform DER -text -noout 2>/dev/null || true)
    
    if [ -n "$cert_text" ]; then
      # Extract OID values - strip DER encoding prefixes
      source_repo_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.12:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
      source_repo_ref=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.14:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
      build_signer_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.9:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^h]*//' || true)
      runner_env=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.11:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
    fi
  fi
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
