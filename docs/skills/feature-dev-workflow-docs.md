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
| 7 | CI + Review — Verify CI status, open PR to `dev` (`issue-status-labeler.yml` updates issue to `status: in-review`) |
| 8 | Close Log — Update feature log (upon approval + CI pass, `auto-merge-dev.yml` merges PR & `issue-status-labeler.yml` closes issue) |

---

## Feature Log

Every feature maintains a dedicated log file at `docs/backlog/features/F-XXX-name.md` serving as the **single source of truth** for that feature's lifecycle across agent restarts and team handoffs.
