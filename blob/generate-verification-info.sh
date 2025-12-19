#!/bin/bash

# Generate verification info file for a signed blob
#
# usage: generate-verification-info.sh <artifact> <bundle> <output>
#
# artifact: path to the signed artifact
# bundle: path to the bundle file
# output: path to output verification info JSON
#
# Environment variables:
#   SIGSTORE_ENV - "staging" or "production" (default: production)
#   PIPELINE_DEFINITION_ID - required
#
# example: generate-verification-info.sh ./artifact ./artifact.bundle ./verification.json

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: generate-verification-info.sh <artifact> <bundle> <output>"
    exit 1
fi

artifact="$1"
bundle="$2"
output="$3"

SIGSTORE_ENV="${SIGSTORE_ENV:-production}"

if [ -z "${PIPELINE_DEFINITION_ID:-}" ]; then
  echo "Error: PIPELINE_DEFINITION_ID is required"
  exit 1
fi

# Extract info from bundle
log_index=$(jq -r '.verificationMaterial.tlogEntries[0].logIndex // ""' "$bundle")

# Calculate artifact digest
artifact_digest="sha256:$(shasum -a 256 "$artifact" | cut -d' ' -f1)"

# Initialize provenance variables
source_repo_uri=""
source_repo_ref=""
build_signer_uri=""
runner_env=""

# Extract certificate and decode claims embedded in it
# The certificate contains OIDC claims mapped to X.509 extensions (Fulcio OIDs)
cert_base64=$(jq -r '.verificationMaterial.certificate.rawBytes // ""' "$bundle")
if [ -n "$cert_base64" ]; then
  # Extract certificate extensions using openssl
  cert_text=$(echo "$cert_base64" | base64 -d | openssl x509 -inform DER -text -noout 2>/dev/null || true)
  
  if [ -n "$cert_text" ]; then
    # Extract OID values - they have DER encoding prefixes we need to strip
    # The format is: "1.3.6.1.4.1.57264.1.X:\n                <prefix><value>"
    
    # Source Repository URI (OID 1.3.6.1.4.1.57264.1.12) - contains vcs-origin
    source_repo_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.12:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
    
    # Source Repository Ref (OID 1.3.6.1.4.1.57264.1.14) - contains vcs-ref (branch/tag)
    source_repo_ref=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.14:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
    
    # Build Signer URI (OID 1.3.6.1.4.1.57264.1.9)
    build_signer_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.9:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^h]*//' || true)
    
    # Runner Environment (OID 1.3.6.1.4.1.57264.1.11)
    runner_env=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.11:" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/^[^a-zA-Z]*//' || true)
  fi
fi

# Build Rekor search URL
if [ "$SIGSTORE_ENV" = "staging" ]; then
  rekor_search_base="https://search.sigstage.dev"
else
  rekor_search_base="https://search.sigstore.dev"
fi

if [ -n "$log_index" ]; then
  rekor_search_url="${rekor_search_base}/?logIndex=${log_index}"
else
  rekor_search_url=""
fi

oidc_issuer="https://oidc.circleci.com/org/${CIRCLE_ORGANIZATION_ID}"
certificate_identity="https://circleci.com/api/v2/projects/${CIRCLE_PROJECT_ID}/pipeline-definitions/${PIPELINE_DEFINITION_ID}"

# Generate verification info JSON using jq for proper escaping
jq -n \
  --arg artifact "$(basename "$artifact")" \
  --arg artifact_digest "$artifact_digest" \
  --arg signature_bundle "$(basename "$bundle")" \
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
    artifact: $artifact,
    artifact_digest: $artifact_digest,
    signature_bundle: $signature_bundle,
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
    verify_command: ("cosign verify-blob " + $artifact + " --bundle " + $signature_bundle + " --certificate-identity=\u0027" + $certificate_identity + "\u0027 --certificate-oidc-issuer=\u0027" + $certificate_oidc_issuer + "\u0027")
  }' > "$output"

echo "Verification info written to: $output"
