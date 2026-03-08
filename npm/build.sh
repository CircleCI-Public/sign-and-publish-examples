#!/bin/bash

set -euo pipefail

BASE_VERSION="$(node -p "require('./package.json').version")"
BUILD_NUM="${CIRCLE_BUILD_NUM:-0}"
BRANCH="${CIRCLE_BRANCH:-local}"

IFS='.' read -r MAJOR MINOR _ <<< "$BASE_VERSION"

if [ "$BRANCH" = "main" ]; then
  TARGET_VERSION="${MAJOR}.${MINOR}.${BUILD_NUM}"
else
  SANITIZED_BRANCH="$(echo "$BRANCH" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g')"
  [ -n "$SANITIZED_BRANCH" ] || SANITIZED_BRANCH="branch"
  TARGET_VERSION="${MAJOR}.${MINOR}.${BUILD_NUM}-dev.${SANITIZED_BRANCH}"
fi

echo "Setting package version to: ${TARGET_VERSION}"
npm version "$TARGET_VERSION" --no-git-tag-version

mkdir -p dist
npm pack --pack-destination dist >/dev/null
echo "Build complete. Tarball written to npm/dist/"
