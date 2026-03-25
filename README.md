# GitHub CLI Buildkite Plugin

[![usages](https://img.shields.io/badge/usages-white?logo=buildkite&logoColor=blue)](https://github.com/search?q=elastic%2Fgh-cli+%28path%3A.buildkite%29&type=code)

A Buildkite plugin for installing the GitHub CLI (`gh`) and optionally running GitHub workflows from your Buildkite pipeline.

## Features

- 🚀 Automatically installs the specified version of GitHub CLI
- 📦 Supports version specification via direct input or version files
- 🔄 Can trigger GitHub workflows with custom inputs
- ⏱️ Optionally wait for workflow completion before proceeding
- 🔧 Works on both Linux and macOS build agents
- 💾 Caches installations to speed up subsequent builds

## Usage

### Basic Installation

Simply install the GitHub CLI without running any workflows:

```yaml
steps:
  - label: ":github: Use GitHub CLI"
    plugins:
      - elastic/gh-cli#v0.1.0:
          version: "2.88.0"
    command: |
      gh --version
      gh repo view
```

### Install and Run Workflow

Install GitHub CLI and trigger a workflow:

```yaml
steps:
  - label: ":github: Trigger deployment"
    plugins:
      - elastic/gh-cli#v0.1.0:
          version: "2.88.0"
          workflow-file: "deploy.yml"
          workflow-ref: "main"
          workflow-inputs:
            environment: "staging"
            version: "1.2.3"
    env:
      GITHUB_TOKEN: ${GITHUB_TOKEN}
```

### Run Workflow and Wait for Completion

Trigger a workflow and wait for it to complete:

```yaml
steps:
  - label: ":github: Run tests and wait"
    plugins:
      - elastic/gh-cli#v0.1.0:
          version: "2.88.0"
          workflow-file: "ci.yml"
          workflow-ref: ${BUILDKITE_COMMIT}
          wait: true
          workflow-inputs:
            test-suite: "integration"
    env:
      GITHUB_TOKEN: ${GITHUB_TOKEN}
```

### Using Version File

Specify the version in a file:

```yaml
steps:
  - label: ":github: Use version from file"
    plugins:
      - elastic/gh-cli#v0.1.0:
          version-file: ".gh-version"
```

### Using .tool-versions (asdf)

If you use asdf, you can specify the version in `.tool-versions`:

```
# .tool-versions
gh 2.88.0
node 24.0.0
```

Then reference it in your pipeline:

```yaml
steps:
  - label: ":github: Use asdf version"
    plugins:
      - elastic/gh-cli#v0.1.0:
          version-file: ".tool-versions"
```

### 🔌 Plugin Composability

Work seamlessly with dependency plugins like `elastic/vault-github-token`:

```yaml
plugins:
  - elastic/vault-github-token#v0.1.0:  # Sets GITHUB_TOKEN
  - elastic/gh-cli#v0.1.0: # Uses GITHUB_TOKEN
      version: "2.88.0"
      workflow-file: "deploy.yml"
```

## Configuration

### `version` (optional, string)

The version of GitHub CLI to install (e.g., `"2.62.0"`).

If not specified, the plugin will fall back to `version-file` or the default version.

### `version-file` (optional, string)

Path to a file containing the version number. Supports both simple version files and `.tool-versions` (asdf format).

### `workflow-file` (optional, string)

The workflow file name or ID to run (e.g., `"ci.yml"` or a workflow ID).

### `workflow-ref` (optional, string)

The git reference (branch, tag, or SHA) for the workflow. Defaults to the current Buildkite branch.

### `workflow-inputs` (optional, object)

Input parameters to pass to the workflow as key-value pairs:

```yaml
workflow-inputs:
  environment: "production"
  version: "1.0.0"
  enable-debug: "true"
```

### `wait` (optional, boolean)

Whether to wait for the workflow to complete before proceeding. Defaults to `false`.

When `true`, the plugin will monitor the workflow run and fail the Buildkite build if the workflow fails.

## Environment Variables

### Required

- `GITHUB_TOKEN` - A GitHub personal access token with appropriate permissions for running workflows and accessing the repository.

### Set by Plugin

- `GH_CLI_BIN` - Path to the gh CLI binary directory
- `PATH` - Updated to include the gh CLI binary

## Requirements

The plugin requires the following tools to be available on the build agent:

- `bash`
- `curl`
- `tar`
- `git`
- `buildkite-agent`
- `jq` (required for parsing workflow inputs)

## Version Management

The plugin determines which version to install using the following precedence:

1. `version` parameter (highest priority)
2. `version-file` parameter
3. `.default-gh-cli-version` file in the plugin directory (default: 2.62.0)

## Platform Support

- ✅ Linux (amd64, arm64)
- ✅ macOS (amd64, arm64)

## Examples

### CI Workflow with Matrix Testing

```yaml
steps:
  - label: ":github: Run matrix tests"
    plugins:
      - elastic/gh-cli#v0.1.0:
          version: "2.88.0"
          workflow-file: "matrix-tests.yml"
          workflow-ref: ${BUILDKITE_COMMIT}
          wait: true
          workflow-inputs:
            node-versions: "14,16,18,20"
            test-type: "integration"
    env:
      GITHUB_TOKEN: ${GITHUB_TOKEN}
```

### Deployment Pipeline

```yaml
steps:
  - label: ":rocket: Deploy to staging"
    plugins:
      - elastic/gh-cli#v0.1.0:
          version: "2.88.0"
          workflow-file: "deploy.yml"
          workflow-ref: "main"
          workflow-inputs:
            environment: "staging"
            version: ${BUILDKITE_TAG}
    env:
      GITHUB_TOKEN: ${GITHUB_TOKEN}

  - wait

  - label: ":rocket: Deploy to production"
    plugins:
      - elastic/gh-cli#v0.1.0:
          version: "2.88.0"
          workflow-file: "deploy.yml"
          workflow-ref: "main"
          wait: true
          workflow-inputs:
            environment: "production"
            version: ${BUILDKITE_TAG}
    env:
      GITHUB_TOKEN: ${GITHUB_TOKEN}
```

## Troubleshooting

### Authentication Issues

If you encounter authentication errors, ensure that:

1. `GITHUB_TOKEN` is set in your environment
2. The token has the required scopes (typically `repo` and `workflow`)
3. The token hasn't expired

### Workflow Not Found

If the workflow cannot be found:

1. Verify the workflow file name is correct
2. Ensure the workflow exists in the specified ref
3. Check that the workflow file is in `.github/workflows/`

### Version Download Fails

If the gh CLI download fails:

1. Check that the version exists in the [GitHub CLI releases](https://github.com/cli/cli/releases)
2. Verify network connectivity from your build agent
3. Ensure the platform and architecture are supported

## Development

To test the plugin locally:

```bash
# Clone the repository
git clone https://github.com/elastic/gh-cli-buildkite-plugin.git
cd gh-cli-buildkite-plugin

# Set required environment variables
export BUILDKITE_PLUGIN_GH_CLI_VERSION="2.88.0"
export GITHUB_TOKEN="your-token"

# Run the pre-command hook
./hooks/pre-command
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
