# Stacks & Project Configuration

## Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile Citizen/Volunteer | Flutter (Dart) — `mobile-flutter/` |
| Desktop Console Admin/Agency | Flutter Desktop — `windows_console_flutter/` |
| Mobile Responder | Flutter (planned) — `mobile-flutter-responder/` |
| Backend | Go 1.26 + Fiber v2 + Sonic + Zerolog |
| Database | PostgreSQL 15 |
| Cache & Ephemeral | Redis |
| OTP Email | SMTP (Gmail) |
| OTP WhatsApp | Fonnte API |
| Containerization | Docker Compose |

## Project Configuration

```
Repo Owner     : SuperBypassUdinnn
Repo Name      : SuperBypassUdinnn/SIAGAKITA
Default Branch : main
Dev Branch     : dev
```

## Branch Strategy

```
Branch         : Purpose
main           : Stable release (deploys via tag v*.*.*)
dev            : Active integration (all feature branches merge here)
feature/F-XXX  : New feature development (branched from dev)
fix/F-XXX      : Bug fixes (branched from dev)
```

Naming Conventions:
- Feature   : `feature/F-XXX-name` (e.g., `feature/F-014-dispatch-volunteer`)
- Bugfix    : `fix/F-XXX-name` (e.g., `fix/F-015-sos-strike-mapping`)
- Sub-branch: `feature/F-XXX-name/sub-backend`, `feature/F-XXX-name/sub-mobile`

### Mandatory Merge Methods
- `feature/*` / `fix/*` → `dev`: **Squash Merge** (1 PR = 1 atomic Conventional Commit on `dev`).
- `dev` → `main`: **Rebase Merge** (fast-forward linear release history for release bots).

## GitHub Labels

```
Priority     : priority: P0, priority: P1, priority: P2
Status       : status: in-progress, status: in-review, status: ready
Component    : component: backend, component: mobile, component: desktop, component: infra
Type         : type: feature, type: fix, type: chore, type: docs
```

## Milestone Naming

```
Format: Sprint X (v1.X.X) — DD Month YYYY
Example: Sprint 25 (v1.0.25) — 15 August 2026
```

## CI/CD Workflows

```
Workflow               : Trigger Condition
ci-dev.yml             : Push/PR to `dev` (conditional by changed paths)
ci-main.yml            : PR to `main` (full CI + Docker build validation)
release-deploy.yml     : Push tag v*.*.* (Docker push + VPS deploy + rollback + GitHub Release)
auto-tag.yml           : Push to `main` with changes to `VERSION` file (auto-creates git tag)
```

## Directory Layout

```
siagakita/
├── .agent/skills/       ← Agent skill instructions
├── .github/workflows/   ← CI/CD pipelines
├── backend-go/          ← Go Fiber backend
├── infrastructure/      ← Docker Compose (prod & dev)
├── mobile-flutter/      ← Flutter mobile app (citizen/volunteer)
├── windows_console_flutter/ ← Flutter desktop app (admin/agency)
├── docs/                ← Project documentation
│   ├── api/             ← Modular OpenAPI 3.0 specs (Swagger UI)
│   ├── design/          ← Visual architecture, Mermaid ERD & state diagrams
│   ├── skills/          ← Skill guides for human developers
│   └── backlog/         ← Feature logs (F-XXX-name.md)
└── VERSION              ← Active version file (read by auto-tag.yml)
```
