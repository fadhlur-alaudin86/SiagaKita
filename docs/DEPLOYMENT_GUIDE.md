# 🚀 SiagaKita — Production Deployment Guide

> **Production Server IP:** `139.59.99.230` (DigitalOcean VPS)
> **Last Updated:** 8 August 2026

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Initial VPS Infrastructure Setup](#2-initial-vps-infrastructure-setup)
3. [Required GitHub Secrets](#3-required-github-secrets)
4. [Automated CI/CD Workflow](#4-automated-cicd-workflow)
5. [Emergency Manual Deployment](#5-emergency-manual-deployment)
6. [Monitoring & Troubleshooting](#6-monitoring--troubleshooting)
7. [Client Application Configuration](#7-client-application-configuration)
8. [Database Migration Procedures](#8-database-migration-procedures)

---

## 1. Prerequisites

- Docker Hub account with access to repository `siagakita-api`.
- SSH Key configured for server access (`root@139.59.99.230`).
- GitHub Repository with admin permissions to configure **Settings → Secrets and variables → Actions**.

---

## 2. Initial VPS Infrastructure Setup (One-time)

### 2a. Execute Setup Script from Local Machine

```bash
# Copy setup script to server
scp infrastructure/setup_server.sh root@139.59.99.230:/tmp/

# Copy configuration files
scp infrastructure/docker-compose.prod.yml root@139.59.99.230:/opt/siagakita/
scp infrastructure/.env                    root@139.59.99.230:/opt/siagakita/

# SSH to server and run setup
ssh root@139.59.99.230
chmod +x /tmp/setup_server.sh
/tmp/setup_server.sh
```

### 2b. Server Environment Configuration

The `/opt/siagakita/.env` file on the server must contain all required production variables:

```env
DB_USER=siagakita_admin
DB_PASSWORD=<strong_password>
DB_NAME=siagakita
DB_HOST=postgres
DB_PORT=5432

REDIS_PASSWORD=<strong_password>
REDIS_HOST=redis
REDIS_PORT=6379

API_HOST=139.59.99.230
HTTP_PORT=8080
WS_PORT=8081

JWT_SECRET=<random_secret_min_32_chars>
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=168h

FONNTE_TOKEN=<fonnte_api_token>

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=<email@gmail.com>
SMTP_PASSWORD=<gmail_app_password>
SMTP_FROM=<email@gmail.com>

SUPERADMIN_EMAIL=<superadmin_email>
SUPERADMIN_PASS=<strong_password>

DOCKERHUB_USERNAME=<dockerhub_username>

UPLOAD_DIR=/app/uploads
UPLOAD_BASE_URL=http://139.59.99.230:8080/uploads

GO_ENV=production
LOG_PATH=logs/app.log
```

---

## 3. Required GitHub Secrets

Navigate to: **GitHub → Repository → Settings → Secrets and variables → Actions**

Add the following secrets:

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub username | Authentication & image tagging |
| `DOCKERHUB_TOKEN` | Docker Hub access token | Image push authorization |
| `VPS_HOST` | `139.59.99.230` | Production server IP |
| `VPS_USERNAME` | `root` | SSH user |
| `VPS_SSH_KEY` | SSH Private Key content | Automated SSH authentication |

---

## 4. Automated CI/CD Workflow

The SiagaKita deployment pipeline enforces strict quality gates across branches:

```
[ Developer Branch ]
         │
         ▼ PR to dev
  .github/workflows/ci-dev.yml (Path-filtered Go & Flutter checks)
         │
         ▼ Merge to dev → PR to main
  .github/workflows/ci-main.yml (Full CI + Docker build validation)
         │
         ▼ Merge PR to main (includes VERSION file update)
  .github/workflows/auto-tag.yml (Generates git tag v1.X.X)
         │
         ▼ Pushes tag v1.X.X
  .github/workflows/release-deploy.yml
         ├── Job 1: Build Docker image (tags: v1.X.X & latest) → push to Docker Hub
         ├── Job 2: Deploy to VPS via SSH & perform health verification
         │           └── (On failure: automatic rollback to previous container image)
         └── Job 3: Publish GitHub Release with Conventional Commits changelog
```

### Versioning & Automated Tagging

1. Whenever a release is ready, update the root `VERSION` file (e.g., `1.0.25`).
2. Submit a PR from `dev` to `main`.
3. Merging to `main` triggers `auto-tag.yml` which reads `VERSION` and creates tag `v1.0.25`.
4. `release-deploy.yml` builds, deploys, verifies, and creates the GitHub Release automatically.

### Automated Rollback Strategy

During deployment, `release-deploy.yml` polls container status up to 5 times (with 5-second delays):
- If `docker inspect` confirms the backend status is `healthy`, deployment completes.
- If health verification fails, the pipeline automatically halts, pulls the previous Docker image, restores the container, and logs the incident.

---

## 5. Emergency Manual Deployment

If GitHub Actions is unreachable, execute a manual deploy:

```bash
# SSH into production server
ssh root@139.59.99.230
cd /opt/siagakita

# Pull latest image
docker compose -f docker-compose.prod.yml pull backend

# Restart backend service
docker compose -f docker-compose.prod.yml up -d --no-deps backend

# Verify health status
docker ps
curl http://localhost:8080/health
```

---

## 6. Monitoring & Troubleshooting

### Health Check Endpoint

```bash
curl http://139.59.99.230:8080/health
# Expected Output: {"service":"SiagaKita REST API","status":"ok"}
```

### Inspecting Backend Logs

```bash
ssh root@139.59.99.230
docker logs siagakita_backend -f --tail=100
```

### Firewall Port Configuration

```bash
ssh root@139.59.99.230
ufw allow 22/tcp    # SSH
ufw allow 8080/tcp  # REST API
ufw allow 8081/tcp  # WebSocket
ufw enable
```

---

## 7. Client Application Configuration

Both Flutter clients consume API endpoints dynamically via environment variables without hardcoded IP addresses.

```bash
# Run Mobile App (Citizen & Volunteer)
cd mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env

# Run Desktop Console (Admin & Agency)
cd windows_console_flutter && flutter run -d linux --dart-define-from-file=../infrastructure/.env

# Build Android Release APK
cd mobile-flutter && flutter build apk --dart-define-from-file=../infrastructure/.env
```

---

## 8. Database Migration Procedures

Raw SQL migrations are placed in `backend-go/migrations/NNN_description.sql`.

```bash
# Execute incremental migration on production database
scp backend-go/migrations/013_add_dispatch_table.sql root@139.59.99.230:/opt/siagakita/
ssh root@139.59.99.230
docker exec -i siagakita_postgres psql -U siagakita_admin -d siagakita < /opt/siagakita/013_add_dispatch_table.sql
```
