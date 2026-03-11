#!/usr/bin/env bats

load '../test_helper'

setup() {
  # Extract and source just the build_workflow_inputs_json function
  # shellcheck disable=SC1090
  source <(sed -n '/^build_workflow_inputs_json()/,/^}/p' "${BATS_TEST_DIRNAME}/../../hooks/command")

  # Clean up any existing workflow input env vars
  for var in $(compgen -e | grep "^BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_"); do
    unset "$var"
  done
}

teardown() {
  # Clean up env vars after each test
  for var in $(compgen -e | grep "^BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_"); do
    unset "$var"
  done
}

@test "Build workflow inputs JSON from flattened env vars" {
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_VERSION="1.0.0"
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_ENVIRONMENT="production"
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_TEST_SUITE="smoke"

  run build_workflow_inputs_json
  assert_success

  # Parse the JSON to verify it's valid
  echo "$output" | jq -e '.' > /dev/null

  # Check each key-value pair
  echo "$output" | jq -e '.version == "1.0.0"'
  echo "$output" | jq -e '.environment == "production"'
  echo "$output" | jq -e '."test-suite" == "smoke"'
}

@test "Build workflow inputs JSON with kebab-case conversion" {
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_ENABLE_DEBUG="true"

  run build_workflow_inputs_json
  assert_success

  # Verify kebab-case conversion: ENABLE_DEBUG -> enable-debug
  echo "$output" | jq -e '."enable-debug" == "true"'
}

@test "Build workflow inputs JSON with no inputs returns empty" {
  run build_workflow_inputs_json
  assert_success
  assert_output ""
}

@test "Build workflow inputs JSON ignores other plugin env vars" {
  export BUILDKITE_PLUGIN_GH_CLI_VERSION="2.62.0"
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_FILE="test.yml"
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_VERSION="1.0.0"

  run build_workflow_inputs_json
  assert_success

  # Should only include workflow inputs, not other plugin config
  local json_keys
  json_keys=$(echo "$output" | jq -r 'keys | .[]')

  [[ "$json_keys" == "version" ]]
  [[ "$json_keys" != *"workflow-file"* ]]
}

@test "Build workflow inputs JSON with special characters" {
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_MESSAGE="Hello World! Special chars: @#\$"

  run build_workflow_inputs_json
  assert_success

  # Verify special characters are preserved
  echo "$output" | jq -e '.message == "Hello World! Special chars: @#$"'
}

@test "Build workflow inputs JSON with empty value" {
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_OPTIONAL=""
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_REQUIRED="value"

  run build_workflow_inputs_json
  assert_success

  # Both should be included, even if empty
  echo "$output" | jq -e '.optional == ""'
  echo "$output" | jq -e '.required == "value"'
}

@test "Build workflow inputs JSON with multiple underscores" {
  export BUILDKITE_PLUGIN_GH_CLI_WORKFLOW_INPUTS_LONG_VAR_NAME="test"

  run build_workflow_inputs_json
  assert_success

  # Verify conversion: LONG_VAR_NAME -> long-var-name
  echo "$output" | jq -e '."long-var-name" == "test"'
}
