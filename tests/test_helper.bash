#!/usr/bin/env bash

# Load bats-support and bats-assert if available
# These are typically installed in the buildkite/plugin-tester image
if [[ -f /usr/lib/bats/bats-support/load.bash ]]; then
  load '/usr/lib/bats/bats-support/load.bash'
fi

if [[ -f /usr/lib/bats/bats-assert/load.bash ]]; then
  load '/usr/lib/bats/bats-assert/load.bash'
fi

# If not available, provide basic assert functions
if ! command -v assert_success &> /dev/null; then
  assert_success() {
    if [[ "$status" -ne 0 ]]; then
      echo "Expected success but got status: $status"
      echo "Output: $output"
      return 1
    fi
  }
fi

if ! command -v assert_failure &> /dev/null; then
  assert_failure() {
    if [[ "$status" -eq 0 ]]; then
      echo "Expected failure but got success"
      echo "Output: $output"
      return 1
    fi
  }
fi

if ! command -v assert_output &> /dev/null; then
  assert_output() {
    local expected="$1"
    if [[ "$1" == "--partial" ]]; then
      expected="$2"
      if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
      fi
    else
      if [[ "$output" != "$expected" ]]; then
        echo "Expected output: $expected"
        echo "Actual output: $output"
        return 1
      fi
    fi
  }
fi
