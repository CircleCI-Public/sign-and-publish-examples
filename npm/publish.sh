#!/bin/bash

set -euo pipefail

BRANCH="${CIRCLE_BRANCH:-local}"
DIST_TAG="dev"

if [ "$BRANCH" = "main" ]; then
  DIST_TAG="latest"
fi

if [ -n "${NPM_REGISTRY_URL:-}" ]; then
  npm config set registry "${NPM_REGISTRY_URL}"
fi

if [ -z "${NPM_ID_TOKEN:-}" ]; then
  if command -v circleci >/dev/null 2>&1; then
    export NPM_ID_TOKEN="$(circleci run oidc get --claims '{"aud": "npm:registry.npmjs.org"}')"
  else
    echo "Error: NPM_ID_TOKEN is not set and CircleCI CLI is unavailable to mint one." >&2
    exit 1
  fi
fi

echo "Publishing $(node -p "require('./package.json').name")@$(node -p "require('./package.json').version") with dist-tag '${DIST_TAG}'"
npm publish --access public --tag "${DIST_TAG}"
