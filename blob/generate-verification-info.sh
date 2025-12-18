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

if [ "$#" -ne 3 ]; then
    echo "Usage: generate-verification-info.sh <artifact> <bundle> <output>"
    exit 1
fi

artifact="$1"
bundle="$2"
output="$3"

SIGSTORE_ENV="${SIGSTORE_ENV:-production}"

if [ -z "$PIPELINE_DEFINITION_ID" ]; then
  echo "Error: PIPELINE_DEFINITION_ID is required"
  exit 1
fi

# Extract info from bundle
log_index=$(jq -r '.verificationMaterial.tlogEntries[0].logIndex // empty' "$bundle")

# Calculate artifact digest
artifact_digest="sha256:$(shasum -a 256 "$artifact" | cut -d' ' -f1)"

# Extract certificate and decode claims embedded in it
# The certificate contains OIDC claims mapped to X.509 extensions (Fulcio OIDs)
cert_base64=$(jq -r '.verificationMaterial.certificate.rawBytes // empty' "$bundle")
if [ -n "$cert_base64" ]; then
  # Extract certificate extensions using openssl
  cert_text=$(echo "$cert_base64" | base64 -d | openssl x509 -inform DER -text -noout 2>/dev/null)
  
  # Extract Source Repository URI (OID 1.3.6.1.4.1.57264.1.12) - contains vcs-origin
  source_repo_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.12" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '\0' || echo "")
  
  # Extract Source Repository Ref (OID 1.3.6.1.4.1.57264.1.14) - contains vcs-ref (branch/tag)
  source_repo_ref=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.14" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '\0' || echo "")
  
  # Extract Build Signer URI (OID 1.3.6.1.4.1.57264.1.9)
  build_signer_uri=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.9" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '\0' || echo "")
  
  # Extract Runner Environment (OID 1.3.6.1.4.1.57264.1.11)
  runner_env=$(echo "$cert_text" | grep -A1 "1.3.6.1.4.1.57264.1.11" | tail -1 | sed 's/^[[:space:]]*//' | tr -d '\0' || echo "")
fi

# Build Rekor search URL
if [ "$SIGSTORE_ENV" = "staging" ]; then
  rekor_search_url="https://search.sigstage.dev/?logIndex=${log_index}"
else
  rekor_search_url="https://search.sigstore.dev/?logIndex=${log_index}"
fi

oidc_issuer="https://oidc.circleci.com/org/${CIRCLE_ORGANIZATION_ID}"
certificate_identity="https://circleci.com/api/v2/projects/${CIRCLE_PROJECT_ID}/pipeline-definitions/${PIPELINE_DEFINITION_ID}"

# Generate verification info JSON
# This file contains everything a user needs to:
# 1. Verify the signature (certificate_identity + certificate_oidc_issuer)
# 2. Validate provenance claims (source_repository, source_ref, build_signer)
cat > "$output" << EOF
{
  "artifact": "$(basename "$artifact")",
  "artifact_digest": "${artifact_digest}",
  "signature_bundle": "$(basename "$bundle")",
  "signed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "sigstore_environment": "${SIGSTORE_ENV}",
  "transparency_log": {
    "log_index": ${log_index:-null},
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
  "verify_command": "cosign verify-blob $(basename "$artifact") --bundle $(basename "$bundle") --certificate-identity='${certificate_identity}' --certificate-oidc-issuer='${oidc_issuer}'"
}
EOF

echo "Verification info written to: $output"
