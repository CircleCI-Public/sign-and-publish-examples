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

echo "Publishing $(node -p "require('./package.json').name")@$(node -p "require('./package.json').version") with dist-tag '${DIST_TAG}'"
npm publish --provenance --access public --tag "${DIST_TAG}"
