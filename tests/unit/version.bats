#!/usr/bin/env bats

load '../test_helper'

setup() {
  export FIXTURES_DIR="${BATS_TEST_DIRNAME}/../fixtures"
  source "${BATS_TEST_DIRNAME}/../../lib/version.bash"
}

@test "Get version from .tool-versions file" {
  run get_version_from_file "${FIXTURES_DIR}/.tool-versions"
  assert_success
  assert_output "2.60.0"
}

@test "Get version from any file" {
  run get_version_from_file "${FIXTURES_DIR}/.gh-cli-version"
  assert_success
  assert_output "2.58.0"
}

@test "Get version from input or file (with both provided)" {
  # Mock buildkite-agent command to silently succeed
  buildkite-agent() {
    return 0
  }
  export -f buildkite-agent

  run get_version_from_input_or_file "2.60.0" "${FIXTURES_DIR}/.gh-cli-version"
  assert_success
  assert_output "2.60.0"
}

@test "Get version from input or file (empty input)" {
  run get_version_from_input_or_file "" "${FIXTURES_DIR}/.gh-cli-version"
  assert_success
  assert_output "2.58.0"
}

@test "Get version from input or file (failure case)" {
  run get_version_from_input_or_file "" "/non/existent/file"
  assert_failure
  assert_output --partial "Version file not found"
}
