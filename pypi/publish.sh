#!/bin/bash
# Publish Python package distributions to PyPI or TestPyPI using twine
#
# Usage:
#   export PYPI_ENV=staging  # or production
#   export TWINE_USERNAME="__token__"
#   export TWINE_PASSWORD="<your-pypi-token>"
#   ./publish.sh
#
# Environment variables:
#   PYPI_ENV          - either "staging" or "production" (required)
#   TWINE_USERNAME    - PyPI username (usually "__token__")
#   TWINE_PASSWORD    - PyPI API token (required, will not be echoed)

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

# Validate credentials
if [ -z "$TWINE_USERNAME" ]; then
  echo "Error: TWINE_USERNAME not set" >&2
  exit 1
fi

if [ -z "$TWINE_PASSWORD" ]; then
  echo "Error: TWINE_PASSWORD not set" >&2
  exit 1
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
esac

echo "Publishing to $REPO_NAME ($PYPI_ENV)..."

# Disable command echoing to avoid leaking credentials
set +x

# Upload distributions
python -m twine upload \
  --repository-url "$REPO_URL" \
  --username "$TWINE_USERNAME" \
  --password "$TWINE_PASSWORD" \
  dist/*

set -x

echo "Publish to $REPO_NAME complete!"
