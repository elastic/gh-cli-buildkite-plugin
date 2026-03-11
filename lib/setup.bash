#!/usr/bin/env bash

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
# shellcheck source=lib/asset.bash
source "${SCRIPT_DIR}/asset.bash"
# shellcheck source=lib/version.bash
source "${SCRIPT_DIR}/version.bash"

# Setup and install gh CLI
setup() {
  local version="${1}"
  local install_dir="${2}"

  echo "Setting up gh CLI version ${version}..."

  # Check if gh is already installed with the correct version
  if command -v gh &> /dev/null; then
    local current_version
    current_version=$(gh --version | head -n 1 | awk '{print $3}' || echo "unknown")

    if [[ "${current_version}" == "${version}" ]]; then
      echo "gh CLI version ${version} is already installed"
      return 0
    else
      echo "Found gh CLI version ${current_version}, but need ${version}"
    fi
  fi

  # Create install directory
  mkdir -p "${install_dir}"

  # Download and install gh CLI
  download_gh_cli "${version}" "${install_dir}"

  # Verify installation
  if [[ -x "${install_dir}/gh" ]]; then
    echo "gh CLI setup complete"
    "${install_dir}/gh" --version
  else
    echo "Failed to install gh CLI" >&2
    return 1
  fi
}
