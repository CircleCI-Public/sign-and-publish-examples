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

if [ "$#" -ne 2 ]; then
    echo "Usage: generate-verification-info.sh <image> <output>"
    exit 1
fi

image="$1"
output="$2"

SIGSTORE_ENV="${SIGSTORE_ENV:-production}"

if [ -z "$PIPELINE_DEFINITION_ID" ]; then
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

# Verify and capture the output which includes certificate and tlog info
# cosign verify returns JSON array with verification details including the certificate
verify_output=$(cosign verify "$image" \
  --certificate-oidc-issuer "$oidc_issuer" \
  --certificate-identity "$certificate_identity" \
  --output-json 2>/dev/null)

# Extract log index from verification output
log_index=$(echo "$verify_output" | jq -r '.[0].optional.Bundle.Payload.logIndex // empty' 2>/dev/null)

if [ -n "$log_index" ] && [ "$log_index" != "null" ]; then
  rekor_search_url="${rekor_search_base}/?logIndex=${log_index}"
  log_index_json="$log_index"
else
  rekor_search_url=""
  log_index_json="null"
fi

# Extract certificate from verification output and decode provenance claims
# The certificate contains OIDC claims mapped to X.509 extensions (Fulcio OIDs)
cert_pem=$(echo "$verify_output" | jq -r '.[0].optional.Bundle.Payload.body' 2>/dev/null | base64 -d 2>/dev/null | jq -r '.spec.signature.publicKey.content // empty' 2>/dev/null)
if [ -n "$cert_pem" ]; then
  cert_text=$(echo "$cert_pem" | base64 -d | openssl x509 -inform DER -text -noout 2>/dev/null)
  
  # Extract Source Repository URI (OID 1.3.6.1.4.1.57264.1.12) - contains vcs-origin
  source_repo_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.12" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '\0' || echo "")
  
  # Extract Source Repository Ref (OID 1.3.6.1.4.1.57264.1.14) - contains vcs-ref (branch/tag)
  source_repo_ref=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.14" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '\0' || echo "")
  
  # Extract Build Signer URI (OID 1.3.6.1.4.1.57264.1.9)
  build_signer_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.9" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '\0' || echo "")
  
  # Extract Runner Environment (OID 1.3.6.1.4.1.57264.1.11)
  runner_env=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.11" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '\0' || echo "")
fi

# Generate verification info JSON
# This file contains everything a user needs to:
# 1. Verify the signature (certificate_identity + certificate_oidc_issuer)
# 2. Validate provenance claims (source_repository, source_ref, build_signer)
cat > "$output" << EOF
{
  "image": "${image}",
  "signed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "sigstore_environment": "${SIGSTORE_ENV}",
  "transparency_log": {
    "log_index": ${log_index_json},
    "search_url": "${rekor_search_url}"
  },
  "verification": {
    "certificate_identity": "${certificate_identity}",
    "certificate_oidc_issuer": "${oidc_issuer}"
  },
  "provenance": {
    "source_repository_uri": "${source_repo_uri:-}",
    "source_repository_ref": "${source_repo_ref:-}",
    "build_signer_uri": "${build_signer_uri:-}",
    "runner_environment": "${runner_env:-}"
  },
  "verify_command": "cosign verify ${image} --certificate-identity='${certificate_identity}' --certificate-oidc-issuer='${oidc_issuer}'"
}
EOF

echo "Verification info written to: $output"
