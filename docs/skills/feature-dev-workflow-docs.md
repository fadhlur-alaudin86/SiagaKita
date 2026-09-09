# Feature Dev Workflow — SiagaKita Developer Guide

This guide describes the contract-first feature development pipeline for SiagaKita (Go Fiber + Flutter).

---

## Pipeline Overview

```
Backlog Overview → Discovery → Issue → Branch → Contract → Backend → Flutter → Test → PR → dev
```

| Step | Action |
|------|--------|
| -3 | Backlog Overview — Fetch remote issues, pick target feature |
| -2 | Discovery — Codebase exploration & 5 clarifying questions |
| -1 | Resolve Backlog — Create/match GitHub issue, write feature log |
| 0 | Branch — Create `feature/F-XXX-name` from `dev` |
| 1 | Read Mapping — Inspect domain handlers, DB schema, API contracts, Flutter screens |
| 2 | API Contract — Write `docs/api/feat-xxx.yaml` |
| 3 | DB Migration — Write `.sql` migration file, update schema docs |
| 4 | Backend Implementation — Implement Go handlers/services/repositories |
| 5 | Flutter Implementation — Implement Flutter screens/widgets/services |
| 6 | Tests — Go table-driven unit tests + Flutter widget tests |
| 7 | Review Gate & Retrospective — Verify 4 audit dimensions (Security, DB, Silent-Failure, Dead-Code), run Step 7.5 Workflow Retrospective, open PR to `dev` (`issue-status-labeler.yml` updates issue to `status: in-review`) |
| 8 | Close Log & Evolution — Update feature log, log applied workflow evolutions (upon approval + CI pass, `auto-merge-dev.yml` merges PR & `issue-status-labeler.yml` closes issue) |

---

## Feature Log

Every feature maintains a dedicated log file at `docs/backlog/features/F-XXX-name.md` serving as the **single source of truth** for that feature's lifecycle across agent restarts and team handoffs.

---

## Evolutionary Workflows & Self-Improving Skills

To prevent workflow rot and preserve hard-earned engineering lessons across sessions, AI workers actively run a **Workflow Retrospective** at Step 7.5 before opening a Pull Request:

1. **Minor Evolutions (Autonomous Execution)**:
   - Minor enhancements—such as technical quirks, new CLI flags, testing gotchas, and database indexing tricks—are added directly to `.agent/skills/` and committed into the active feature branch as a separate commit (`docs(workflow): ...` or `chore(skills): ...`).
   - These improvements are reviewed and merged naturally alongside the feature PR.

2. **Major Evolutions (Human Alignment via `/grill-me`)**:
   - High-impact architectural proposals—such as modifications to CI/CD workflows (`.github/workflows/*.yml`), new review gates, or changing database rollback strategies—are never applied autonomously.
   - The agent formulates a structured `learning_proposal.md` artifact detailing trade-offs and diff previews, and requests a `/grill-me` interview with the developer before implementation.
