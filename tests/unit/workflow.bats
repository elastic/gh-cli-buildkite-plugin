#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "${BATS_TEST_DIRNAME}/../../lib/workflow.bash"
}

@test "run_workflow with no workflow file returns success" {
  run run_workflow "" "main" "" "false"
  assert_success
  assert_output --partial "No workflow file specified"
}

@test "run_workflow builds basic command without inputs" {
  # Mock gh command
  gh() {
    echo "gh $*"
    return 0
  }
  export -f gh

  run run_workflow "ci.yml" "main" "" "false"
  assert_success
  assert_output --partial "Running GitHub workflow: ci.yml"
  assert_output --partial "Reference: main"
  assert_output --partial "gh workflow run ci.yml --ref main"
}

@test "run_workflow builds command with JSON inputs" {
  # Mock gh and jq commands
  gh() {
    echo "gh $*"
    return 0
  }
  export -f gh

  jq() {
    if [[ "$*" == *"to_entries"* ]]; then
      echo '--field version=1.0.0'
      echo '--field environment=production'
    fi
  }
  export -f jq

  local inputs='{"version":"1.0.0","environment":"production"}'

  run run_workflow "ci.yml" "main" "$inputs" "false"
  assert_success
  assert_output --partial "Workflow inputs: $inputs"
  assert_output --partial "--field version=1.0.0"
  assert_output --partial "--field environment=production"
}

@test "run_workflow fails when gh command fails" {
  # Mock gh command to fail
  gh() {
    return 1
  }
  export -f gh

  run run_workflow "ci.yml" "main" "" "false"
  assert_failure
  assert_output --partial "Failed to trigger workflow"
}

@test "run_workflow calls wait_for_workflow when wait is true" {
  # Mock gh command
  gh() {
    return 0
  }
  export -f gh

  # Mock wait_for_workflow
  wait_for_workflow() {
    echo "wait_for_workflow called with: $1 $2"
    return 0
  }
  export -f wait_for_workflow

  run run_workflow "ci.yml" "main" "" "true"
  assert_success
  assert_output --partial "wait_for_workflow called with: ci.yml main"
}

@test "wait_for_workflow gets run ID and watches it" {
  # Mock gh run list
  gh() {
    if [[ "$1" == "run" && "$2" == "list" ]]; then
      echo "12345"
    elif [[ "$1" == "run" && "$2" == "watch" ]]; then
      echo "Watching run 12345"
      return 0
    elif [[ "$1" == "run" && "$2" == "view" ]]; then
      echo "Viewing run 12345"
      return 0
    fi
  }
  export -f gh

  # Mock sleep to avoid delays
  sleep() {
    return 0
  }
  export -f sleep

  run wait_for_workflow "ci.yml" "main"
  assert_success
  assert_output --partial "Waiting for workflow to complete"
  assert_output --partial "Monitoring workflow run ID: 12345"
  assert_output --partial "Workflow completed successfully"
}

@test "wait_for_workflow fails when no run ID found" {
  # Mock gh run list to return empty
  gh() {
    if [[ "$1" == "run" && "$2" == "list" ]]; then
      echo ""
    fi
  }
  export -f gh

  # Mock sleep
  sleep() {
    return 0
  }
  export -f sleep

  run wait_for_workflow "ci.yml" "main"
  assert_failure
  assert_output --partial "Could not find workflow run ID"
}

@test "wait_for_workflow fails when workflow run fails" {
  # Mock gh commands
  gh() {
    if [[ "$1" == "run" && "$2" == "list" ]]; then
      echo "12345"
    elif [[ "$1" == "run" && "$2" == "watch" ]]; then
      return 1  # Simulate workflow failure
    elif [[ "$1" == "run" && "$2" == "view" ]]; then
      echo "Run failed"
      return 0
    fi
  }
  export -f gh

  # Mock sleep
  sleep() {
    return 0
  }
  export -f sleep

  run wait_for_workflow "ci.yml" "main"
  assert_failure
  assert_output --partial "Workflow run failed or was cancelled"
}
