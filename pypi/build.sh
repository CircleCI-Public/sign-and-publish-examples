#!/bin/bash
# Set a dynamic package version and build the wheel and sdist.
#
# The version is MAJOR.MINOR from pyproject.toml with the patch set to the
# CircleCI build number, so every publish gets a unique, increasing version
# and repeated builds do not collide on the index.

set -euo pipefail

BASE_VERSION="$(grep -E '^version = ' pyproject.toml | head -1 | sed -E 's/version = "(.*)"/\1/')"
BUILD_NUM="${CIRCLE_BUILD_NUM:-0}"

IFS='.' read -r MAJOR MINOR _ <<< "$BASE_VERSION"
TARGET_VERSION="${MAJOR}.${MINOR}.${BUILD_NUM}"

echo "Setting package version to: ${TARGET_VERSION}"

# Portable sed for macOS and Linux.
INIT_FILE="src/circleci_sign_publish_example/__init__.py"
sed -i.bak "s/^version = .*/version = \"${TARGET_VERSION}\"/" pyproject.toml && rm -f pyproject.toml.bak
sed -i.bak "s/^__version__ = .*/__version__ = \"${TARGET_VERSION}\"/" "$INIT_FILE" && rm -f "${INIT_FILE}.bak"

echo "Building distributions..."
python -m build

echo "Build complete. Distributions ready in dist/"
