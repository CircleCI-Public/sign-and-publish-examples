#!/bin/bash
# Publish Python package distributions to PyPI or TestPyPI using twine
#
# Usage:
#   export PYPI_ENV=staging  # or production, or local
#   export TWINE_USERNAME="__token__"
#   export TWINE_PASSWORD="<your-pypi-token>"
#   ./publish.sh
#
# Environment variables:
#   PYPI_ENV          - either "staging", "production", or "local" (required)
#   TWINE_USERNAME    - PyPI username (usually "__token__")
#   TWINE_PASSWORD    - PyPI API token (required, will not be echoed)
#   LOCAL_PYPI_URL    - Local PyPI repository URL (used when PYPI_ENV=local, defaults to http://localhost/legacy/)

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

# Validate credentials (optional if using .pypirc)
CREDENTIALS_PROVIDED=false
if [ -n "$TWINE_USERNAME" ] && [ -n "$TWINE_PASSWORD" ]; then
  CREDENTIALS_PROVIDED=true
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
if [ "$CREDENTIALS_PROVIDED" = true ]; then
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
