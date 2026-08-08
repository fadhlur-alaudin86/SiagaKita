# 📚 SiagaKita — Documentation Overview

> This directory contains all technical documentation for the SiagaKita project.
> **Keep these documents updated whenever significant architecture, schema, or workflow changes occur.**

---

## Documentation Index

| File | Description | Last Updated |
|------|-------------|--------------|
| [PROGRESS_REPORT.md](./PROGRESS_REPORT.md) | Development progress log, sprint changelogs, component status, completed/pending tasks | 8 August 2026 |
| [BACKEND_ARCHITECTURE.md](./BACKEND_ARCHITECTURE.md) | Go directory layout, DDD patterns, auth flows, RBAC, WebSocket hubs, OTP integration, env vars | 1 May 2026 |
| [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) | Full PostgreSQL schema v12, tables, triggers, ERD, and design decisions | 15 May 2026 |
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | Production VPS setup, GitHub Secrets, CI/CD automation, rollbacks, firewall config | 8 August 2026 |
| [FRONTEND_STRUCTURE.txt](./FRONTEND_STRUCTURE.txt) | Flutter Mobile architecture, screen-to-endpoint mappings | 13 May 2026 |
| [DESKTOP_PLANNING_ADMIN_INSTANSI.txt](./DESKTOP_PLANNING_ADMIN_INSTANSI.txt) | Flutter Desktop Console architecture, page specifications for central agencies | 1 May 2026 |
| [skills/README.md](./skills/README.md) | Developer guide for AI agent skills (`devops-workflow`, `gh-project-manager`, `feature-dev-workflow`) | 8 August 2026 |

---

## Development & Deployment Workflows

### Branching Strategy

```
main                          ← Stable release (deploys via tag v*.*.*)
 └── dev                      ← Active integration branch (target for feature PRs)
      ├── feature/F-XXX-name  ← New feature development
      └── fix/F-XXX-name      ← Bug fixes
```

- **No Direct Pushes**: All code changes must enter `dev` or `main` via Pull Requests.
- **Conventional Commits**: Commit messages must follow `type(scope): description` (e.g., `feat(incident): add volunteer dispatch`).

### CI/CD Pipelines

| Pipeline | Trigger | Action |
|----------|---------|--------|
| `ci-dev.yml` | Push/PR to `dev` | Runs conditional Go & Flutter linting/testing based on modified paths |
| `ci-main.yml` | PR to `main` | Runs full Go & Flutter CI suite + Docker build validation |
| `release-deploy.yml` | Push tag `v*.*.*` | Builds Docker image, pushes to Docker Hub, deploys to VPS with automated rollback on health check failure, and creates GitHub Release |
| `auto-tag.yml` | Push to `main` with modified `VERSION` | Automatically creates git release tag matching `VERSION` file |

### Triggering a Production Deployment

1. Update the root `VERSION` file (e.g., `1.0.25`).
2. Submit a PR from `dev` to `main` including the `VERSION` file update.
3. Upon merging to `main`, `auto-tag.yml` creates tag `v1.0.25`.
4. `release-deploy.yml` builds the Docker image, deploys to VPS, verifies health, and publishes a GitHub Release.

---

## Quick Reference Commands

### Local Backend Execution

```bash
# Start infrastructure containers
cd infrastructure && docker compose up -d postgres redis

# Run backend locally
cd backend-go && go run cmd/api/main.go
```

### Running Mobile & Desktop Clients

```bash
# Mobile Client (Citizen & Volunteer)
cd mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env

# Desktop Console (Agency & Admin)
cd windows_console_flutter && flutter run -d linux --dart-define-from-file=../infrastructure/.env
```

---

## Documentation Guidelines

1. **Update `PROGRESS_REPORT.md`** after every sprint or patch release.
2. **API Endpoint Changes**: Update `PROGRESS_REPORT.md` and `FRONTEND_STRUCTURE.txt`.
3. **Database Schema Changes**: Update `DATABASE_SCHEMA.md` and create incremental migration SQL files in `backend-go/migrations/NNN_description.sql`.
4. **Backend Architecture Updates**: Update `BACKEND_ARCHITECTURE.md`.
5. **AI Agent Workflows**: Use agent skills located in `.agent/skills/` and refer to human documentation in `docs/skills/`.
