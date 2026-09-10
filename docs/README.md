# SiagaKita Documentation Overview

This directory contains the central technical documentation for the SiagaKita platform.

---

## Documentation Index

| Document | Description | Target Audience |
|---|---|---|
| [BACKEND_ARCHITECTURE.md](./BACKEND_ARCHITECTURE.md) | Go Fiber architecture, DDD structure, Redis JTI SessionGuard, WebSocket Hub, and security guards | Backend Engineers |
| [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) | PostgreSQL schema specification, table models, triggers, and automated migration CLI (`cmd/migrate`) | DBAs, Backend Developers |
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | Production VPS provisioning, Nginx reverse proxy, Cloudflare SSL, and automated CI/CD deployment | DevOps, Infrastructure Engineers |
| [design/README.md](./design/README.md) | Living Mermaid diagram catalog (Database ERD, Use Case diagrams, Activity & State sequences) | Full-Stack Engineers, Architects |
| [api/openapi.yaml](./api/openapi.yaml) | Modular OpenAPI 3.0 API specifications (Interactive Swagger UI served at `/docs/*`) | Frontend & Backend Developers |
| [skills/README.md](./skills/README.md) | Human developer onboarding guide for AI Agent skills (`.agent/skills/`) | Developers, AI Pair Programmers |
| [backlog/features/](./backlog/features/) | Historical feature logs detailing discovery notes, decisions, and testing outcomes per feature | Team Leads, Contributors |

---

## Architecture & Visual Design

The platform maintains living Mermaid.js diagrams directly within repository markdown files:

- **Interactive ERD**: [`docs/design/database-erd.md`](./design/database-erd.md) (15 tables, ENUM types, and relational foreign keys).
- **Use Case Models**: [`docs/design/use-case-diagrams.md`](./design/use-case-diagrams.md) (Role access boundaries for 6 actor types).
- **Activity & Sequence Flows**: [`docs/design/activity-diagrams.md`](./design/activity-diagrams.md) (Emergency SOS Jalur A, Community Reports Jalur B, and KYC verification state machines).

---

## Development & Deployment Workflows

### Branch Strategy

```
main                          ← Protected stable release (deploys via release tag v*.*.*)
 └── dev                      ← Active integration branch (target for all feature PRs)
      ├── feature/F-XXX-name  ← New feature development branch
      └── fix/F-XXX-name      ← Bug fix branch
```

- **No Direct Pushes**: All changes must merge into `dev` or `main` through reviewed Pull Requests.
- **Conventional Commits**: Commits strictly follow `<type>(<scope>): <short description>` (e.g. `feat(incident): add volunteer dispatch endpoint`).

### CI/CD Automation

| Pipeline | Trigger | Responsibilities |
|---|---|---|
| `ci-dev.yml` | Push/PR to `dev` | Conditional Go and Flutter linting, unit tests, `govulncheck`, and localization orphan detection |
| `ci-main.yml` | PR to `main` | Full validation suite across all components and Docker container build verification |
| `release-deploy.yml` | Push tag `v*.*.*` | Builds Docker image, pushes to Docker Hub, deploys to VPS via SSH with health rollback, and publishes GitHub Release |
| `auto-tag.yml` | Push to `main` with modified `VERSION` | Automatically generates and pushes git release tag matching `VERSION` |

---

## Quick Reference Commands

### Running Backend & Database Locally

```bash
# Start PostgreSQL and Redis infrastructure containers:
cd infrastructure && docker compose up -d postgres redis

# Run database migrations to latest revision:
cd ../backend-go && go run cmd/migrate/main.go up

# Start the Go Fiber API server:
go run cmd/api/main.go
```

Interactive Swagger UI documentation is available at `http://localhost:8080/docs/*`.

### Running Client Applications

```bash
# Mobile Client (Flutter Citizen & Volunteer App):
cd mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env

# Desktop Console (Flutter Agency & Admin App):
cd windows_console_flutter && flutter run -d linux --dart-define-from-file=../infrastructure/.env
```

### Running Automated Quality Gates

```bash
# Check client localization dictionary hygiene (zero orphaned translation keys):
python3 scripts/check_localization_orphans.py --all

# Run backend static analysis and security linters:
cd backend-go && golangci-lint run ./...

# Run Go vulnerability audit:
cd backend-go && go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

---

## Documentation Governance Rules

1. **Database Changes**: Any modification to database tables or columns in `backend-go/migrations/` MUST update both [`DATABASE_SCHEMA.md`](./DATABASE_SCHEMA.md) and [`design/database-erd.md`](./design/database-erd.md).
2. **API Endpoint Changes**: Extend domain OpenAPI files in [`api/paths/<domain>.yaml`](./api/paths/) and verify against Swagger UI at `/docs/*`.
3. **Workflow & State Lifecycle Changes**: If an incident status transition or actor permission matrix changes, update [`design/activity-diagrams.md`](./design/activity-diagrams.md) or [`design/use-case-diagrams.md`](./design/use-case-diagrams.md).
4. **Feature Execution**: Record progress, discovery notes, and testing outcomes in [`backlog/features/F-XXX-name.md`](./backlog/features/) throughout feature development.
