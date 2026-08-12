---
name: feature-dev-workflow
description: Contract-first feature development pipeline for SiagaKita (Go Fiber + Flutter). From Backlog Overview to PR to dev. Adapted from fast-prototyping-workflow for the Go+Flutter stack.
---

## Trigger Keywords

`new feature`, `feature`, `implementation`, `new endpoint`, `new screen`, `new API`, `add column`, `migration`, `dispatch`, `new domain`

## Stack Reference

Read [stacks.md](stacks.md) for domain structures and stack details (Go Fiber, Flutter, PostgreSQL).
Read [stacks.md](../stacks.md) for project configurations (repo, branches, milestone naming).

## Workflow Summary

| Step | Action | Artifacts |
|------|--------|-----------|
| -3 | **Backlog Overview** — Fetch issues via `gh` + read `DATABASE_SCHEMA.md` + read `stacks.md`. Print compact summary. User picks target. | Inline summary |
| -2 | **Discovery** — Explore codebase, inspect target domain, ask **5 clarifying questions**. Formulate plan and get user confirmation. | Discovery notes, 5 Q&A, Plan (in memory) |
| -1 | **Resolve Backlog** — Match/create GitHub Issue. Create `docs/backlog/features/F-XXX-name.md` using full template. | Feature log file |
| 0 | **Branch** — Create `feature/F-XXX-name` from `dev`. Update issue label to `status: in-progress`. Add comment to issue. | Git branch |
| 1 | **Read Mapping** — Inspect Go domain handler, DB schema, API endpoint, and Flutter screens. | Discovery notes |
| 2 | **API Contract** — Extend `docs/api/paths/<domain>.yaml` with new endpoint(s) (OpenAPI 3.0). Add new schemas to `docs/api/components/schemas.yaml` if needed. Verify at `http://localhost:8080/docs`. | Updated domain YAML |
| 3 | **DB Migration** — Read `docs/DATABASE_SCHEMA.md`, write SQL migration in `backend-go/migrations/`. Update schema docs. | SQL migration + updated schema |
| 4 | **Backend Implementation** — Implement handler, service, repository in `backend-go/internal/domain/<name>/`. | Go source files |
| 5 | **Flutter Implementation** — Implement screens/widgets/services in `mobile-flutter/` and/or `windows_console_flutter/`. | Dart source files |
| 6 | **Tests** — Write Go unit tests (`_test.go`) + Flutter tests. Document test outcomes in feature log. | Test files + test docs |
| 7 | **CI + Review** — Ensure CI passes. Update issue label to `status: in-review`. Open PR targeting `dev`. | Pull Request |
| 8 | **Close Log** — Update feature log (all steps ✅). Link PR. Move issue to Done. | Updated feature log |

## Agent Rules

### General
0. **Backlog Overview First** — Run Step -3 before Step -2 on first skill activation per session.
1. **Check Backlog First** — Run `gh issue list` before starting work to avoid duplicates.
2. **Create Feature Log at Step -1** — Write full log template to `docs/backlog/features/F-XXX-name.md`.
3. **Update Log per Step** — Mark progress ✅ with timestamp and decision rationale.
4. **Confirm Before Writing** — Ask user approval before modifying backend, DB, or Flutter files.
5. **Decision Logging** — Document every non-trivial design choice in the Decisions Log.
6. **Resume Protocol** — If interrupted or handing off, read feature log first → resume at first pending ⬜ step.

### Backend (Go Fiber)
7. **Read Schema First** — Read `docs/DATABASE_SCHEMA.md` before writing migrations.
8. **Update Schema After Migration** — Update `docs/DATABASE_SCHEMA.md` whenever schema changes.
9. **YAGNI** — Do not add abstractions until explicitly needed.
10. **Max 3 Layers** — handler → service → repository. No deeper.
11. **Raw SQL** — No ORM. Use raw SQL via `pgx` or `database/sql`.
12. **Comment Every Public Symbol** — Provide `// why` comments on every public handler, function, middleware.
13. **Conventional Commits MANDATORY** — Format: `<type>(<scope>): <description>`.

### API Contract (OpenAPI)
14. **Extend, don't create new** — New endpoints MUST be appended to the existing domain file `docs/api/paths/<domain>.yaml`. Never create a standalone per-feature file.
15. **Shared schemas go to components** — Any new reusable request/response schema must be added to `docs/api/components/schemas.yaml` using `$ref`.
16. **Verify Swagger UI** — After editing any YAML file, run the backend locally (`GO_ENV=development`) and confirm the endpoint appears correctly at `http://localhost:8080/docs`.
17. **Swagger UI is dev-only** — The `/docs` route is conditionally mounted only when `GO_ENV != production`. Never remove this guard.
18. **Keep contracts accurate** — If a backend handler changes its request/response shape, update the corresponding OpenAPI YAML in the same PR/commit.

### Flutter
14. **Responsive Utilities** — Use `lib/core/utils/responsive.dart` for UI scaling.
15. **Session-Aware** — Use `SessionService` for persistent session management.
16. **Offline-Resilient** — Utilize `OfflineService` for operations needing offline support.
17. **RepaintBoundary** — Wrap heavy list or chart widgets in `RepaintBoundary`.

### Testing
18. **Unit Tests per Handler** — Cover 4 mandatory scenarios: success, empty result, invalid input, DB error.
19. **Isolated Tests** — No shared state, fast (< 1s per file).
20. **Update Feature Log** — Record test command and status in feature log.

### GitHub Sync & Merge Strategy
21. **Step 0 → in-progress**: `gh issue edit <N> --add-label "status: in-progress"` + explanatory comment when starting work.
22. **Step 7 → in-review**: Opening a PR to `dev` automatically triggers `issue-status-labeler.yml` to update the linked issue to `status: in-review` and post a comment.
23. **Step 8 → Done**: Merging a PR into `dev` automatically triggers `issue-status-labeler.yml` to resolve and close linked issues.
24. **Dev → Main MANUAL ONLY** — The agent MUST NOT merge `dev` to `main`. This is reserved for manual user action.
25. **PR to `dev` = Squash Merge (Automated by `auto-merge-dev.yml`)** — Once a PR receives 1 Approval Review and passes CI checks, `auto-merge-dev.yml` automatically executes a **Squash Merge** into `dev` and deletes the feature branch.

## Feature Log Template

Every feature gets a dedicated log file at `docs/backlog/features/F-XXX-name.md`.

```markdown
# F-XXX: [Feature Name]

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-XXX |
| Title | |
| Requestor | |
| Date Created | |
| GitHub Issue | # |
| Status | Backlog / In Progress / In Review / Done |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| Go Domain | | |
| Endpoint | | |
| DB Table | | |
| Mobile Screen | | |
| Desktop Screen | | |

## 5 Clarifying Questions

| # | Question | Answer |
|---|----------|--------|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| -3 | Backlog Overview | ⬜ Pending | | |
| -2 | Discovery | ⬜ Pending | | |
| -1 | Resolve backlog | ⬜ Pending | | |
| 0 | Branch | ⬜ Pending | | |
| 1 | Read mapping | ⬜ Pending | | |
| 2 | API Contract | ⬜ Pending | | |
| 3 | DB Migration | ⬜ Pending | | |
| 4 | Backend Implementation | ⬜ Pending | | |
| 5 | Flutter Implementation | ⬜ Pending | | |
| 6 | Tests | ⬜ Pending | | |
| 7 | CI + Review | ⬜ Pending | | |
| 8 | Close Log | ⬜ Pending | | |

## Test Cases

| Layer | Test Name | Scenario | Run Command | Last Run | Status |
|-------|-----------|----------|-------------|----------|--------|
| handler | | success | | | |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| | | |
```
