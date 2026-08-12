# DevOps Workflow — SiagaKita Developer Guide

This guide details the CI/CD pipelines, branching strategy, versioning, and automated deployment workflow for SiagaKita.

---

## Branch Strategy

```
main ────────────────────────────────────────────► stable release
  │
  └── dev ──────────────────────────────────────► active integration
        │
        ├── feature/F-014-dispatch-volunteer ───► new feature
        │     ├── .../sub-backend
        │     └── .../sub-mobile
        │
        └── fix/F-015-sos-strike-mapping ───────► bug fix
```

### Rules

- **Direct pushes to `main` or `dev` are strictly forbidden** — all changes must enter via Pull Requests.
- Feature branches are created from `dev`.
- Sub-branches (if needed) are created from parent feature branches.
- Merge progression: `sub-branch → feature branch → dev → main` (manual release gate).

---

## CI/CD Pipelines

| Workflow | File Path | Trigger Condition | Execution Details |
|----------|-----------|-------------------|-------------------|
| CI Dev | `.github/workflows/ci-dev.yml` | Push/PR to `dev` | Conditional linting & build checks (runs only modified Go/Flutter paths) |
| CI Main | `.github/workflows/ci-main.yml` | PR to `main` | Full CI suite across all components + Docker build validation |
| Release Deploy | `.github/workflows/release-deploy.yml` | Push tag `v*.*.*` | Docker push + VPS deployment + automated health check rollback + GitHub Release |
| Auto Tag | `.github/workflows/auto-tag.yml` | Push to `main` with modified `VERSION` file | Automatically creates git tag `v1.X.X` matching `VERSION` |
| PR Labeler | `.github/workflows/labeler.yml` | PR open/synchronize | Automatically labels PRs based on modified file paths |
| Issue Status Auto-Labeler | `.github/workflows/issue-status-labeler.yml` | PR open/review/merge | Automates issue status transitions (`status: in-review`, `status: ready`, closes on merge) |
| Auto Merge Dev | `.github/workflows/auto-merge-dev.yml` | PR open/review targeting `dev` | Enables automatic squash-merge to `dev` upon 1 approval & passing CI checks |

---

## Versioning & Manual Release Triggering

The `VERSION` file at the repository root holds the active release version (e.g., `1.0.25`).

### Release Procedure:
1. Update the `VERSION` file (e.g., `1.0.25`).
2. Create a PR from `dev` to `main` including the updated `VERSION` file.
3. Upon PR approval and merge to `main`, `auto-tag.yml` automatically creates git tag `v1.0.25`.
4. The tag creation triggers `release-deploy.yml` which builds the Docker image, deploys to VPS, verifies health, and creates a GitHub Release.

---

## VPS Automated Rollback Mechanism

If a deployment fails health checks (5 retries with 5s intervals), `release-deploy.yml` automatically:
1. Stops the broken backend container.
2. Pulls the previous stable Docker image.
3. Restarts the container using the previous image.
4. Reports deployment failure in GitHub Actions logs.
