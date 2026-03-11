#!/usr/bin/env bats

load '../test_helper'

setup() {
  export FIXTURES_DIR="${BATS_TEST_DIRNAME}/../fixtures"
  source "${BATS_TEST_DIRNAME}/../../lib/asset.bash"
}

@test "Get asset name for gh CLI" {
  # Mock uname to return Linux x86_64
  uname() {
    if [[ "$1" == "-s" ]]; then
      echo "Linux"
    elif [[ "$1" == "-m" ]]; then
      echo "x86_64"
    fi
  }
  export -f uname

  run get_asset_name "2.60.0"
  assert_success
  assert_output "gh_2.60.0_linux_amd64.tar.gz"
}

@test "Get asset name for macOS arm64" {
  # Mock uname to return Darwin arm64
  uname() {
    if [[ "$1" == "-s" ]]; then
      echo "Darwin"
    elif [[ "$1" == "-m" ]]; then
      echo "arm64"
    fi
  }
  export -f uname

  run get_asset_name "2.60.0"
  assert_success
  assert_output "gh_2.60.0_macOS_arm64.tar.gz"
}

@test "Reject unsupported OS" {
  # Mock uname to return Windows
  uname() {
    if [[ "$1" == "-s" ]]; then
      echo "Windows_NT"
    fi
  }
  export -f uname

  run get_os
  assert_failure
  assert_output --partial "Unsupported operating system"
}

@test "Reject unsupported architecture" {
  # Mock uname to return i386
  uname() {
    if [[ "$1" == "-m" ]]; then
      echo "i386"
    fi
  }
  export -f uname

  run get_arch
  assert_failure
  assert_output --partial "Unsupported architecture"
}

@test "Download gh CLI creates correct structure" {
  skip "Integration test - requires actual download"

  local temp_dir
  temp_dir=$(mktemp -d)

  # This would be an integration test that actually downloads
  # For unit tests, we would mock curl and tar

  rm -rf "${temp_dir}"
}
