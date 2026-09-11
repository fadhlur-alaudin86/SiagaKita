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
| 0 | **Branch & Assign** — Create `feature/F-XXX-name` from `dev`. Update issue label to `status: in-progress`, assign to active account (`--add-assignee "@me"`), and add comment to issue. | Git branch |
| 1 | **Read Mapping** — Inspect Go domain handler, DB schema (`docs/DATABASE_SCHEMA.md`), ERD (`docs/design/database-erd.md`), Activity/State diagrams (`docs/design/activity-diagrams.md`), API endpoints, and Flutter screens. | Discovery notes |
| 2 | **API Contract** — Extend `docs/api/paths/<domain>.yaml` with new endpoint(s) (OpenAPI 3.0). Add new schemas to `docs/api/components/schemas.yaml` if needed. Verify at `http://localhost:8080/docs`. | Updated domain YAML |
| 3 | **DB Migration** — Read `docs/DATABASE_SCHEMA.md` & `docs/design/database-erd.md`, write paired SQL migrations (`NNN_name.up.sql` & `NNN_name.down.sql`) in `backend-go/migrations/`. Update schema docs AND update Mermaid ERD. | Paired SQL migrations + updated schema + updated ERD |
| 4 | **Backend Implementation** — Implement handler, service, repository in `backend-go/internal/domain/<name>/`. If lifecycle states or actor capabilities change, update `docs/design/activity-diagrams.md` or `use-case-diagrams.md`. | Go source files + updated diagrams |
| 5 | **Flutter Implementation** — Implement screens/widgets/services in `mobile-flutter/` and/or `windows_console_flutter/`. | Dart source files |
| 6 | **Tests & Hybrid TDD** — Write Go unit tests (`_test.go`) with RED-GREEN cycle for critical logic + Flutter tests. Document test outcomes in feature log. | Test files + test docs |
| 7 | **Review Gate & Retrospective** — Run Pre-PR verification (Security, Database, Silent-Failure, and Dead-Code audits). Execute Step 7.5 Workflow Retrospective (apply minor skill updates or draft major proposals). Ensure CI passes. Sync issue checklist. Open PR targeting `dev`. | Pre-PR audit report + workflow updates + Pull Request |
| 8 | **Close Log & Evolution** — Update feature log (all steps ✅). Record applied workflow evolutions. Link PR. Move issue to Done. | Updated feature log |

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
7. **Read Schema First** — Read `docs/DATABASE_SCHEMA.md` and `docs/design/database-erd.md` before writing migrations.
8. **Reversible Migrations & Schema Sync** — Every database change MUST include both `NNN_name.up.sql` and `NNN_name.down.sql` following the Expand & Contract pattern. Update `docs/DATABASE_SCHEMA.md` AND `docs/design/database-erd.md`. See [postgres-patterns.md](postgres-patterns.md).
9. **YAGNI** — Do not add abstractions until explicitly needed.
10. **Max 3 Layers** — handler → service → repository. No deeper.
11. **Raw SQL** — No ORM. Use raw SQL via `pgx` with parameterized queries (`$1, $2`).
12. **Comment Every Public Symbol** — Provide `// why` comments on every public handler, function, middleware.
13. **Error Wrapping** — Always wrap errors with `fmt.Errorf("...: %w", err)` and inspect using `errors.Is`/`errors.As`.
14. **Conventional Commits MANDATORY** — Format: `<type>(<scope>): <description>`.

### API Contract (OpenAPI)
15. **Extend, don't create new** — New endpoints MUST be appended to the existing domain file `docs/api/paths/<domain>.yaml`. Never create a standalone per-feature file.
16. **Shared schemas go to components** — Any new reusable request/response schema must be added to `docs/api/components/schemas.yaml` using `$ref`.
17. **Verify Swagger UI** — After editing any YAML file, run the backend locally (`GO_ENV=development`) and confirm the endpoint appears correctly at `http://localhost:8080/docs`.
18. **Swagger UI is dev-only** — The `/docs` route is conditionally mounted only when `GO_ENV != production`. Never remove this guard.
19. **Keep contracts accurate** — If a backend handler changes its request/response shape, update the corresponding OpenAPI YAML in the same PR/commit.

### System Design & Living Documentation
20. **Living ERD Synchronization** — Any migration that adds/modifies tables, columns, or foreign keys MUST update both `docs/DATABASE_SCHEMA.md` and `docs/design/database-erd.md`.
21. **Living Activity & State Diagrams** — If a feature alters an incident lifecycle status (e.g. `incidents.status` or `incident_responses.status`), grace period logic, or mission flows, you MUST update `docs/design/activity-diagrams.md`.
22. **Living Use Case Diagrams** — If actor role capabilities or new administrative use cases are introduced, you MUST update `docs/design/use-case-diagrams.md`.

### Flutter
23. **Responsive Utilities** — Use `lib/core/utils/responsive.dart` for UI scaling.
24. **Session-Aware & Secure Storage** — Use `SessionService` with `flutter_secure_storage` for auth tokens.
25. **BuildContext Safety** — Always check `if (!context.mounted) return;` across async `await` boundaries.
26. **Offline-Resilient** — Utilize `OfflineService` for operations needing offline support.
27. **Widget Clean Architecture** — Extract components to standalone widget classes with `const` constructors.
28. **RepaintBoundary** — Wrap heavy list or chart widgets in `RepaintBoundary`.

### Testing & Hybrid TDD
29. **Hybrid TDD for Critical Logic** — Write tests first (RED) for SOS lifecycle, Auth/RBAC, Dispatch engine, and points/balance logic, then implement to pass (GREEN).
30. **Unit Tests per Handler** — Cover 4 mandatory scenarios: success, empty result, invalid input, DB error.
31. **Isolated Tests** — No shared state, fast (< 1s per file).
32. **Update Feature Log** — Record test command and status in feature log.

### GitHub Sync, Pre-PR Review & Merge Strategy
33. **Step 0 → in-progress & Assignee**: `gh issue edit <N> --add-label "status: in-progress" --remove-label "status: ready,status: in-review,status: done" --add-assignee "@me"` + explanatory comment when starting work. Always assign the issue to the active developer/agent account (`@me`) when picking up an issue.
34. **Step 7 → Pre-PR Verification Gate & Retrospective (MANDATORY)**:
    - **Automated Verification Pipeline (MANDATORY)**: Run `python3 scripts/verify_pipeline.py` (or `--fast` during intermediate iterations) to validate OpenAPI contracts, database migration sequence, localization dictionary parity, and run automated Go and Flutter suites. All checks must pass before opening PR.
    - **Self-Review Checklist**: Review all changed code against [review-standards.md](review-standards.md) (Security Review, Database & Migration Review, Silent Failure Audit, and Clean Code & Dead Code Elimination).
    - **Step 7.5 Workflow Retrospective**: Evaluate whether new technical gotchas, CLI flags, or patterns were learned (see [workflow-evolution.md](workflow-evolution.md)). If minor, apply directly to `.agent/skills/` and commit as `docs(workflow): ...` or `chore(skills): ...` before PR creation. If major, generate `learning_proposal.md` and propose `/grill-me`.
    - **Checklist Pre-Sync (MANDATORY)**: Before creating the PR, the agent MUST inspect the issue body and mark all completed Tasks and Acceptance Criteria checkboxes from `- [ ]` to `- [x]` via `gh issue edit <N> --body "..."`.
    - **Single Status Label**: Transition to `status: in-review` and ensure old status labels (`status: in-progress`, `status: ready`, `status: done`) are removed to prevent label stacking.
    - **Closing vs Parent Linking**: In the PR description, use `Closes #<child_issue>` for the issue being solved. If under an epic/tracker issue, specify `Parent Issue: #<parent_issue>` so the parent issue is not prematurely closed.
35. **Step 8 → Done & Closed**:
    - Merging into `dev` automatically updates the issue to `status: done`, removes previous status labels, auto-checks any remaining checkboxes, and closes the issue.
    - **Parent Tracker Sync**: If working under a parent issue, mark off the corresponding subtask checkbox (`- [ ]` to `- [x]`) in the parent issue body.
    - **Close Log & Record Evolution**: Mark all steps ✅ and record applied minor skill changes or major proposals in `docs/backlog/features/F-XXX-name.md`.
36. **Dev → Main MANUAL ONLY** — The agent MUST NOT merge `dev` to `main`. This is reserved for manual user action.
37. **PR to `dev` = Squash Merge MANDATORY** — All PRs from topic branches (`feature/*`, `fix/*`) targeting `dev` MUST use **Squash Merge**. All WIP/micro commits are squashed into 1 atomic Conventional Commit on `dev` (e.g., `feat(incident): add volunteer dispatch endpoint`).
38. **PR to `main` = Rebase Merge MANDATORY** — All PRs from `dev` targeting `main` MUST use **Rebase Merge** to preserve a clean, linear history for automated release notes.

### Evolutionary Workflow & Self-Improvement
39. **Continuous Workflow Retrospective** — At Step 7.5, actively check for institutional lessons. Minor updates to existing skills are bundled directly into the active topic branch before PR creation. See [workflow-evolution.md](workflow-evolution.md).
40. **Strict Minor vs. Major Boundary** — Never modify `.github/workflows/*.yml`, review gates, or branching/rollback policies autonomously. Major evolutions must be drafted in `learning_proposal.md` with `/grill-me` alignment before implementation.
41. **Context Hygiene & Anti-Bloat** — Keep all skill rules dense, actionable, and under 3 lines where possible. Prune dead prototypes and obsolete instructions immediately.


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

## Workflow Retrospective & Evolution

| Type | Skill / File | Changes / Proposal | Status |
|------|--------------|--------------------|--------|
| Minor | | | Applied |
| Major | | | Proposed (/grill-me) |

## Outputs Checklist

| # | Artifact | Status |
|---|----------|:------:|
| 1 | Feature log (`docs/backlog/features/F-XXX-name.md`) | ⬜ |
| 2 | API Contract (`docs/api/paths/<domain>.yaml`) | ⬜ |
| 3 | DB Migration (`backend-go/migrations/NNN_*.up.sql` & `*.down.sql`) | ⬜ |
| 4 | Updated `docs/DATABASE_SCHEMA.md` & `docs/design/database-erd.md` | ⬜ |
| 5 | Updated `docs/design/activity-diagrams.md` (if workflow/state changed) | ⬜ |
| 6 | Backend code (`backend-go/internal/domain/<name>/`) | ⬜ |
| 7 | Flutter code (`mobile-flutter/` / `windows_console_flutter/`) | ⬜ |
| 8 | Unit & widget tests (`*_test.go`, `*_test.dart`) | ⬜ |
| 9 | Pre-PR Review Audit (Security, DB, Silent-Failure, Dead-Code) | ⬜ |
| 10 | Pull request to `dev` (Squash Merge) | ⬜ |
| 11 | Workflow Retrospective (Minor updates / Major proposals logged) | ⬜ |
```

## Detailed References

- **[stacks.md](stacks.md)** — Go+Flutter project paths, patterns, and naming conventions.
- **[backend-standards.md](backend-standards.md)** — Go coding standards, error wrapping, context timeout, and Conventional Commits.
- **[flutter-standards.md](flutter-standards.md)** — Flutter/Dart standards, secure storage, mounted checks, and responsive sizing.
- **[postgres-patterns.md](postgres-patterns.md)** — PostgreSQL 15 & pgx v5 patterns, indexing (B-Tree & GIN), and migration safety.
- **[review-standards.md](review-standards.md)** — Pre-PR self-review checklists (Security, Database, Silent-Failure audits).
- **[workflow-evolution.md](workflow-evolution.md)** — Evolutionary workflow protocol, minor auto-update rules, and major proposal guidelines.
- **[testing.md](testing.md)** — Testing conventions, Hybrid TDD (RED-GREEN), and plan sanitization.
- **[gh-project-manager/SKILL.md](../gh-project-manager/SKILL.md)** — GitHub Issues, single-status rules, and sprint tracking.
- **[docs/DATABASE_SCHEMA.md](../../../docs/DATABASE_SCHEMA.md)** — Active schema v12 (always read before creating migrations).
- **[docs/design/database-erd.md](../../../docs/design/database-erd.md)** — Mermaid ERD living documentation.
