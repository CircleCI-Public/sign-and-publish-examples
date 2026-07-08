# circleci-sign-publish-example

A minimal example package showing how to publish to PyPI from CircleCI using [trusted publishing](https://docs.pypi.org/trusted-publishers/), with no long-lived API token.

For the full walkthrough, see [Publish to PyPI](https://circleci.com/docs/deploy/deploy-to-pypi-registry/).

> This example publishes to [TestPyPI](https://test.pypi.org). To publish elsewhere, change `--repository` in `../.circleci/pypi-publish.yml`.

## Project Structure

- **`build.sh`** - Sets a dynamic version (`MAJOR.MINOR.<CIRCLE_BUILD_NUM>`) and builds the wheel and sdist
- **`pyproject.toml`** - Package metadata, built with the `uv_build` backend
- **`src/circleci_sign_publish_example/`** - The package's one function: `hello`
- **`tests/`** - Tests, runnable with `PYTHONPATH=src python -m unittest discover -s tests`
- **`../.circleci/pypi-publish.yml`** - CircleCI pipeline

## How It Works

1. CircleCI runs the publish job on push to `main`.
2. `twine upload` (6.1.0+) detects it is running on CircleCI and mints an OIDC token through the `id` library (`circleci run oidc get --root-issuer`).
3. `twine` exchanges the OIDC token for a short-lived TestPyPI API token and uploads the distributions. No token is stored.

The trusted publisher is configured on TestPyPI under the project's *Publishing* settings and is bound to the `trusted-publishing-guard` CircleCI context, which has an expression restriction limiting it to `main`. A second workflow on non-main branches is included to demonstrate that the lockdown rejects publishes from other branches.
