# PyPI Publishing Example

A minimal example of building and publishing a Python package to PyPI using CircleCI.

## Local Usage

### Build

```bash
cd pypi
./build.sh
```

This will:
- Generate a unique version based on environment (`PYPI_ENV`)
- Install the `build` package
- Create distributions (wheel and sdist) in `dist/`

### Install and Test

```bash
pip install dist/circleci_sign_publish_example-*.whl
python -c "import sign_publish_pypi_example; print(sign_publish_pypi_example.hello())"
```

### Publish (Locally)

```bash
# Set environment (staging or production)
export PYPI_ENV=staging
export TWINE_USERNAME="__token__"
export TWINE_PASSWORD="<your-test-pypi-token>"

./publish.sh
```

**Note:** Publishing locally requires valid PyPI credentials. For testing, use TestPyPI.

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
