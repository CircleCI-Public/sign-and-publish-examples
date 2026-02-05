#!/bin/bash
# Generate PEP 740 attestation bundles for built distributions
#
# Usage:
#   ./testify.sh
#
# Expects:
#   - A virtual environment activated with sigstore dependencies
#   - Built distributions present in dist/
#
# This script installs a custom fork of pypi-attestations that includes
# CircleCI OIDC support, then signs all .whl and .tar.gz files in dist/.
# The resulting .publish.attestation files are placed alongside the artifacts.

set -e

if [ ! -d dist ] || [ -z "$(ls dist/*.whl dist/*.tar.gz 2>/dev/null)" ]; then
  echo "Error: no distributions found in dist/" >&2
  exit 1
fi

echo "Installing attestation dependencies..."
pip install id==1.6.0
pip install "pypi-attestations @ https://github.com/meeech/pypi-attestations/archive/refs/heads/add-circleci-to-pypi-attestations.zip"

echo "Signing distributions..."
pypi-attestations sign dist/*

echo "Attestation complete. Bundles:"
ls -1 dist/*.attestation
