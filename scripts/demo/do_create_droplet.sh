#!/usr/bin/env bash
# do_create_droplet.sh - Provision the temporary SiagaKita demo droplet on DigitalOcean.
#
# Purpose: Boot a single 1 vCPU / 2 GB droplet in Singapore for the exhibition and
#          expose only SSH (22) and HTTP (80).
# Data & Logic Flow: doctl + DO_API_TOKEN -> droplet (Ubuntu 24.04) -> wait for public
#          IP -> print the deploy command.
# Key Components: doctl, cloud-init user-data, ufw, optional DO Cloud Firewall.
#
# Two host-firewall strategies, chosen automatically by token permissions:
#   1. "firewall"  - a DO Cloud Firewall + a registered DO SSH key. Requires the
#                    Firewalls and SSH Keys scopes on the API token.
#   2. "userdata"  - no DO-side resources at all: the SSH public key is injected via
#                    cloud-init and ufw allows only 22/tcp and 80/tcp. Requires only
#                    the Droplets scope. This is the fallback when the token is
#                    scoped to Droplets only (DO tokens cannot be re-scoped).
#
# Both strategies produce the same result: a droplet reachable on 22 and 80 only.
#
# Idempotent: an existing droplet or firewall with the configured name is reused.
#
# Usage:
#   export DO_API_TOKEN=$(cat /tmp/opencode/do-token)
#   ./scripts/demo/do_create_droplet.sh
#
# Teardown (after the exhibition):
#   doctl compute droplet delete siagakita-demo --force
#   doctl compute firewall delete siagakita-demo-fw --force   # only in firewall mode
set -euo pipefail

DROPLET_NAME="${DROPLET_NAME:-siagakita-demo}"
FIREWALL_NAME="${FIREWALL_NAME:-siagakita-demo-fw}"
DO_REGION="${DO_REGION:-sgp1}"
DO_SIZE="${DO_SIZE:-s-1vcpu-2gb}"
DO_IMAGE="${DO_IMAGE:-ubuntu-24-04-x64}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519_siagakita_demo.pub}"
SSH_KEY_NAME="${SSH_KEY_NAME:-siagakita-demo-key}"
TOKEN_FILE="${TOKEN_FILE:-/tmp/opencode/do-token}"
SSH_ALLOWED_SOURCES="${SSH_ALLOWED_SOURCES:-}"
HOST_FIREWALL="${HOST_FIREWALL:-auto}"   # auto | firewall | userdata

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- 0. Preflight ------------------------------------------------------------
command -v doctl >/dev/null 2>&1 || fail "doctl not installed. See scripts/demo/README.md."

if [[ -z "${DO_API_TOKEN:-}" && -f "$TOKEN_FILE" ]]; then
  DO_API_TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
fi
[[ -n "${DO_API_TOKEN:-}" ]] || fail "No DigitalOcean token. Set DO_API_TOKEN or write it to $TOKEN_FILE."
export DIGITALOCEAN_ACCESS_TOKEN="$DO_API_TOKEN"

[[ -f "$SSH_KEY_PATH" ]] || fail "SSH public key not found: $SSH_KEY_PATH (override with SSH_KEY_PATH=...)"

# A passphrase-protected key cannot be unlocked under BatchMode=yes, which would
# turn every SSH call into "Permission denied (publickey)" with no prompt. Catch it here.
if [[ -f "${SSH_KEY_PATH%.pub}" ]] && ! ssh-keygen -yf "${SSH_KEY_PATH%.pub}" >/dev/null 2>&1; then
  fail "Private key ${SSH_KEY_PATH%.pub} needs a passphrase or is unreadable.
       The deploy scripts run SSH with BatchMode=yes. Generate a dedicated key:
         ssh-keygen -t ed25519 -N '' -C siagakita-demo-droplet -f ~/.ssh/id_ed25519_siagakita_demo
       then re-run with SSH_KEY_PATH=~/.ssh/id_ed25519_siagakita_demo.pub"
fi

log "Verifying DigitalOcean credentials..."
if doctl compute droplet list --format ID --no-header >/dev/null 2>&1; then
  log "Token can manage droplets."
else
  fail "Token cannot list droplets. It needs the Droplets scope (create/read)."
fi

# --- 1. Reuse an existing droplet -------------------------------------------
EXISTING_ID="$(doctl compute droplet list --format ID,Name --no-header | awk -v n="$DROPLET_NAME" '$2==n {print $1}' | head -1)"
if [[ -n "$EXISTING_ID" ]]; then
  IP="$(doctl compute droplet get "$EXISTING_ID" --format PublicIPv4 --no-header)"
  log "Droplet '$DROPLET_NAME' already exists (id=$EXISTING_ID, ip=$IP)."
  log "Next: ./scripts/demo/deploy_demo.sh $IP"
  exit 0
fi

# --- 2. Decide the host-firewall strategy -----------------------------------
can_firewall() { doctl compute firewall list --format ID --no-header >/dev/null 2>&1; }
can_sshkey()   { doctl compute ssh-key list --format ID --no-header >/dev/null 2>&1; }

if [[ "$HOST_FIREWALL" == "auto" ]]; then
  if can_firewall && can_sshkey; then
    HOST_FIREWALL="firewall"
  else
    HOST_FIREWALL="userdata"
  fi
fi

case "$HOST_FIREWALL" in
  firewall) log "Strategy: DO Cloud Firewall + registered DO SSH key." ;;
  userdata) log "Strategy: cloud-init user-data (SSH key + ufw). Token lacks Firewalls/SSH Keys scope." ;;
  *) fail "HOST_FIREWALL must be auto, firewall, or userdata (got '$HOST_FIREWALL')." ;;
esac

if [[ -z "$SSH_ALLOWED_SOURCES" ]]; then
  SSH_ALLOWED_SOURCES="$(curl -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)/32"
  if [[ "$SSH_ALLOWED_SOURCES" == "/32" ]]; then
    SSH_ALLOWED_SOURCES="0.0.0.0/0"
    log "WARNING: could not detect the workstation egress IP."
    log "WARNING: SSH (22) will be open to 0.0.0.0/0 for the lifetime of this droplet."
    log "WARNING: root password login stays disabled, so this is key-only, but it is"
    log "WARNING: exposed to the public internet. Set SSH_ALLOWED_SOURCES=<ip>/32 to pin it."
  else
    log "SSH (22) restricted to workstation egress: $SSH_ALLOWED_SOURCES"
  fi
fi

# --- 3a. firewall strategy: DO firewall + DO key ----------------------------
KEY_FINGERPRINT=""
FIREWALL_ID=""
if [[ "$HOST_FIREWALL" == "firewall" ]]; then
  FIREWALL_ID="$(doctl compute firewall list --format ID,Name --no-header | awk -v n="$FIREWALL_NAME" '$2==n {print $1}' | head -1)"
  if [[ -z "$FIREWALL_ID" ]]; then
    log "Creating Cloud Firewall '$FIREWALL_NAME'..."
    FIREWALL_ID="$(doctl compute firewall create \
      --name "$FIREWALL_NAME" \
      --inbound-rules "protocol:tcp,ports:22,address:$SSH_ALLOWED_SOURCES protocol:tcp,ports:80,address:0.0.0.0/0 protocol:tcp,ports:80,address:::/0" \
      --outbound-rules "protocol:tcp,ports:all,address:0.0.0.0/0 protocol:udp,ports:all,address:0.0.0.0/0 protocol:icmp,address:0.0.0.0/0" \
      --format ID --no-header)"
    log "Firewall created: $FIREWALL_ID"
  else
    log "Cloud Firewall '$FIREWALL_NAME' already exists ($FIREWALL_ID)."
  fi

  KEY_FINGERPRINT="$(doctl compute ssh-key list --format FingerPrint,Name --no-header | awk -v n="$SSH_KEY_NAME" '$2==n {print $1}' | head -1)"
  if [[ -z "$KEY_FINGERPRINT" ]]; then
    log "Registering SSH key '$SSH_KEY_NAME'..."
    KEY_FINGERPRINT="$(doctl compute ssh-key import "$SSH_KEY_NAME" \
      --public-key-file "$SSH_KEY_PATH" --format FingerPrint --no-header)"
  fi
  log "SSH key fingerprint: $KEY_FINGERPRINT"
fi

# --- 3b. userdata strategy: cloud-init key + ufw ----------------------------
USER_DATA_FILE=""
if [[ "$HOST_FIREWALL" == "userdata" ]]; then
  USER_DATA_FILE="$(mktemp /tmp/opencode/siagakita-demo-cloud-init.XXXXXX.yaml)"
  PUBKEY="$(cat "$SSH_KEY_PATH")"
  if [[ "$SSH_ALLOWED_SOURCES" == "0.0.0.0/0" ]]; then
    SSH_UFW_RULE="ufw allow 22/tcp"
  else
    SSH_UFW_RULE="ufw allow from ${SSH_ALLOWED_SOURCES} to any port 22 proto tcp"
  fi

  # Written as a quoted heredoc: no shell expansion, so no escaping can corrupt
  # the generated YAML. __PUBKEY__ is substituted afterwards with a literal-safe
  # Python replace, and the result is validated as YAML before use.
  cat > "$USER_DATA_FILE" <<'YAML'
#cloud-config
# SiagaKita demo droplet bootstrap: shell access + host firewall only.
# Docker, directories, migration, and seeding are handled later by remote_setup.sh.
#
# The top-level key targets cloud-init's default user (ubuntu) as a backup path.
# Root's key is written explicitly because Ubuntu cloud images do not apply
# ssh_authorized_keys to root.
ssh_pwauth: false
ssh_authorized_keys:
  - __PUBKEY__
write_files:
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      __PUBKEY__
runcmd:
  # DigitalOcean sets an expired root password when a droplet is created without
  # --ssh-keys (which our Droplets-only token cannot set). sshd's PAM account
  # phase then refuses every session with "You are required to change your
  # password immediately", even for key-based logins. Clear the expiry here.
  - chage -d "$(date +%F)" -M 99999 root
  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  - systemctl reload ssh || systemctl reload sshd || true
  - ufw default deny incoming
  - ufw default allow outgoing
  - __SSH_UFW_RULE__
  - ufw allow 80/tcp
  - ufw --force enable
YAML

  python3 - "$USER_DATA_FILE" "$PUBKEY" "$SSH_UFW_RULE" <<'PY'
import sys
import yaml

path, pubkey, ssh_rule = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read().replace("__PUBKEY__", pubkey).replace("__SSH_UFW_RULE__", ssh_rule)
open(path, "w").write(text)

doc = yaml.safe_load(text)
assert isinstance(doc, dict), "user-data root must be a mapping"
assert doc["write_files"][0]["path"] == "/root/.ssh/authorized_keys", "root key path wrong"
assert doc["write_files"][0]["content"].strip() == pubkey, "root key content mismatch"
assert any(pubkey in k for k in doc["ssh_authorized_keys"]), "backup key missing"
cmds = doc["runcmd"]
assert any("ufw allow" in str(c) for c in cmds), "ufw allow rule missing"
assert any("80/tcp" in str(c) for c in cmds), "port 80 rule missing"
print(f"  user-data validated: {len(cmds)} runcmd steps, root key + ubuntu key + ufw 22/80")
PY

  log "Cloud-init user-data prepared and YAML-validated: $USER_DATA_FILE"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "DRY_RUN=1: stopping before droplet creation. User-data: $USER_DATA_FILE"
    sed -n '1,40p' "$USER_DATA_FILE"
    exit 0
  fi
fi

# --- 4. Create the droplet --------------------------------------------------
CREATE_ARGS=(
  --region "$DO_REGION"
  --size "$DO_SIZE"
  --image "$DO_IMAGE"
  --enable-monitoring
  --wait
  --format ID --no-header
)
[[ -n "$KEY_FINGERPRINT" ]] && CREATE_ARGS+=(--ssh-keys "$KEY_FINGERPRINT")
[[ -n "$USER_DATA_FILE" ]] && CREATE_ARGS+=(--user-data-file "$USER_DATA_FILE")

log "Creating droplet '$DROPLET_NAME' ($DO_SIZE @ $DO_REGION)..."
DROPLET_ID="$(doctl compute droplet create "$DROPLET_NAME" "${CREATE_ARGS[@]}")"
[[ -n "$USER_DATA_FILE" ]] && rm -f "$USER_DATA_FILE"

IP="$(doctl compute droplet get "$DROPLET_ID" --format PublicIPv4 --no-header)"
[[ -n "$IP" ]] || fail "Droplet created but no public IPv4 was assigned yet. Retry in a few seconds."

if [[ -n "$FIREWALL_ID" ]]; then
  log "Attaching firewall $FIREWALL_ID to droplet $DROPLET_ID..."
  doctl compute firewall add-droplets "$FIREWALL_ID" --droplet-ids "$DROPLET_ID" >/dev/null
fi

# --- 5. Wait for SSH (cloud-init installs the key in userdata mode) ---------
log "Waiting for SSH on $IP (cloud-init may still be running)..."
SSH_READY=0
SSH_LAST_ERROR=""
for attempt in $(seq 1 48); do
  if SSH_LAST_ERROR="$(ssh -i "${SSH_KEY_PATH%.pub}" -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=5 -o BatchMode=yes "root@$IP" true 2>&1)"; then
    SSH_READY=1
    log "SSH is up (attempt $attempt)."
    break
  fi
  sleep 5
done

printf '\n'
if [[ "$SSH_READY" == "1" ]]; then
  printf '===============================================================\n'
  printf ' Droplet ready\n'
  printf '   id        : %s\n' "$DROPLET_ID"
  printf '   ip        : %s\n' "$IP"
  printf '   firewall  : %s\n' "$HOST_FIREWALL"
  printf '   health    : http://%s/health (after deploy)\n' "$IP"
  printf '===============================================================\n'
  printf ' Next step:\n'
  printf '   ./scripts/demo/deploy_demo.sh %s\n\n' "$IP"
else
  printf 'Droplet %s exists at %s but SSH is not reachable yet.\n' "$DROPLET_ID" "$IP"
  printf 'last error: %s\n' "${SSH_LAST_ERROR:-<none captured>}"
  printf 'cloud-init can take a minute on first boot. Retry in 60s:\n'
  printf '   ssh -i %s root@%s\n\n' "${SSH_KEY_PATH%.pub}" "$IP"
  exit 1
fi
