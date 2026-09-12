# Feature Dev Workflow — SiagaKita Developer Guide

This guide describes the contract-first feature development pipeline for SiagaKita (Go Fiber + Flutter).

---

## Pipeline Overview

```
Backlog Overview → Discovery → Issue → Branch → Contract → Backend → Flutter → Test → PR → dev
```

| Step | Action |
|------|--------|
| -3 | Backlog Overview — Audit documentation parity (`python3 scripts/sync_backlog_status.py --check`), fetch remote issues via `gh`, pick target feature |
| -2 | Discovery — Codebase exploration & 5 clarifying questions |
| -1 | Resolve Backlog — Create/match GitHub issue, write feature log |
| 0 | Branch — Create `feature/F-XXX-name` from `dev` |
| 1 | Read Mapping — Inspect domain handlers, DB schema, API contracts, Flutter screens |
| 2 | API Contract — Write `docs/api/paths/<domain>.yaml` |
| 3 | DB Migration — Write paired SQL migration files (`.up.sql` & `.down.sql`), update schema docs & Mermaid ERD |
| 4 | Backend Implementation — Implement Go handlers/services/repositories |
| 5 | Flutter Implementation — Implement Flutter screens/widgets/services |
| 6 | Tests — Go table-driven unit tests + Flutter widget tests |
| 7 | Review Gate & Retrospective — Run pre-flight quality gatekeeper (`python3 scripts/verify_pipeline.py` 7/7 gates), verify audit dimensions (Security, DB, Silent-Failure, Dead-Code), run Step 7.5 Workflow Retrospective, open PR to `dev` (`issue-status-labeler.yml` updates issue to `status: in-review`) |
| 8 | Close Log & Evolution — Update feature log, sync documentation parity (`python3 scripts/sync_backlog_status.py --fix`), reconcile issues and parent tracker (`python3 scripts/reconcile_issue_status.py`), log applied workflow evolutions (upon approval + CI pass, `auto-merge-dev.yml` merges PR & `reconcile_issue_status.py` in CI closes child issues and transitions parent trackers to `status: ready`) |

---

## Feature Log & Architectural Plans

Every feature maintains a dedicated log file at `docs/backlog/features/F-XXX-name.md` serving as the **single source of truth** for that feature's lifecycle across agent restarts and team handoffs.

If the feature belongs to an overarching epic or architectural roadmap in `.planning/`, the feature log explicitly references its parent plan (e.g. `Parent Plan: .planning/04-desktop-dispatch-mvp.md`), ensuring bidirectional traceability between strategic architecture and tactical execution.

---

## Evolutionary Workflows & Self-Improving Skills

To prevent workflow rot and preserve hard-earned engineering lessons across sessions, AI workers actively run a **Workflow Retrospective** at Step 7.5 before opening a Pull Request:

1. **Minor Evolutions (Autonomous Execution)**:
   - Minor enhancements—such as technical quirks, new CLI flags, testing gotchas, and database indexing tricks—are added directly to `.agent/skills/` and committed into the active feature branch as a separate commit (`docs(workflow): ...` or `chore(skills): ...`).
   - These improvements are reviewed and merged naturally alongside the feature PR.

2. **Major Evolutions (Human Alignment via `/grill-me`)**:
   - High-impact architectural proposals—such as modifications to CI/CD workflows (`.github/workflows/*.yml`), new review gates, or changing database rollback strategies—are never applied autonomously.
   - The agent formulates a structured `learning_proposal.md` artifact detailing trade-offs and diff previews, and requests a `/grill-me` interview with the developer before implementation.

---

## Automation Scripts (`scripts/`)

The repository provides four dedicated Python automation scripts in `scripts/`, each tied to specific workflow gates and operational lifecycles:

| Script | Workflow Step | Purpose | Primary Flags |
|---|---|---|---|
| `scripts/sync_backlog_status.py` | Step -3 & Step 8 | Audits and updates living documentation parity between `.planning/` architectural plans, `docs/backlog/features/` logs, and remote GitHub issues. | `--check`, `--fix` |
| `scripts/check_localization_orphans.py` | Step 7 (Gate 3) | Scans Flutter Mobile and Windows Console dictionaries to eliminate orphaned translation keys, enforcing Invariant 5 of `localization.md`. | `--all`, `--mobile`, `--desktop`, `--json` |
| `scripts/verify_pipeline.py` | Step 7 (Pre-PR Gate) | Overarching pre-flight gatekeeper validating 7 quality gates (OpenAPI, DB migrations, localization, code formatting, linters/`govulncheck`, unit tests, backlog sync). | `--fast`, `--format`, `--skip-tests` |
| `scripts/reconcile_issue_status.py` | Step 8 & CI | Reconciles merged PRs, applies `status: done`, auto-checks remaining issue checkboxes (`- [x]`), closes child issues, and evaluates parent trackers to mark tasks complete and set `status: ready`. | `--reconcile`, `--limit <N>` |
