---
name: devops-workflow
description: Manage CI/CD pipelines, branching strategy, VPS deployments, rollbacks, and GitHub workflow files for SiagaKita. Use this skill when asked to adjust pipelines, versioning, or deployment infrastructure.
---

## Trigger Keywords

`deploy`, `CI/CD`, `workflow`, `pipeline`, `rollback`, `VPS`, `branch protection`, `GitHub Actions`, `Dockerfile`, `docker compose`, `branching`, `tag`, `release`, `ci failure`

## Stack Reference

Read [stacks.md](../stacks.md) for project configurations, branch strategies, and directory structures.

## Core Responsibilities

| Area | Responsibility |
|------|----------------|
| CI/CD | Maintain `.github/workflows/*.yml` |
| Branching | Enforce branch naming & protection rules |
| Versioning | Update `VERSION` file and manage `v*.*.*` tags |
| Deployment | Monitor & trigger VPS deployments via SSH |
| Rollback | Execute automated rollbacks if health checks fail |
| Documentation | Update `docs/skills/devops-workflow-docs.md` when workflows change |

## Branching Rules

### Naming Conventions

```
main                          # Stable release — only accepts merges from dev
dev                           # Active integration — all feature branches target dev
feature/F-XXX-name            # New feature — created from dev
fix/F-XXX-name                # Bugfix — created from dev
feature/F-XXX-name/sub-*      # Sub-branch per component or team member
```

### Merge Flow

```
feature/F-XXX/sub-backend ─┬─► feature/F-XXX-name ─► (PR + CI pass) ─► dev
feature/F-XXX/sub-mobile  ─┘                                ↓
                                                     (PR to main: manual by user)
                                                              ↓
                                                            main ← tag v*.*.* ← deploy
```

### Branch Protection & Merge Rules

**Branch `dev`:**
- Require status checks (`ci-dev`) to pass before merging
- **Squash Merge MANDATORY** for all PRs from `feature/*` and `fix/*` branches to `dev`. All micro/WIP commits are squashed into 1 atomic Conventional Commit (e.g., `feat(incident): add dispatch endpoint`).

**Branch `main`:**
- Require PR (no direct pushes — only merges from `dev`)
- Require `ci-main` status checks to pass
- **Rebase Merge MANDATORY** for PRs from `dev` to `main` (fast-forward linear history, preserves atomic commits from `dev` for automated release notes).

## CI/CD Workflow Reference

| Workflow | Trigger | Action |
|----------|---------|--------|
| `ci-dev.yml` | Push/PR to `dev` | Conditional linting & build checks (based on modified paths) |
| `ci-main.yml` | PR to `main` | Full CI across all components + Docker build validation |
| `release-deploy.yml` | Push tag `v*.*.*` | Docker build+push + VPS deploy + health check rollback + GitHub Release |
| `auto-tag.yml` | Push to `main` with changes to `VERSION` | Auto-creates a git tag matching `VERSION` file |
| `labeler.yml` | PR open/synchronize | Automatically labels PRs based on modified paths |
| `issue-status-labeler.yml` | PR open/review/merge | Automates issue status transitions (`status: in-review`, `status: ready`, closes on merge) |
| `auto-merge-dev.yml` | PR open/review to `dev` | Enables automatic squash-merge to `dev` upon 1 approval & passing CI checks |

## Versioning Flow

```
1. Developer updates the VERSION file (e.g., 1.0.25).
2. Create PR from `dev` to `main` including the updated VERSION file.
3. Once merged to `main`, `auto-tag.yml` creates tag `v1.0.25`.
4. Tag `v1.0.25` triggers `release-deploy.yml`.
5. `release-deploy.yml` builds Docker image (tagged v1.0.25 & latest), pushes to Docker Hub, deploys to VPS, verifies health, and creates GitHub Release.
```

**Version Increment Rules:**
- `PATCH` (z): bugfix, hotfix → 1.0.24 → 1.0.25
- `MINOR` (y): new feature → 1.0.24 → 1.1.0
- `MAJOR` (x): breaking change → 1.0.24 → 2.0.0

## Conventional Commits (MANDATORY)

All team members MUST follow Conventional Commits to ensure automated release notes generation works seamlessly.

### Format

```
<type>(<scope>): <short description in imperative mood>

[optional body]

[optional footer]
```

### Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(incident): add volunteer dispatch endpoint` |
| `fix` | Bug fix | `fix(auth): resolve JWT expiry issue on refresh` |
| `chore` | Maintenance, dependencies, config | `chore: bump go.mod dependencies` |
| `docs` | Documentation changes | `docs(api): update OpenAPI contract for /sos endpoint` |
| `refactor` | Code refactoring (no functional change) | `refactor(hub): simplify WebSocket registry logic` |
| `test` | Add or update tests | `test(incident): add table-driven tests for SOS handler` |
| `ci` | CI/CD workflow updates | `ci: add Flutter analyze step to ci-dev.yml` |
| `style` | Formatting, whitespace, no logic change | `style(mobile): apply dart format` |

### Scopes

`auth`, `incident`, `user`, `admin`, `telemetry`, `otp`, `ws`, `mobile`, `desktop`, `infra`, `ci`, `docs`

## Database Migrations & Rollback Operations

### Automated In-App Migrations (Startup)
- The backend Go binary embeds all migrations (`backend-go/migrations/*.sql`) and executes pending UP migrations automatically upon booting.
- Multi-container startup races are prevented via PostgreSQL advisory locking in `golang-migrate`.

### Rollback Strategy & Production Safety
- **No Automatic Schema Rollback on VPS Failure**: The `release-deploy.yml` pipeline automatically rolls back the Docker container image if health checks fail, but intentionally DOES NOT execute `down.sql`. Automatic down-migrations on a live database risk catastrophic, irreversible customer data loss.
- **Manual Emergency Rollback**: If a database rollback is required, run `siagakita-migrate` through SSH on the VPS:
  ```bash
  # Check active schema version
  docker compose -f docker-compose.prod.yml exec backend ./siagakita-migrate version

  # Roll back 1 migration step
  docker compose -f docker-compose.prod.yml exec backend ./siagakita-migrate down 1

  # Force specific version if marked dirty
  docker compose -f docker-compose.prod.yml exec backend ./siagakita-migrate force <version>
  ```

## Agent Rules

1. **Read stacks.md first** — before altering any workflow or project configuration.
2. **Confirm before modifying workflows** — always confirm with the user before editing production `.yml` files.
3. **Use path filters** — `ci-dev.yml` should only execute checks relevant to changed paths.
4. **Never merge dev to main directly** — merging `dev` into `main` must always be executed manually by the user (release gate).
5. **Update VERSION** — remind developers to update `VERSION` when creating a release PR to `main`.
6. **Enforce Conventional Commits** — if commit messages break standard format, point it out and request correction.
7. **Automated Rollback awareness** — deployment workflows include automated health check rollbacks. If a deployment fails, inspect container logs and report findings.
8. **Database Rollback Caution** — Never automate destructive database schema rollbacks in unattended CI/CD pipelines. Always verify backward-compatibility (Expand & Contract) and instruct developers to use `siagakita-migrate` for manual schema rollbacks.

