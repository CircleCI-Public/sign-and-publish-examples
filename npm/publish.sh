#!/bin/bash

set -euo pipefail

BRANCH="${CIRCLE_BRANCH:-local}"
DIST_TAG="dev"

echo "publish.sh starting on branch: ${BRANCH}"

if [ "$BRANCH" = "main" ]; then
  DIST_TAG="latest"
fi

echo "Using npm dist-tag: ${DIST_TAG}"

if [ -n "${NPM_REGISTRY_URL:-}" ]; then
  echo "Configuring npm registry: ${NPM_REGISTRY_URL}"
  npm config set registry "${NPM_REGISTRY_URL}"
else
  echo "Using default npm registry"
fi

if [ -z "${NPM_ID_TOKEN:-}" ]; then
  echo "NPM_ID_TOKEN not set; attempting to mint one"
  if command -v circleci >/dev/null 2>&1; then
    echo "CircleCI CLI found; requesting OIDC token for npm"
    export NPM_ID_TOKEN="$(circleci run oidc get --claims '{"aud": "npm:registry.npmjs.org"}')"
    echo "OIDC token acquired"
  else
    echo "Error: NPM_ID_TOKEN is not set and CircleCI CLI is unavailable to mint one." >&2
    exit 1
  fi
else
  echo "Using existing NPM_ID_TOKEN from environment"
fi

echo "Publishing $(node -p "require('./package.json').name")@$(node -p "require('./package.json').version") with dist-tag '${DIST_TAG}'"
npm publish --access public --tag "${DIST_TAG}"
