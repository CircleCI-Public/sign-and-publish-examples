# @circleci/trusted-publishing-example

A minimal example package showing how to publish to npm from CircleCI using [trusted publishing](https://docs.npmjs.com/trusted-publishers), with no long-lived `NPM_TOKEN`.

For the full walkthrough, see [Publish to npm](https://circleci.com/docs/deploy/deploy-to-npm-registry/).

## Project Structure

- **`build.sh`** - Sets a dynamic version (`MAJOR.MINOR.<CIRCLE_BUILD_NUM>`) on `package.json`
- **`index.js`** - The package's one function: `helloWorld`
- **`index.test.js`** - Tests, runnable with `npm test`
- **`../.circleci/npm-publish.yml`** - CircleCI pipeline

## How It Works

1. CircleCI runs the publish job on push to `main`.
2. The job mints an OIDC token (`circleci run oidc get --claims '{"aud": "npm:registry.npmjs.org"}'`) and exports it as `NPM_ID_TOKEN`.
3. `npm publish` detects `NPM_ID_TOKEN` and exchanges it for a short-lived publish token.

The trusted publisher is configured on npmjs.com under the package's *Settings → Trusted Publishing* tab and is bound to the `trusted-publishing-guard` CircleCI context, which has an expression restriction limiting it to `main`. A staging workflow on non-main branches is included to demonstrate that the lockdown rejects publishes from other branches.
