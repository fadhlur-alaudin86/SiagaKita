#!/usr/bin/env bash
# destroy_droplet.sh - Tear down the demo droplet and stop the billing clock.
#
# Purpose: Remove the throwaway exhibition droplet (and the DO Cloud Firewall when
#          one was created) so no charges continue after the exhibition.
# Data & Logic Flow: read the DO token -> resolve the droplet by name -> print a
#          summary -> require an explicit confirmation -> delete -> verify gone.
# Key Components: doctl compute droplet, doctl compute firewall (best effort).
#
# Usage:
#   ./scripts/demo/destroy_droplet.sh                 # interactive confirmation
#   ./scripts/demo/destroy_droplet.sh --yes           # no prompt (CI or scripted)
#   DROPLET_NAME=other ./scripts/demo/destroy_droplet.sh
#
# Requires: doctl, DO_API_TOKEN (or /tmp/opencode/do-token).

set -euo pipefail

DROPLET_NAME="${DROPLET_NAME:-siagakita-demo}"
FIREWALL_NAME="${FIREWALL_NAME:-siagakita-demo-fw}"

log() { printf '[destroy] %s\n' "$*"; }
fail() { printf '[destroy] ERROR: %s\n' "$*" >&2; exit 1; }

ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) fail "unknown argument '$arg' (use --yes to skip the prompt)" ;;
  esac
done

command -v doctl >/dev/null 2>&1 || fail "doctl not found in PATH."

# Accept either variable name so a caller that already exported doctl's own
# DIGITALOCEAN_ACCESS_TOKEN is not rejected.
if [[ -z "${DO_API_TOKEN:-}" ]]; then
  DO_API_TOKEN="${DIGITALOCEAN_ACCESS_TOKEN:-}"
fi

if [[ -z "${DO_API_TOKEN:-}" ]]; then
  TOKEN_FILE="${DO_TOKEN_FILE:-/tmp/opencode/do-token}"
  [[ -f "$TOKEN_FILE" ]] || fail "No token: set DO_API_TOKEN or DIGITALOCEAN_ACCESS_TOKEN, or write $TOKEN_FILE."
  DO_API_TOKEN="$(tr -d '\n\r' < "$TOKEN_FILE")"
fi

# doctl authenticates from DIGITALOCEAN_ACCESS_TOKEN, not from DO_API_TOKEN.
export DIGITALOCEAN_ACCESS_TOKEN="$DO_API_TOKEN"

DROPLET_ID="$(doctl compute droplet list --format ID,Name --no-header \
  | awk -v n="$DROPLET_NAME" '$2==n {print $1}' | head -1)"

if [[ -z "$DROPLET_ID" ]]; then
  log "No droplet named '$DROPLET_NAME' exists; nothing to delete."
else
  DROPLET_IP="$(doctl compute droplet get "$DROPLET_ID" --format PublicIPv4 --no-header || true)"
  log "About to destroy: $DROPLET_NAME (id $DROPLET_ID, ip ${DROPLET_IP:-unknown})"
  log "This is irreversible. Database contents on the droplet are lost."

  if [[ "$ASSUME_YES" -ne 1 ]]; then
    read -r -p "Type the droplet name to confirm: " CONFIRM
    [[ "$CONFIRM" == "$DROPLET_NAME" ]] || fail "confirmation did not match; aborted."
  fi

  doctl compute droplet delete "$DROPLET_ID" --force
  log "Droplet delete requested."
fi

# The Cloud Firewall only exists in the firewall provisioning strategy. A token
# without the Firewalls scope answers 403 here, which is expected and harmless.
if doctl compute firewall list --format ID --no-header >/dev/null 2>&1; then
  FIREWALL_ID="$(doctl compute firewall list --format ID,Name --no-header \
    | awk -v n="$FIREWALL_NAME" '$2==n {print $1}' | head -1)"
  if [[ -n "$FIREWALL_ID" ]]; then
    doctl compute firewall delete "$FIREWALL_ID" --force
    log "Cloud Firewall '$FIREWALL_NAME' deleted."
  else
    log "No Cloud Firewall named '$FIREWALL_NAME'; nothing to delete."
  fi
else
  log "Token cannot list Cloud Firewalls (expected in the userdata strategy); skipped."
fi

# Verify the droplet is really gone, so "destroyed" is a checked claim.
for _ in $(seq 1 20); do
  if ! doctl compute droplet list --format Name --no-header | grep -qx "$DROPLET_NAME"; then
    log "Verified: '$DROPLET_NAME' is no longer listed. Billing has stopped."
    exit 0
  fi
  sleep 3
done

fail "Droplet '$DROPLET_NAME' is still listed after 60s; check the DigitalOcean console."
