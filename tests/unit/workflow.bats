#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "${BATS_TEST_DIRNAME}/../../lib/workflow.bash"
  export PATH="${BATS_TEST_DIRNAME}:$PATH"
}

teardown() {
  # Clean up any stubs
  if command -v unstub &> /dev/null; then
    unstub gh || true
    unstub jq || true
    unstub sleep || true
  fi
}

@test "run_workflow with no workflow file returns success" {
  run run_workflow "" "main" "" "false"
  assert_success
  assert_output --partial "No workflow file specified"
}

@test "run_workflow builds basic command without inputs" {
  stub gh \
    "workflow run ci.yml --ref main : echo 'Triggered workflow'; exit 0"

  run run_workflow "ci.yml" "main" "" "false"
  assert_success
  assert_output --partial "Running GitHub workflow: ci.yml"
  assert_output --partial "Reference: main"
  assert_output --partial "Triggered workflow"

  unstub gh
}

@test "run_workflow builds command with JSON inputs" {
  # Stub jq to return the field arguments
  stub jq \
    "-r * : echo '--field version=1.0.0'; echo '--field environment=production'; exit 0"

  stub gh \
    "workflow run ci.yml --ref main --field version=1.0.0 --field environment=production : echo 'Triggered workflow'; exit 0"

  local inputs='{"version":"1.0.0","environment":"production"}'

  run run_workflow "ci.yml" "main" "$inputs" "false"
  assert_success
  assert_output --partial "Workflow inputs: $inputs"
  assert_output --partial "Triggered workflow"

  unstub jq
  unstub gh
}

@test "run_workflow fails when gh command fails" {
  stub gh \
    "workflow run ci.yml --ref main : exit 1"

  run run_workflow "ci.yml" "main" "" "false"
  assert_failure
  assert_output --partial "Failed to trigger workflow"

  unstub gh
}

@test "run_workflow calls wait_for_workflow when wait is true" {
  stub gh \
    "workflow run ci.yml --ref main : echo 'Triggered workflow'; exit 0" \
    "run list --workflow=ci.yml --branch=main --limit=1 --json databaseId --jq .[0].databaseId : echo '12345'; exit 0" \
    "run watch 12345 --exit-status : echo 'Workflow completed'; exit 0" \
    "run view 12345 : echo 'Run details'; exit 0"

  stub sleep \
    "5 : exit 0"

  run run_workflow "ci.yml" "main" "" "true"
  assert_success
  assert_output --partial "Waiting for workflow to complete"
  assert_output --partial "Monitoring workflow run ID: 12345"
  assert_output --partial "Workflow completed successfully"

  unstub gh
  unstub sleep
}

@test "wait_for_workflow gets run ID and watches it" {
  stub gh \
    "run list --workflow=ci.yml --branch=main --limit=1 --json databaseId --jq .[0].databaseId : echo '12345'; exit 0" \
    "run watch 12345 --exit-status : echo 'Workflow running...'; exit 0" \
    "run view 12345 : echo 'Workflow details'; exit 0"

  stub sleep \
    "5 : exit 0"

  run wait_for_workflow "ci.yml" "main"
  assert_success
  assert_output --partial "Waiting for workflow to complete"
  assert_output --partial "Monitoring workflow run ID: 12345"
  assert_output --partial "Workflow completed successfully"

  unstub gh
  unstub sleep
}

@test "wait_for_workflow fails when no run ID found" {
  stub gh \
    "run list --workflow=ci.yml --branch=main --limit=1 --json databaseId --jq .[0].databaseId : echo ''; exit 0"

  stub sleep \
    "5 : exit 0"

  run wait_for_workflow "ci.yml" "main"
  assert_failure
  assert_output --partial "Could not find workflow run ID"

  unstub gh
  unstub sleep
}

@test "wait_for_workflow fails when workflow run fails" {
  stub gh \
    "run list --workflow=ci.yml --branch=main --limit=1 --json databaseId --jq .[0].databaseId : echo '12345'; exit 0" \
    "run watch 12345 --exit-status : exit 1" \
    "run view 12345 : echo 'Workflow failed'; exit 0"

  stub sleep \
    "5 : exit 0"

  run wait_for_workflow "ci.yml" "main"
  assert_failure
  assert_output --partial "Workflow run failed or was cancelled"

  unstub gh
  unstub sleep
}
