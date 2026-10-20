#!/usr/bin/env bash
# remote_setup.sh - Bootstrap the SiagaKita demo stack on the DigitalOcean droplet.
#
# Purpose: Turn a bare Ubuntu droplet into a running demo stack: Docker Engine, swap
#          headroom, directory layout, image load, schema migration, seed data.
# Data & Logic Flow: runs as root ON THE DROPLET (uploaded by deploy_demo.sh).
#          /opt/siagakita/.env.demo + docker-compose.demo.yml -> docker load image
#          -> migrate up -> compose up -d -> seed_demo_data.sql -> health checks.
# Key Components: docker, docker compose, /opt/siagakita/{uploads,logs,nginx,postgres-data,redis-data}.
#
# Arguments:
#   $1  IMAGE_TAG      (e.g. 1.1.0-demo)   - tag of the already-loaded image
#
# Expected files already present in /opt/siagakita/:
#   .env.demo, docker-compose.demo.yml, nginx/nginx.demo.conf,
#   siagakita-api-<IMAGE_TAG>.tar.gz, seed_demo_data.sql
#
# Idempotent: safe to re-run. Skips Docker install if present, `docker load` is
# a no-op for an identical image, migrations are versioned, the seeder is guarded.
set -euo pipefail

IMAGE_TAG="${1:?usage: remote_setup.sh <IMAGE_TAG>}"
APP_DIR=/opt/siagakita
COMPOSE_FILE="$APP_DIR/docker-compose.demo.yml"
ENV_FILE="$APP_DIR/.env.demo"
IMAGE_REF="siagakita-api:${IMAGE_TAG}"

log()  { printf '[bootstrap] %s\n' "$*"; }
fail() { printf '[bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

# Every compose call must receive --env-file explicitly. Two distinct mechanisms
# are at play and only one of them reads `env_file:` from the YAML:
#   - `env_file:` injects variables INTO a container's environment.
#   - `${VAR}` in the YAML is interpolated by the compose CLI before the file is
#     even parsed, using the shell environment plus the project-directory `.env`.
# Because our file is named .env.demo (not .env), interpolation would resolve
# every ${DB_USER}, ${DB_PASSWORD}, ${DB_NAME} and ${REDIS_PASSWORD} to an empty
# string, and PostgreSQL aborts with "Database is uninitialized and superuser
# password is not specified". Passing --env-file fixes both.
dc() { docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }

[[ -f "$COMPOSE_FILE" ]] || fail "$COMPOSE_FILE missing - upload it first."
[[ -f "$ENV_FILE" ]] || fail "$ENV_FILE missing - upload it first."

# Guard the interpolation contract before touching Docker: a missing key here
# produces a confusing PostgreSQL init failure several steps later.
for key in DB_USER DB_PASSWORD DB_NAME REDIS_PASSWORD; do
  grep -qE "^${key}=" "$ENV_FILE" || fail "$ENV_FILE has no ${key}= line, which docker-compose.demo.yml interpolates."
done

# Wait out cloud-init / unattended-upgrades holding the apt lock.
log "Waiting for apt/dpkg lock..."
for _ in $(seq 1 60); do
  if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && \
     ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

# --- 1. Swap headroom (PostgreSQL + backend on 2 GB) -------------------------
if ! swapon --show | grep -q '/swapfile'; then
  log "Creating 2 GB swapfile..."
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  sysctl -w vm.swappiness=10 >/dev/null
  grep -q '^vm.swappiness' /etc/sysctl.conf || echo 'vm.swappiness=10' >> /etc/sysctl.conf
else
  log "Swapfile already active."
fi

# --- 2. Docker Engine --------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg >/dev/null
  curl -fsSL https://get.docker.com | sh >/dev/null
  systemctl enable --now docker
else
  log "Docker already installed ($(docker --version))."
fi
docker compose version >/dev/null 2>&1 || fail "docker compose plugin unavailable."

# --- 3. Directory layout -----------------------------------------------------
log "Preparing $APP_DIR layout..."
mkdir -p "$APP_DIR"/{uploads,logs,nginx,console-web,postgres-data,redis-data}
chmod 755 "$APP_DIR"/{uploads,logs}

# --- 4. Load the backend image shipped from the workstation -------------------
if docker image inspect "$IMAGE_REF" >/dev/null 2>&1; then
  log "Image $IMAGE_REF already loaded."
else
  TAR="$APP_DIR/siagakita-api-${IMAGE_TAG}.tar.gz"
  [[ -f "$TAR" ]] || fail "$TAR not found - deploy_demo.sh should have uploaded it."
  log "Loading $TAR (this takes ~30-60s)..."
  gzip -dc "$TAR" | docker load
  docker image inspect "$IMAGE_REF" >/dev/null 2>&1 || fail "Loaded archive does not contain $IMAGE_REF."
  log "Image $IMAGE_REF loaded."
fi

# The uploaded archive is dead weight once the image is in the local store.
rm -f "$APP_DIR/siagakita-api-${IMAGE_TAG}.tar.gz"

# --- 5. Start PostgreSQL and Redis first (backend needs them healthy) ---------
cd "$APP_DIR"
log "Starting postgres + redis..."
dc up -d postgres redis

log "Waiting for PostgreSQL to accept connections..."
for attempt in $(seq 1 40); do
  if docker exec siagakita_postgres sh -c \
      'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    log "PostgreSQL ready."
    break
  fi
  [[ "$attempt" == "40" ]] && { docker logs --tail 50 siagakita_postgres; fail "PostgreSQL never became ready."; }
  sleep 3
done

# --- 6. Apply schema migrations (the API image does NOT auto-migrate) --------
log "Applying database migrations..."
dc run --rm --no-deps backend ./siagakita-migrate up
dc run --rm --no-deps backend ./siagakita-migrate version

# --- 7. Bring up the full stack ----------------------------------------------
log "Starting backend + nginx..."
dc up -d

log "Waiting for backend health check..."
BACKEND_STATE="unknown"
for attempt in $(seq 1 30); do
  BACKEND_STATE="$(docker inspect --format '{{.State.Health.Status}}' siagakita_backend 2>/dev/null || echo unknown)"
  printf '[bootstrap]   attempt %02d: %s\n' "$attempt" "$BACKEND_STATE"
  [[ "$BACKEND_STATE" == "healthy" ]] && break
  if [[ "$(docker inspect --format '{{.State.Status}}' siagakita_backend 2>/dev/null || echo missing)" == "exited" ]]; then
    docker logs --tail 80 siagakita_backend
    fail "Backend container exited during startup."
  fi
  sleep 5
done
[[ "$BACKEND_STATE" == "healthy" ]] || { docker logs --tail 80 siagakita_backend; fail "Backend never became healthy."; }

# --- 8. Seed demo data (idempotent) ------------------------------------------
if [[ -f "$APP_DIR/seed_demo_data.sql" ]]; then
  log "Seeding demo data..."
  docker exec -i siagakita_postgres sh -c \
    'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
    < "$APP_DIR/seed_demo_data.sql"
  log "Demo data seeded."
else
  log "WARNING: seed_demo_data.sql not found, skipping demo data."
fi

# --- 9. Post-flight summary --------------------------------------------------
log "Applying kernel network tuning..."
sysctl -w net.core.somaxconn=1024 >/dev/null 2>&1 || true

printf '\n[bootstrap] === container status ===\n'
dc ps

printf '\n[bootstrap] === nginx config validation ===\n'
if docker exec siagakita_nginx nginx -t 2>&1 | sed 's/^/[bootstrap]   /'; then
  printf '[bootstrap] nginx config is valid.\n'
else
  fail "nginx rejected the uploaded config - see the output above."
fi

printf '\n[bootstrap] === console web route ===\n'
if curl -fsS --max-time 10 -o /dev/null -w '%{http_code}\n' http://127.0.0.1/console/ | grep -q '^200$'; then
  printf '[bootstrap] /console/ serves the web console.\n'
else
  printf '[bootstrap] /console/ not served (console web build was not uploaded).\n'
fi

printf '\n[bootstrap] === public endpoint check ===\n'
curl -fsS --max-time 10 http://127.0.0.1/health && printf '\n' || printf '[bootstrap] health endpoint not reachable yet\n'

printf '\n[bootstrap] Stack is up. Demo accounts password: Siaga#Demo2026\n'
