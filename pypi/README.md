# PyPI Publishing Example

A minimal example of building and publishing a Python package to PyPI using CircleCI.

## Local Usage

### Prerequisites

You'll need `uv` installed. Install it from [astral.sh/uv](https://docs.astral.sh/uv/):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Build

```bash
cd pypi
./build.sh
```

This will:
- Generate a unique version based on environment (`PYPI_ENV`)
- Use `uv build` to create distributions (wheel and sdist) in `dist/`

### Install and Test

```bash
pip install dist/circleci_sign_publish_example-*.whl
python -c "import circleci_sign_publish_example; print(circleci_sign_publish_example.hello())"
```

### Publish (Locally)

**To TestPyPI (staging):**
```bash
export PYPI_ENV=staging
export TWINE_USERNAME="__token__"
export TWINE_PASSWORD="<your-test-pypi-token>"
./publish.sh
```

**To Local PyPI instance:**
```bash
export PYPI_ENV=local
export TWINE_USERNAME="<your-local-username>"
export TWINE_PASSWORD="<your-local-password>"
export LOCAL_PYPI_URL="http://localhost/legacy/"  # optional, defaults to http://localhost/legacy/
./publish.sh
```

**Note:** Publishing requires valid credentials. For testing against a local instance, ensure your PyPI server is running and accessible.

## CircleCI Workflow

The workflow automatically publishes based on branch:

- **`main` branch** → Publishes to [PyPI](https://pypi.org) (production)
- **Other branches** → Publishes to [TestPyPI](https://test.pypi.org) (staging)

### Required CircleCI Contexts

Create two contexts in your CircleCI organization:

1. **`pypi-production`**
   - Variable: `PYPI_API_TOKEN` (your PyPI API token)

2. **`pypi-staging`**
   - Variable: `PYPI_API_TOKEN` (your TestPyPI API token)

### Version Strategy

Versions are automatically generated to ensure uniqueness across builds:

- **Staging:** `0.0.0.dev{CIRCLE_BUILD_NUM}`
- **Production:** `0.0.0.post{CIRCLE_BUILD_NUM}`

This prevents "file already exists" errors on repeated builds.

### Installing from TestPyPI

To test the staged build:

```bash
pip install \
  --index-url https://test.pypi.org/simple/ \
  --extra-index-url https://pypi.org/simple/ \
  circleci-sign-publish-example
```
