#!/bin/bash

set -euo pipefail

BASE_VERSION="$(node -p "require('./package.json').version")"
BUILD_NUM="${CIRCLE_BUILD_NUM:-0}"

IFS='.' read -r MAJOR MINOR _ <<< "$BASE_VERSION"

TARGET_VERSION="${MAJOR}.${MINOR}.${BUILD_NUM}"

echo "Setting package version to: ${TARGET_VERSION}"
npm version "$TARGET_VERSION" --no-git-tag-version
