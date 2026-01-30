#!/bin/bash

# Validate verification info against security policies
#
# usage: validate-verification-info.sh <verification-json>
#
# verification-json: path to the verification info JSON file
#
# This script demonstrates policy validation using the verification info.
# It checks the provenance claims and rejects artifacts that don't meet policy.
#
# Current policies:
#   - Reject artifacts signed during SSH debug sessions (runner_environment = "ssh-rerun")
#
# Exit codes:
#   0 - All policies passed
#   1 - Policy violation detected

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: validate-verification-info.sh <verification-json>"
    exit 1
fi

verification_json="$1"

if [ ! -f "$verification_json" ]; then
    echo "Error: Verification file not found: $verification_json"
    exit 1
fi

echo "Validating policies for: $verification_json"

# Extract verification fields
certificate_oidc_issuer=$(jq -r '.verification.certificate_oidc_issuer // ""' "$verification_json")

# Extract provenance fields
runner_environment=$(jq -r '.provenance.runner_environment // ""' "$verification_json")
source_repo_uri=$(jq -r '.provenance.source_repository_uri // ""' "$verification_json")
source_repo_ref=$(jq -r '.provenance.source_repository_ref // ""' "$verification_json")

echo "  OIDC Issuer: ${certificate_oidc_issuer:-"(not set)"}"
echo "  Runner environment: ${runner_environment:-"(not set)"}"
echo "  Source repository: ${source_repo_uri:-"(not set)"}"
echo "  Source ref: ${source_repo_ref:-"(not set)"}"

# Policy 1: Validate OIDC issuer matches expected CircleCI issuer
if [ -z "$certificate_oidc_issuer" ]; then
    echo ""
    echo "❌ POLICY VIOLATION: Missing OIDC issuer"
    exit 1
fi

if [[ "$certificate_oidc_issuer" != https://oidc.circleci.com* ]]; then
    echo ""
    echo "❌ POLICY VIOLATION: Invalid OIDC issuer: $certificate_oidc_issuer"
    echo "   Expected issuer to start with: https://oidc.circleci.com"
    exit 1
fi

# Policy 2: Reject SSH debug session builds
if [ "$runner_environment" = "ssh-rerun" ]; then
    echo ""
    echo "❌ POLICY VIOLATION: Artifact was signed during an SSH debug session"
    echo "   Artifacts signed during SSH reruns are not trusted for production use."
    exit 1
fi

# Add more policy checks here as needed:
#
# Example: Require builds from main branch only
# if [[ "$source_repo_ref" != "refs/heads/main" ]]; then
#     echo "❌ POLICY VIOLATION: Artifact not built from main branch"
#     exit 1
# fi
#
# Example: Require builds from specific repository
# if [[ "$source_repo_uri" != "https://github.com/your-org/your-repo" ]]; then
#     echo "❌ POLICY VIOLATION: Artifact not from approved repository"
#     exit 1
# fi

echo ""
echo "✅ All policies passed"
