#!/bin/bash
# Publish Python package distributions to PyPI, TestPyPI, or local instance using twine
#
# Usage (OIDC):
#   export PYPI_ENV=staging  # or production, or local
#   export OIDC_TOKEN="$(circleci run oidc get --root-issuer --claims '{\"aud\": \"pypi\"}')"
#   ./publish.sh
#
# Usage (API Token):
#   export PYPI_ENV=staging
#   export TWINE_USERNAME="__token__"
#   export TWINE_PASSWORD="<your-pypi-token>"
#   ./publish.sh
#
# Environment variables:
#   PYPI_ENV          - either "staging", "production", or "local" (required)
#   OIDC_TOKEN        - OIDC token for Trusted Publishing (recommended for CI)
#   TWINE_USERNAME    - PyPI username (usually "__token__", fallback if OIDC_TOKEN not set)
#   TWINE_PASSWORD    - PyPI API token (fallback if OIDC_TOKEN not set)
#   LOCAL_PYPI_URL    - PyPI repository URL (used when PYPI_ENV=local, defaults to http://localhost/legacy/)

set -e

# Validate PYPI_ENV
if [ -z "$PYPI_ENV" ]; then
  echo "Error: PYPI_ENV not set (must be 'staging', 'production', or 'local')" >&2
  exit 1
fi

if [ "$PYPI_ENV" != "staging" ] && [ "$PYPI_ENV" != "production" ] && [ "$PYPI_ENV" != "local" ]; then
  echo "Error: PYPI_ENV must be 'staging', 'production', or 'local', got '$PYPI_ENV'" >&2
  exit 1
fi

# Determine authentication method
USE_OIDC=false
USE_API_TOKEN=false

if [ -n "$OIDC_TOKEN" ]; then
  USE_OIDC=true
elif [ -n "$TWINE_USERNAME" ] && [ -n "$TWINE_PASSWORD" ]; then
  USE_API_TOKEN=true
fi

# Determine repository URL
case "$PYPI_ENV" in
  staging)
    REPO_URL="https://test.pypi.org/legacy/"
    REPO_NAME="TestPyPI"
    ;;
  production)
    REPO_URL="https://upload.pypi.org/legacy/"
    REPO_NAME="PyPI"
    ;;
  local)
    REPO_URL="${LOCAL_PYPI_URL:-http://localhost/legacy/}"
    REPO_NAME="Local PyPI"
    ;;
esac

echo "Publishing to $REPO_NAME ($PYPI_ENV)..."

# Disable command echoing to avoid leaking credentials
set +x

# Upload distributions
if [ "$USE_OIDC" = true ]; then
  # Use OIDC token for Trusted Publishing
  python -m twine upload \
    --repository-url "$REPO_URL" \
    --identity-token "$OIDC_TOKEN" \
    dist/*
elif [ "$USE_API_TOKEN" = true ]; then
  # Use API token credentials
  python -m twine upload \
    --repository-url "$REPO_URL" \
    --username "$TWINE_USERNAME" \
    --password "$TWINE_PASSWORD" \
    dist/*
else
  # Use .pypirc credentials (specify repository name for local, URL for others)
  if [ "$PYPI_ENV" = "local" ]; then
    python -m twine upload \
      --repository local \
      dist/*
  else
    python -m twine upload \
      --repository-url "$REPO_URL" \
      dist/*
  fi
fi

set -x

echo "Publish to $REPO_NAME complete!"
