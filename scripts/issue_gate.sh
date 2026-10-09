#!/usr/bin/env bash
#
# issue_gate.sh — Mechanical enforcement for acceptance-criteria checkoff.
#
# Prose workflow rules are forgettable; this gate is not. It exits 0 only
# when the given PR has no failed checks and nothing still running, so an
# agent can only sync issue checkboxes after real CI verification.
#
# Usage:
#   ./scripts/issue_gate.sh <pr-number> [--repo OWNER/REPO]
#
# Exit codes: 0 = green, 1 = red (failed/cancelled), 2 = still running.
#

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <pr-number> [--repo OWNER/REPO]" >&2
    exit 2
fi

PR="$1"
REPO_ARGS=()
if [ "${2:-}" = "--repo" ] && [ -n "${3:-}" ]; then
    REPO_ARGS=(--repo "$3")
fi

ROLLS=$(gh pr view "$PR" "${REPO_ARGS[@]}" --json statusCheckRollup --jq '.statusCheckRollup')

failed=$(echo "$ROLLS" | jq -r '[.[] | select(.status == "COMPLETED" and (.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT" or .conclusion == "ACTION_REQUIRED")) | .name] | join(", ")')
pending=$(echo "$ROLLS" | jq -r '[.[] | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING" or .status == "WAITING") | .name] | join(", ")')

if [ -n "$failed" ]; then
    echo "[FAIL] PR #$PR has failing checks: $failed" >&2
    exit 1
fi

if [ -n "$pending" ]; then
    echo "[WAIT] PR #$PR still running: $pending" >&2
    exit 2
fi

echo "[PASS] PR #$PR is green — checkbox sync allowed."
