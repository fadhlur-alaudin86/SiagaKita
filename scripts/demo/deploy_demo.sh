#!/usr/bin/env bash
# deploy_demo.sh - Ship and start the SiagaKita demo stack on the demo droplet.
#
# Purpose: One command from the workstation to a fully seeded, publicly reachable
#          HTTP demo stack. No Docker Hub, no CI - the backend image is exported
#          locally and copied over SSH.
# Data & Logic Flow:
#   1. verify local image siagakita-api:<IMAGE_TAG> exists (build if missing)
#   2. render infrastructure/.env.demo for the droplet IP into a staging dir
#   3. docker save | gzip the image
#   4. scp image + compose + nginx conf + seeder + remote_setup.sh to the droplet
#   5. ssh: run remote_setup.sh (Docker install, load image, migrate, compose up, seed)
#   6. verify http://<ip>/health from the workstation
# Key Components: docker, scp, ssh; staging dir under /tmp/opencode.
#
# Usage:
#   ./scripts/demo/deploy_demo.sh <droplet-ip>
#
# Env overrides:
#   IMAGE_TAG=1.1.0-demo        backend image tag
#   SSH_KEY=~/.ssh/id_ed25519_siagakita_demo
#   REMOTE_DIR=/opt/siagakita   target directory on the droplet
#   STAGE_DIR=/tmp/opencode/siagakita-demo-stage
#   FORCE_REBUILD=1             rebuild the image before shipping
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

DROPLET_IP="${1:?usage: deploy_demo.sh <droplet-ip>}"
IMAGE_TAG="${IMAGE_TAG:-1.1.0-demo}"
IMAGE_REF="siagakita-api:${IMAGE_TAG}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_siagakita_demo}"
SSH_USER="${SSH_USER:-root}"
REMOTE_DIR="${REMOTE_DIR:-/opt/siagakita}"
STAGE_DIR="${STAGE_DIR:-/tmp/opencode/siagakita-demo-stage}"
FORCE_REBUILD="${FORCE_REBUILD:-0}"

SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30)
REMOTE="${SSH_USER}@${DROPLET_IP}"

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- 0. Preflight ------------------------------------------------------------
[[ -f "$SSH_KEY" ]] || fail "SSH private key not found: $SSH_KEY"
[[ -f infrastructure/.env.prod ]] || fail "infrastructure/.env.prod missing - it supplies the real credentials."
[[ -f infrastructure/docker-compose.demo.yml ]] || fail "infrastructure/docker-compose.demo.yml missing."
[[ -f infrastructure/nginx/nginx.demo.conf ]] || fail "infrastructure/nginx/nginx.demo.conf missing."
[[ -f scripts/demo/seed_demo_data.sql ]] || fail "scripts/demo/seed_demo_data.sql missing."

log "Checking connectivity to $REMOTE ..."
ssh "${SSH_OPTS[@]}" -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE" true 2>/dev/null \
  || fail "Cannot SSH to $REMOTE. Is the droplet up and port 22 open to your current IP?"

# --- 1. Backend image --------------------------------------------------------
if [[ "$FORCE_REBUILD" == "1" ]] || ! docker image inspect "$IMAGE_REF" >/dev/null 2>&1; then
  log "Building backend image $IMAGE_REF ..."
  docker build -t "$IMAGE_REF" ./backend-go
else
  log "Using existing local image $IMAGE_REF."
fi

# --- 2. Render .env.demo for this droplet IP ---------------------------------
mkdir -p "$STAGE_DIR/nginx"
log "Rendering $STAGE_DIR/.env.demo from infrastructure/.env.prod ..."
python3 - "$REPO_ROOT" "$DROPLET_IP" "$IMAGE_TAG" "$STAGE_DIR" <<'PY'
import pathlib, sys

repo_root, ip, image_tag, stage_dir = sys.argv[1:5]
src = pathlib.Path(repo_root) / "infrastructure" / ".env.prod"
dst = pathlib.Path(stage_dir) / ".env.demo"

base = "http://" + ip
overrides = {
    "API_HOST": ip,
    "GO_ENV": "production",
    # A concrete origin list, never "*": the WebSocket upgrader at
    # backend-go/internal/ws/handler.go compares the Origin header literally, so
    # "*" never matches a browser and a browser console would be rejected at the
    # handshake. The droplet origin is what the served /console/ bundle runs
    # from; the localhost entries cover serving the web build locally.
    "CORS_ALLOWED_ORIGINS": f"{base},http://localhost:8080,http://127.0.0.1:8080",
    "API_BASE_URL": base + "/api/v1",
    "WS_BASE_URL": "ws://" + ip + "/v1/ws/connect",
    "UPLOAD_BASE_URL": base + "/uploads",
    "IMAGE_TAG": image_tag,
    "DOCKERHUB_USERNAME": "",  # demo never pulls from a registry
}

lines, seen = [], set()
for raw in src.read_text().splitlines():
    stripped = raw.strip()
    if stripped and not stripped.startswith("#") and "=" in stripped:
        key = stripped.split("=", 1)[0].strip()
        if key in overrides:
            lines.append(f"{key}={overrides[key]}")
            seen.add(key)
            continue
    lines.append(raw)

for key, value in overrides.items():
    if key not in seen:
        lines.append(f"{key}={value}")

dst.write_text("\n".join(lines) + "\n")

required = ["DB_USER", "DB_PASSWORD", "DB_NAME", "REDIS_PASSWORD", "JWT_SECRET",
            "SUPERADMIN_EMAIL", "SUPERADMIN_PASS", "IMAGE_TAG"]
text = dst.read_text()
missing = [k for k in required if f"\n{k}=" not in "\n" + text]
if missing:
    raise SystemExit("ERROR: rendered .env.demo is missing required keys: " + ", ".join(missing))

print(f"  .env.demo written ({len(lines)} lines), IP={ip}, tag={image_tag}")
PY

cp infrastructure/docker-compose.demo.yml "$STAGE_DIR/docker-compose.demo.yml"
cp infrastructure/nginx/nginx.demo.conf    "$STAGE_DIR/nginx/nginx.demo.conf"
cp scripts/demo/seed_demo_data.sql         "$STAGE_DIR/seed_demo_data.sql"
cp scripts/demo/remote_setup.sh            "$STAGE_DIR/remote_setup.sh"

# --- 3. Export the image -----------------------------------------------------
IMAGE_TAR="$STAGE_DIR/siagakita-api-${IMAGE_TAG}.tar.gz"
log "Exporting $IMAGE_REF to $IMAGE_TAR ..."
docker save "$IMAGE_REF" | gzip -1 > "$IMAGE_TAR"
log "Image archive: $(du -h "$IMAGE_TAR" | cut -f1)"

# --- 4. Upload everything ----------------------------------------------------
# The nginx directory must exist before scp: remote_setup.sh, which creates the
# full directory tree, only runs after this upload step.
log "Creating $REMOTE_DIR/{,nginx} on the droplet ..."
ssh "${SSH_OPTS[@]}" "$REMOTE" "mkdir -p $REMOTE_DIR $REMOTE_DIR/nginx"

log "Uploading artifacts ..."
scp -q "${SSH_OPTS[@]}" "$IMAGE_TAR" "$REMOTE:$REMOTE_DIR/"
scp -q "${SSH_OPTS[@]}" \
  "$STAGE_DIR/docker-compose.demo.yml" \
  "$STAGE_DIR/.env.demo" \
  "$STAGE_DIR/seed_demo_data.sql" \
  "$STAGE_DIR/remote_setup.sh" \
  "$REMOTE:$REMOTE_DIR/"
scp -q "${SSH_OPTS[@]}" "$STAGE_DIR/nginx/nginx.demo.conf" "$REMOTE:$REMOTE_DIR/nginx/"

# Optional: the Flutter web build of the desktop console. When present it is
# served at http://<ip>/console/, so any browser can run a console instance with
# nothing installed (two tabs = admin + agency consoles side by side).
CONSOLE_WEB_DIR="windows_console_flutter/build/web"
if [[ -f "$CONSOLE_WEB_DIR/index.html" ]]; then
  log "Uploading the console web build ($(du -sh "$CONSOLE_WEB_DIR" | cut -f1)) ..."
  ssh "${SSH_OPTS[@]}" "$REMOTE" "rm -rf $REMOTE_DIR/console-web && mkdir -p $REMOTE_DIR/console-web"
  scp -q -r "${SSH_OPTS[@]}" "$CONSOLE_WEB_DIR/." "$REMOTE:$REMOTE_DIR/console-web/"
else
  log "No console web build at $CONSOLE_WEB_DIR; skipping. Build it with:"
  log "  cd windows_console_flutter && flutter build web --release --base-href=/console/ --no-web-resources-cdn --dart-define-from-file=../env/demo.env"
fi

# --- 5. Bootstrap the droplet ------------------------------------------------
log "Running remote bootstrap (Docker install, image load, migrate, compose up, seed) ..."
log "This takes roughly 3-6 minutes on a fresh droplet."
ssh "${SSH_OPTS[@]}" "$REMOTE" "chmod +x $REMOTE_DIR/remote_setup.sh && $REMOTE_DIR/remote_setup.sh '$IMAGE_TAG'"

# --- 6. Verify from the workstation ------------------------------------------
log "Verifying http://$DROPLET_IP/health from the workstation ..."
HEALTH_OK=0
for _ in $(seq 1 12); do
  if curl -fsS --max-time 10 "http://$DROPLET_IP/health" >/dev/null 2>&1; then
    HEALTH_OK=1
    break
  fi
  sleep 5
done

printf '\n'
if [[ "$HEALTH_OK" == "1" ]]; then
  printf '===============================================================\n'
  printf ' DEMO STACK IS LIVE\n'
  printf '   API base     : http://%s/api/v1\n' "$DROPLET_IP"
  printf '   WebSocket    : ws://%s/v1/ws/connect\n' "$DROPLET_IP"
  printf '   Uploads      : http://%s/uploads\n' "$DROPLET_IP"
  printf '   Console (web): http://localhost:8080/console/ after the SSH tunnel\n'
  printf '                  ssh -i <key> -N -L 8080:127.0.0.1:80 root@%s\n' "$DROPLET_IP"
  printf '   Health       : http://%s/health\n' "$DROPLET_IP"
  printf '   Password     : %s\n' "${SIAGAKITA_DEMO_PASSWORD:-see the operator package (SIAGAKITA_DEMO_PASSWORD)}"
  printf '===============================================================\n'
  printf ' Build the clients against this endpoint next:\n'
  printf '   cd mobile-flutter && flutter build apk --release \\\n'
  printf '     --dart-define=API_BASE_URL=http://%s/api/v1 \\\n' "$DROPLET_IP"
  printf '     --dart-define=WS_BASE_URL=ws://%s/v1/ws/connect\n' "$DROPLET_IP"
  printf ' Or emit a shareable client config for teammates, then build with\n'
  printf '   --dart-define-from-file=../env/demo.env :\n'
  printf '     ./scripts/demo/write_client_env.sh %s\n\n' "$DROPLET_IP"
  printf ' Re-seed or inspect at any time:\n'
  printf '   ssh -i %s %s\n' "$SSH_KEY" "$REMOTE"
  printf '   docker exec -it siagakita_postgres psql -U siagakita_admin -d siagakita\n\n'
  printf ' Teardown after the exhibition:\n'
  printf '   doctl compute droplet delete siagakita-demo --force\n'
  printf '   # only if provisioned with the Cloud Firewall strategy (see do_create_droplet.sh output):\n'
  printf '   # doctl compute firewall delete siagakita-demo-fw --force\n\n'
else
  printf 'ERROR: http://%s/health did not respond.\n' "$DROPLET_IP"
  printf 'Inspect on the droplet:\n'
  printf '  ssh -i %s %s "docker compose --env-file %s/.env.demo -f %s/docker-compose.demo.yml ps && docker logs --tail 100 siagakita_backend"\n' \
    "$SSH_KEY" "$REMOTE" "$REMOTE_DIR" "$REMOTE_DIR"
  exit 1
fi
