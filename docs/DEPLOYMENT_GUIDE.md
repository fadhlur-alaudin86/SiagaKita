# 🚀 SiagaKita — Production Deployment Guide

> **Production Server IP:** `<YOUR_VPS_IP>` (Ubuntu 22.04 / 24.04 LTS VPS)  
> **Production Domain:** `api.siagakita.com` (or `<YOUR_DOMAIN>`)  
> **Last Updated:** September 2026

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Initial VPS Infrastructure Setup](#2-initial-vps-infrastructure-setup)
3. [Cloudflare DNS, Domain & SSL Configuration](#3-cloudflare-dns-domain--ssl-configuration)
4. [Required GitHub Secrets](#4-required-github-secrets)
5. [Automated CI/CD Workflow](#5-automated-cicd-workflow)
6. [Emergency Manual Deployment](#6-emergency-manual-deployment)
7. [Monitoring & Health Verification](#7-monitoring--health-verification)
8. [Client Application Multi-Environment Setup](#8-client-application-multi-environment-setup)
9. [Database Migration Procedures](#9-database-migration-procedures)

---

## 1. Prerequisites

Before starting the deployment, ensure you have:

- A Linux VPS instance running Ubuntu 22.04 or 24.04 LTS with public IPv4 `<YOUR_VPS_IP>`.
- SSH Key access configured for the administrative user (`root@<YOUR_VPS_IP>` or a `sudo`-privileged user).
- A Docker Hub account with repository push permissions for `siagakita-api`.
- A registered domain name managed via Cloudflare DNS (e.g., `siagakita.com`).
- GitHub Repository administrative privileges to configure **Settings → Secrets and variables → Actions**.

---

## 2. Initial VPS Infrastructure Setup (One-time)

### 2a. Install Docker Engine & Tools on the VPS

Connect to your remote VPS via SSH:

```bash
ssh root@<YOUR_VPS_IP>
```

Update system packages and install Docker Engine with the Docker Compose plugin:

```bash
# Update repository package indices
apt update && apt upgrade -y

# Install prerequisite packages
apt install -y curl ufw git ca-certificates gnupg lsb-release

# Install Docker using the official automated script
curl -fsSL https://get.docker.com | sh

# Enable and start Docker service
systemctl enable --now docker

# Confirm installation versions
docker --version
docker compose version
```

### 2b. Create Project Directories on the VPS

Create the operational directories under `/opt/siagakita`:

```bash
mkdir -p /opt/siagakita/uploads \
         /opt/siagakita/logs \
         /opt/siagakita/nginx \
         /opt/siagakita/ssl

# Set appropriate directory access permissions
chmod 755 /opt/siagakita/uploads /opt/siagakita/logs
```

### 2c. Transfer Configuration Files from Local Machine

From your local machine repository root, copy the production Docker Compose definition, Nginx configuration, SSL certificates, and environment template to the VPS:

```bash
# Copy Docker Compose production definition
scp infrastructure/docker-compose.prod.yml root@<YOUR_VPS_IP>:/opt/siagakita/

# Copy Nginx reverse proxy configuration
scp -r infrastructure/nginx/* root@<YOUR_VPS_IP>:/opt/siagakita/nginx/

# Copy SSL certificates directory (Cloudflare Origin CA or self-signed placeholder)
scp -r infrastructure/ssl/* root@<YOUR_VPS_IP>:/opt/siagakita/ssl/

# Copy production environment file template
scp infrastructure/.env.example root@<YOUR_VPS_IP>:/opt/siagakita/.env
```

### 2d. Configure Production Environment Variables

SSH into your server and edit `/opt/siagakita/.env` with your production secrets:

```bash
ssh root@<YOUR_VPS_IP>
nano /opt/siagakita/.env
```

Ensure the following production variables are configured:

```env
# Database Credentials
DB_USER=siagakita_admin
DB_PASSWORD=<strong_unique_password>
DB_NAME=siagakita
DB_HOST=postgres
DB_PORT=5432

# Redis Cache Credentials
REDIS_PASSWORD=<strong_unique_password>
REDIS_HOST=redis
REDIS_PORT=6379

# Server Network & Host
API_HOST=api.siagakita.com
HTTP_PORT=8080
WS_PORT=8081

# JWT Secret Keys
JWT_SECRET=<random_secret_min_32_chars>
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=168h

# WhatsApp Notification Provider (Fonnte)
FONNTE_TOKEN=<fonnte_api_token>

# SMTP Email Notification Provider
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=<email@gmail.com>
SMTP_PASSWORD=<gmail_app_password>
SMTP_FROM=<email@gmail.com>

# Superadmin Initial Credentials
SUPERADMIN_EMAIL=<superadmin_email>
SUPERADMIN_PASS=<strong_unique_password>

# Docker Registry
DOCKERHUB_USERNAME=<dockerhub_username>

# File Upload Storage & Routing
UPLOAD_DIR=/app/uploads
UPLOAD_BASE_URL=https://api.siagakita.com/uploads

# Application Runtime
GO_ENV=production
LOG_PATH=logs/app.log
```

Protect the `.env` file with restrictive permissions:

```bash
chmod 600 /opt/siagakita/.env
```

### 2e. Configure Firewall (`ufw`)

Only allow ports 22 (SSH), 80 (HTTP redirect), and 443 (HTTPS/WSS via Nginx). The backend container ports (8080 and 8081) are strictly isolated within Docker's internal bridge network (`siagakita_network`) and must **never** be exposed directly to the public internet:

```bash
ssh root@<YOUR_VPS_IP>

# Set default firewall policies
ufw default deny incoming
ufw default allow outgoing

# Allow necessary public inbound services
ufw allow 22/tcp    # SSH Management
ufw allow 80/tcp    # HTTP (SSL challenges & auto 301 redirect to HTTPS)
ufw allow 443/tcp   # HTTPS & WSS (Nginx Reverse Proxy)

# Ensure direct backend access is blocked if previously opened
ufw delete allow 8080/tcp 2>/dev/null || true
ufw delete allow 8081/tcp 2>/dev/null || true

# Enable and verify firewall
ufw --force enable
ufw status verbose
```

---

## 3. Cloudflare DNS, Domain & SSL Configuration

To shield the physical VPS IP, mitigate DDoS attacks, and enforce end-to-end TLS encryption, all public traffic routes through Cloudflare.

### 3a. DNS Record Setup

1. In the **Cloudflare Dashboard**, select your zone (e.g., `siagakita.com`).
2. Navigate to **DNS → Records** and add an `A` record:
   - **Type:** `A`
   - **Name:** `api` (resolves to `api.siagakita.com`)
   - **IPv4 Address:** `<YOUR_VPS_IP>`
   - **Proxy Status:** **Proxied (Orange Cloud enabled)**
   - **TTL:** Auto

### 3b. SSL/TLS Encryption Mode

1. In the Cloudflare Dashboard, go to **SSL/TLS → Overview**.
2. Select **Full (strict)** encryption mode. This ensures all traffic between Cloudflare and your Nginx reverse proxy is encrypted with a valid certificate.

### 3c. Cloudflare Origin CA Certificate

1. In Cloudflare, navigate to **SSL/TLS → Origin Server**.
2. Click **Create Certificate**:
   - Private key type: **RSA (2048)**.
   - Hostnames: `api.siagakita.com`, `*.siagakita.com`.
   - Certificate validity: 15 years (recommended).
3. Copy the generated **Origin Certificate** and save it to `/opt/siagakita/ssl/cert.pem` on the VPS.
4. Copy the generated **Private Key** and save it to `/opt/siagakita/ssl/key.pem` on the VPS.
5. Set strict file permissions on the server:

```bash
ssh root@<YOUR_VPS_IP>
chmod 644 /opt/siagakita/ssl/cert.pem
chmod 600 /opt/siagakita/ssl/key.pem
```

> [!TIP]
> **For Local / Staging Testing:** If you are testing before DNS cutover, generate a self-signed placeholder certificate by running:
> ```bash
> ./infrastructure/ssl/generate_self_signed.sh
> ```

---

## 4. Required GitHub Secrets

Navigate to: **GitHub → Repository → Settings → Secrets and variables → Actions**

Add the following repository secrets required by the CI/CD deployment pipeline:

| Secret Name | Example Value | Description |
|---|---|---|
| `DOCKERHUB_USERNAME` | `siagakita` | Docker Hub username for image publishing |
| `DOCKERHUB_TOKEN` | `dckr_pat_xxxx` | Docker Hub access token with write permissions |
| `VPS_HOST` | `<YOUR_VPS_IP>` | Remote VPS IPv4 address |
| `VPS_USERNAME` | `root` | SSH user on the production VPS |
| `VPS_SSH_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | Private SSH key matching the server's `authorized_keys` |

---

## 5. Automated CI/CD Workflow

The automated deployment pipeline enforces strict quality gates across branches:

```
[ Developer Feature Branch ]
         │
         ▼ PR to dev
  .github/workflows/ci-dev.yml (Path-filtered Go unit tests & Flutter analyze)
         │
         ▼ Merge to dev → PR to main
  .github/workflows/ci-main.yml (Full CI test suite + Docker build validation)
         │
         ▼ Merge PR to main (includes VERSION file update)
  .github/workflows/auto-tag.yml (Extracts version & creates git tag v1.X.X)
         │
         ▼ Pushes git tag v1.X.X
  .github/workflows/release-deploy.yml
         ├── Job 1: Build Docker image (tags: v1.X.X & latest) → push to Docker Hub
         ├── Job 2: Deploy to VPS via SSH & perform automated health checks
         │           └── (On failure: automatic rollback to previous container image)
         └── Job 3: Publish GitHub Release with Conventional Commits changelog
```

### Versioning & Automated Tagging

1. When a release is ready, update the root `VERSION` file (e.g., `1.0.26`).
2. Submit a PR from `dev` to `main`.
3. Merging into `main` automatically triggers `auto-tag.yml` which reads `VERSION` and creates git tag `v1.0.26`.
4. `release-deploy.yml` builds the image, deploys to the VPS, verifies container health, and publishes the GitHub Release.

### Automated Rollback Strategy

During deployment, `release-deploy.yml` verifies container health using Docker inspection (up to 5 attempts with 5-second intervals):
- If `docker inspect` confirms the backend status is `healthy`, deployment completes successfully.
- If health verification fails, the pipeline automatically aborts, pulls the previous Docker image, restores the previous container, and logs the failure incident.

---

## 6. Emergency Manual Deployment

If GitHub Actions is unreachable or manual intervention is needed, execute the deployment directly on the server:

```bash
# SSH into production server
ssh root@<YOUR_VPS_IP>
cd /opt/siagakita

# Pull the latest backend container image
docker compose -f docker-compose.prod.yml pull backend

# Restart services without dropping dependencies
docker compose -f docker-compose.prod.yml up -d --no-deps backend nginx

# Verify running container statuses
docker ps

# Test health check via local Nginx reverse proxy
curl -s http://localhost/health
```

---

## 7. Monitoring & Health Verification

### Health Check Endpoints

```bash
# 1. External Domain Check (HTTPS via Cloudflare & Nginx Reverse Proxy)
curl -s https://api.siagakita.com/health
# Expected Output: {"service":"SiagaKita REST API","status":"ok"}

# 2. Localhost check on VPS (via Nginx port 80)
curl -s http://localhost/health

# 3. Direct container health check (internal inspection)
docker exec siagakita_backend wget -qO- http://127.0.0.1:8080/health
```

### Inspecting Service Logs

```bash
ssh root@<YOUR_VPS_IP>

# Inspect Nginx Reverse Proxy access & error logs
docker logs siagakita_nginx -f --tail=100

# Inspect Backend Go API logs
docker logs siagakita_backend -f --tail=100

# Inspect PostgreSQL database logs
docker logs siagakita_postgres -f --tail=50

# Inspect Redis cache logs
docker logs siagakita_redis -f --tail=50
```

---

## 8. Client Application Multi-Environment Setup

Both Flutter client applications consume API and WebSocket endpoints dynamically using the `--dart-define-from-file` build flag. No IP addresses or domain URLs are hardcoded in the application source code.

### Local Development Environment (`.env.dev`)

```bash
# Mobile Flutter App (Citizen & Volunteer)
cd mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env.dev

# Desktop Console App (Admin & Agency Personnel)
cd windows_console_flutter && flutter run -d linux --dart-define-from-file=../infrastructure/.env.dev
```

### Production Environment (`.env.prod`)

```bash
# Run Mobile App in Production mode
cd mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env.prod

# Build Android Release APK for Production
cd mobile-flutter && flutter build apk --release --dart-define-from-file=../infrastructure/.env.prod

# Run Desktop Console in Production mode
cd windows_console_flutter && flutter run -d linux --dart-define-from-file=../infrastructure/.env.prod

# Build Desktop Release for Production
cd windows_console_flutter && flutter build linux --release --dart-define-from-file=../infrastructure/.env.prod
```

---

## 9. Database Migration Procedures

Incremental SQL migration files are located in `backend-go/migrations/NNN_description.sql`.

To apply an incremental migration to the production database:

```bash
# Copy migration file to VPS
scp backend-go/migrations/013_add_dispatch_table.sql root@<YOUR_VPS_IP>:/opt/siagakita/

# SSH into VPS and execute SQL inside the PostgreSQL container
ssh root@<YOUR_VPS_IP>
docker exec -i siagakita_postgres psql -U siagakita_admin -d siagakita < /opt/siagakita/013_add_dispatch_table.sql

# Remove migration file from host after execution
rm /opt/siagakita/013_add_dispatch_table.sql
```
