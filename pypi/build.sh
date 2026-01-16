#!/bin/bash
# Build Python package distributions using uv build
# 
# Usage:
#   export PYPI_ENV=staging  # or production
#   ./build.sh
#
# Environment variables:
#   PYPI_ENV    - either "staging" or "production" (required)
#   CIRCLE_BUILD_NUM - CircleCI build number (auto-set, defaults to 0 locally)

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

# Determine version based on environment
BUILD_NUM="${CIRCLE_BUILD_NUM:-0}"

case "$PYPI_ENV" in
  staging)
    VERSION="0.0.0.dev${BUILD_NUM}"
    ;;
  production)
    VERSION="0.0.0.post${BUILD_NUM}"
    ;;
esac

echo "Building package version: $VERSION"

# Update version in __init__.py
INIT_FILE="src/circleci_sign_publish_example/__init__.py"
sed -i '' "s/__version__ = \".*\"/__version__ = \"$VERSION\"/" "$INIT_FILE"

# Install uv if needed and build
echo "Building distributions with uv..."
uv build

echo "Build complete. Distributions ready in dist/"
