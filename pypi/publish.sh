#!/bin/bash
# Publish Python package distributions to PyPI, TestPyPI, or local instance using twine
#
# Usage (OIDC - automatic in CircleCI):
#   export PYPI_ENV=staging  # or production
#   ./publish.sh
#   (twine will auto-detect CircleCI OIDC token)
#
# Usage (API Token - local testing):
#   export PYPI_ENV=staging
#   export TWINE_USERNAME="__token__"
#   export TWINE_PASSWORD="<your-pypi-token>"
#   ./publish.sh
#
# Environment variables:
#   PYPI_ENV              - either "staging", "production", or "local" (required)
#   TWINE_USERNAME        - PyPI username (defaults to "__token__" for Trusted Publishing)
#   TWINE_PASSWORD        - PyPI API token (for local testing; omit to use Trusted Publishing)
#   STAGING_PYPI_URL      - Staging repository URL (defaults to https://test.pypi.org/legacy/)
#   PRODUCTION_PYPI_URL   - Production repository URL (defaults to https://upload.pypi.org/legacy/)
#   LOCAL_PYPI_URL        - Local repository URL (defaults to http://localhost/legacy/)

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
# If TWINE_PASSWORD is set, use API token. Otherwise use Trusted Publishing (OIDC).
USE_API_TOKEN=false
if [ -n "$TWINE_PASSWORD" ]; then
  USE_API_TOKEN=true
fi

# Default username to __token__ if not set
TWINE_USERNAME="${TWINE_USERNAME:-__token__}"

# Determine repository URL (can be overridden via env vars)
case "$PYPI_ENV" in
  staging)
    REPO_URL="${STAGING_PYPI_URL:-https://test.pypi.org/legacy/}"
    REPO_NAME="TestPyPI"
    ;;
  production)
    REPO_URL="${PRODUCTION_PYPI_URL:-https://upload.pypi.org/legacy/}"
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
if [ "$USE_API_TOKEN" = true ]; then
  # Use API token credentials
  python -m twine upload \
    --repository-url "$REPO_URL" \
    --username "$TWINE_USERNAME" \
    --password "$TWINE_PASSWORD" \
    dist/*
elif [ "$PYPI_ENV" = "local" ]; then
  # Use .pypirc credentials for local instance
  python -m twine upload \
    --repository local \
    dist/*
else
  # Use Trusted Publishing (OIDC) - no credentials needed, twine auto-detects
  python -m twine upload \
    --repository-url "$REPO_URL" \
    --username "$TWINE_USERNAME" \
    dist/*
fi

set -x

echo "Publish to $REPO_NAME complete!"
