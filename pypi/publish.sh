#!/bin/bash
# Publish Python package distributions to PyPI or TestPyPI using twine
#
# Usage (OIDC Trusted Publishing - recommended for CI):
#   export PYPI_ENV=staging  # or production
#   ./publish.sh
#
# Usage (API Token):
#   export PYPI_ENV=staging
#   export TWINE_USERNAME="__token__"
#   export TWINE_PASSWORD="<your-pypi-token>"
#   ./publish.sh
#
# Environment variables:
#   PYPI_ENV              - "staging" (TestPyPI) or "production" (PyPI)
#   PYPI_REPOSITORY_URL   - Override repository URL (staging only)
#   PYPI_OIDC_AUDIENCE    - Override OIDC audience (staging only)
#   TWINE_USERNAME        - PyPI username (fallback if OIDC unavailable)
#   TWINE_PASSWORD        - PyPI API token (fallback if OIDC unavailable)

set -e

# Validate PYPI_ENV
if [ -z "$PYPI_ENV" ]; then
  echo "Error: PYPI_ENV not set (must be 'staging' or 'production')" >&2
  exit 1
fi

if [ "$PYPI_ENV" != "staging" ] && [ "$PYPI_ENV" != "production" ]; then
  echo "Error: PYPI_ENV must be 'staging' or 'production', got '$PYPI_ENV'" >&2
  exit 1
fi

# Determine repository URLs and OIDC settings based on environment
case "$PYPI_ENV" in
  staging)
    REPO_URL="${PYPI_REPOSITORY_URL:-https://test.pypi.org/legacy/}"
    OIDC_AUDIENCE="${PYPI_OIDC_AUDIENCE:-testpypi}"
    REPO_NAME="TestPyPI"
    ;;
  production)
    REPO_URL="https://upload.pypi.org/legacy/"
    OIDC_AUDIENCE="pypi"
    REPO_NAME="PyPI"
    ;;
esac

# Extract domain from repository URL for OIDC token exchange
REPO_DOMAIN=$(echo "$REPO_URL" | sed -E 's|https?://([^/]+).*|\1|')

# Function to exchange OIDC token for PyPI API token
exchange_oidc_token() {
  local oidc_token="$1"
  local domain="$2"
  local mint_url="https://${domain}/_/oidc/mint-token"
  
  echo "Exchanging OIDC token for PyPI API token at $mint_url..." >&2
  
  local response
  response=$(curl -s -X POST "$mint_url" \
    -H "Content-Type: application/json" \
    -d "{\"token\": \"$oidc_token\"}")
  
  # Check if response contains a token
  local api_token
  api_token=$(echo "$response" | python -c "import sys, json; d=json.load(sys.stdin); print(d.get('token', ''))" 2>/dev/null)
  
  if [ -z "$api_token" ]; then
    echo "Error: Failed to exchange OIDC token for API token" >&2
    echo "Response: $response" >&2
    return 1
  fi
  
  echo "$api_token"
}

# Determine authentication method
USE_OIDC=false
USE_API_TOKEN=false

# Try OIDC first if circleci CLI is available
if command -v circleci >/dev/null 2>&1; then
  echo "Attempting OIDC Trusted Publishing..."
  
  # Generate OIDC token with correct audience
  OIDC_TOKEN=$(circleci run oidc get --root-issuer --claims "{\"aud\": \"$OIDC_AUDIENCE\"}" 2>/dev/null) || true
  
  if [ -n "$OIDC_TOKEN" ]; then
    # Exchange OIDC token for PyPI API token
    PYPI_API_TOKEN=$(exchange_oidc_token "$OIDC_TOKEN" "$REPO_DOMAIN") || true
    
    if [ -n "$PYPI_API_TOKEN" ]; then
      USE_OIDC=true
      TWINE_USERNAME="__token__"
      TWINE_PASSWORD="$PYPI_API_TOKEN"
      echo "Successfully obtained PyPI API token via OIDC"
    fi
  fi
fi

# Fall back to API token if OIDC failed
if [ "$USE_OIDC" = false ] && [ -n "$TWINE_USERNAME" ] && [ -n "$TWINE_PASSWORD" ]; then
  USE_API_TOKEN=true
  echo "Using API token authentication"
fi

echo "Publishing to $REPO_NAME ($PYPI_ENV)..."

# Disable command echoing to avoid leaking credentials
set +x

# Upload distributions
if [ "$USE_OIDC" = true ] || [ "$USE_API_TOKEN" = true ]; then
  python -m twine upload \
    --repository-url "$REPO_URL" \
    --username "$TWINE_USERNAME" \
    --password "$TWINE_PASSWORD" \
    dist/*
else
  echo "Error: No authentication available (OIDC failed and no TWINE_USERNAME/TWINE_PASSWORD set)" >&2
  exit 1
fi

set -x

echo "Publish to $REPO_NAME complete!"
