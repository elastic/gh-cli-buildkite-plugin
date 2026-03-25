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

  if [[ "${should_wait}" == "true" ]]; then
    # Capture the most recent run ID before triggering (fallback for gh < 2.87.0)
    local prev_run_id=""
    prev_run_id=$(gh run list --workflow="${workflow_file}" --branch="${workflow_ref}" --limit=1 --json databaseId --jq '.[0].databaseId//empty' 2>/dev/null || true)

    # Capture gh output to extract run URL (available in gh >= 2.87.0)
    local gh_output=""
    if ! gh_output=$(eval "${gh_cmd}" 2>&1); then
      echo "Failed to trigger workflow" >&2
      echo "${gh_output}" >&2
      return 1
    fi
    echo "${gh_output}"

    echo "Workflow triggered successfully"

    # Try to extract run ID directly from gh output (gh >= 2.87.0 prints the run URL)
    local direct_run_id=""
    if [[ "${gh_output}" =~ actions/runs/([0-9]+) ]]; then
      direct_run_id="${BASH_REMATCH[1]}"
    fi

    wait_for_workflow "${workflow_file}" "${workflow_ref}" "${prev_run_id}" "${direct_run_id}"
  else
    if ! eval "${gh_cmd}"; then
      echo "Failed to trigger workflow" >&2
      return 1
    fi
    echo "Workflow triggered successfully"
  fi
}

# Wait for the most recent workflow run to complete
wait_for_workflow() {
  local workflow_file="${1}"
  local workflow_ref="${2}"
  local prev_run_id="${3:-}"
  local direct_run_id="${4:-}"  # run ID from gh output (gh >= 2.87.0)

  echo "Waiting for workflow to complete..."

  local run_id="${direct_run_id}"

  if [[ -z "${run_id}" ]]; then
    # Poll for the new workflow run, retrying until a run different from prev_run_id appears
    local max_attempts="${WORKFLOW_WAIT_MAX_ATTEMPTS:-12}"
    local attempt=0

    while [[ -z "${run_id}" && ${attempt} -lt ${max_attempts} ]]; do
      sleep 5
      attempt=$((attempt + 1))

      local latest_run_id
      latest_run_id=$(gh run list --workflow="${workflow_file}" --branch="${workflow_ref}" --limit=1 --json databaseId --jq '.[0].databaseId//empty')

      if [[ -n "${latest_run_id}" && "${latest_run_id}" != "${prev_run_id}" ]]; then
        run_id="${latest_run_id}"
      fi
    done
  fi

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
