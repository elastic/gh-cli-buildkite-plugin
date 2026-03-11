#!/usr/bin/env bash

set -euo pipefail

# Get version from a file (supports both standard version files and .tool-versions)
get_version_from_file() {
  local version_file="${1}"

  if [[ ! -f "${version_file}" ]]; then
    echo "Version file not found: ${version_file}" >&2
    return 1
  fi

  # Check if it's a .tool-versions file (asdf format)
  if [[ "${version_file}" == *".tool-versions" ]]; then
    # Extract gh version from .tool-versions file
    local version
    version=$(grep -E "^gh\\s+" "${version_file}" | awk '{print $2}' || echo "")

    if [[ -z "${version}" ]]; then
      echo "No 'gh' entry found in ${version_file}" >&2
      return 1
    fi

    echo "${version}"
  else
    # Standard version file - just read the first line
    head -n 1 "${version_file}" | tr -d '[:space:]'
  fi
}

# Get version from input or file, with precedence for direct input
get_version_from_input_or_file() {
  local version="${1:-}"
  local version_file="${2:-}"

  # If both are provided, warn and use the direct version
  if [[ -n "${version}" && -n "${version_file}" ]]; then
    buildkite-agent annotate "Both 'version' and 'version-file' are set. Using 'version' (${version})." --style warning --context gh-cli-version-warning
  fi

  # Direct version takes precedence
  if [[ -n "${version}" ]]; then
    echo "${version}"
    return 0
  fi

  # Try to get version from file
  if [[ -n "${version_file}" ]]; then
    get_version_from_file "${version_file}"
    return $?
  fi

  # Fall back to default version file
  local default_version_file
  default_version_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.default-gh-cli-version"

  if [[ -f "${default_version_file}" ]]; then
    head -n 1 "${default_version_file}" | tr -d '[:space:]'
  else
    echo "No version specified and no default version file found" >&2
    return 1
  fi
}
