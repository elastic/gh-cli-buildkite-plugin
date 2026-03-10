#!/usr/bin/env bash

set -euo pipefail

# Run a GitHub workflow
run_workflow() {
  local workflow_file="${1}"
  local workflow_ref="${2}"
  local workflow_inputs="${3:-}"
  local should_wait="${4:-false}"

  if [[ -z "${workflow_file}" ]]; then
    echo "No workflow file specified, skipping workflow execution" >&2
    return 0
  fi

  echo "Running GitHub workflow: ${workflow_file}"
  echo "Reference: ${workflow_ref}"

  # Build the gh workflow run command
  local gh_cmd="gh workflow run ${workflow_file} --ref ${workflow_ref}"

  # Add workflow inputs if provided
  if [[ -n "${workflow_inputs}" ]]; then
    echo "Workflow inputs: ${workflow_inputs}"

    # Parse the inputs (expecting JSON format)
    # Convert JSON object to --field arguments
    while IFS= read -r line; do
      if [[ -n "${line}" ]]; then
        gh_cmd="${gh_cmd} ${line}"
      fi
    done < <(echo "${workflow_inputs}" | jq -r 'to_entries[] | "--field \(.key)=\(.value)"')
  fi

  # Execute the workflow
  echo "Executing: ${gh_cmd}"
  if ! eval "${gh_cmd}"; then
    echo "Failed to trigger workflow" >&2
    return 1
  fi

  echo "Workflow triggered successfully"

  # Wait for workflow to complete if requested
  if [[ "${should_wait}" == "true" ]]; then
    wait_for_workflow "${workflow_file}" "${workflow_ref}"
  fi
}

# Wait for the most recent workflow run to complete
wait_for_workflow() {
  local workflow_file="${1}"
  local workflow_ref="${2}"

  echo "Waiting for workflow to complete..."

  # Give the workflow a moment to start
  sleep 5

  # Get the most recent run ID for this workflow
  local run_id
  run_id=$(gh run list --workflow="${workflow_file}" --branch="${workflow_ref}" --limit=1 --json databaseId --jq '.[0].databaseId')

  if [[ -z "${run_id}" ]]; then
    echo "Could not find workflow run ID" >&2
    return 1
  fi

  echo "Monitoring workflow run ID: ${run_id}"

  # Watch the workflow run
  if ! gh run watch "${run_id}" --exit-status; then
    echo "Workflow run failed or was cancelled" >&2

    # Get the workflow run details for better error reporting
    gh run view "${run_id}"

    return 1
  fi

  echo "Workflow completed successfully"
  gh run view "${run_id}"
}
