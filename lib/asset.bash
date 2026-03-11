#!/usr/bin/env bash

set -euo pipefail

# Detect the operating system
get_os() {
  local os
  os=$(uname -s)

  case "${os}" in
    Darwin)
      echo "macOS"
      ;;
    Linux)
      echo "linux"
      ;;
    *)
      echo "Unsupported operating system: ${os}" >&2
      return 1
      ;;
  esac
}

# Detect the machine architecture
get_arch() {
  local arch
  arch=$(uname -m)

  case "${arch}" in
    x86_64)
      echo "amd64"
      ;;
    arm64|aarch64)
      echo "arm64"
      ;;
    *)
      echo "Unsupported architecture: ${arch}" >&2
      return 1
      ;;
  esac
}

# Construct the asset filename for gh CLI
get_asset_name() {
  local version="${1}"
  local os
  local arch

  os=$(get_os)
  arch=$(get_arch)

  echo "gh_${version}_${os}_${arch}.tar.gz"
}

# Download and extract gh CLI from GitHub releases
download_gh_cli() {
  local version="${1}"
  local install_dir="${2}"
  local asset_name
  local download_url

  asset_name=$(get_asset_name "${version}")
  download_url="https://github.com/cli/cli/releases/download/v${version}/${asset_name}"

  echo "Downloading gh CLI version ${version}..."
  echo "URL: ${download_url}"

  # Create temporary directory for download
  local temp_dir
  temp_dir=$(mktemp -d)
  # Use double quotes so temp_dir is expanded now (at trap-set time),
  # not later when the variable may be out of scope.
  # shellcheck disable=SC2064
  trap "rm -rf \"${temp_dir}\"" EXIT

  # Download the archive
  if ! curl -fsSL "${download_url}" -o "${temp_dir}/${asset_name}"; then
    echo "Failed to download gh CLI from ${download_url}" >&2
    return 1
  fi

  # Extract the archive
  echo "Extracting gh CLI to ${install_dir}..."
  mkdir -p "${install_dir}"

  tar -xzf "${temp_dir}/${asset_name}" -C "${temp_dir}"

  # Find the extracted directory (removes version and platform suffix)
  local extracted_dir
  extracted_dir=$(find "${temp_dir}" -maxdepth 1 -type d -name "gh_*" | head -n 1)

  if [[ -z "${extracted_dir}" ]]; then
    echo "Failed to find extracted gh CLI directory" >&2
    return 1
  fi

  # Copy the gh binary to the install directory
  cp -r "${extracted_dir}/bin"/* "${install_dir}/"

  echo "gh CLI installed successfully to ${install_dir}"
}
