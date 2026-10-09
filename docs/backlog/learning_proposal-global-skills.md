# Workflow Evolution Proposal: Global Skills Integration (Backend Go + context7 + memory)

## 1. Context & Motivation

The workstation now provides 60+ global OpenCode skills and 7 MCP servers
(codegraph, memory, docker, genoffice, stocky, github, context7) that did not
exist when the project workflow was authored for Antigravity. Project skills
cover process (feature-dev-workflow, devops-workflow, gh-project-manager) but
lack depth in Go security, fresh dependency docs, and cross-session lessons.
Recent evidence: google_fonts v9 breakage was diagnosed from a stale changelog
instead of live docs; the govulncheck toolchain root cause required manual
toolchain archaeology.

## 2. Proposed Changes

### G1 — golang-security hooks (per-area trigger + Step 7 gate)

- Target file(s): `.agent/skills/feature-dev-workflow/backend-standards.md`,
  `.agent/skills/feature-dev-workflow/review-standards.md`
- Summary of change: load global `golang-security` skill when touching auth,
  cryptography, file uploads, or raw SQL (per-area trigger in backend
  standards); require it at Step 7 pre-PR review alongside the existing
  Security Review checklist. Follow-up candidates (not in this batch):
  `golang-error-handling`, `golang-testing`, `golang-concurrency` for the
  WebSocket hub.

### G2 — context7 mandate on every dependency upgrade

- Target file(s): `.agent/skills/feature-dev-workflow/SKILL.md`,
  `.agent/skills/devops-workflow/SKILL.md`
- Summary of change: before adding or upgrading any Go/Flutter dependency,
  query live docs via `context7` (resolve-library-id, then query-docs) for
  breaking changes and migration notes. Covers minor/patch as well as major,
  since v9-style breakage hid behind a minor-looking bump.

### G3 — memory pattern for gotchas and decisions

- Target file(s): `AGENTS.md`,
  `.agent/skills/feature-dev-workflow/workflow-evolution.md`
- Summary of change: at Step 7.5 retrospective, persist technical gotchas AND
  agreed architectural decisions via `memory_store` plus Markdown mirror, and
  recall them at session start for related domains. Complements (not replaces)
  file-based workflow evolution. Never store secrets or tokens.

## 3. Trade-offs & Risks

- Benefits: security review gains checklist depth for free; upgrades stop
  relying on stale training data; lessons survive across sessions and IDEs.
- Potential Pitfalls: extra skill-load tokens per task; context7 needs
  network; memory needs curation to avoid stale entries. Mitigation: trigger
  security only on sensitive areas, context7 only on dep changes, memory
  writes only at Step 7.5 with user-visible notification.

## 4. Proposed Diff Preview

```diff
 # backend-standards.md (per-area trigger)
+When touching auth, JWT, cryptography, uploads, or raw SQL, load the global
+`golang-security` skill first and apply its checklist before implementation.

 # review-standards.md (Step 7 gate)
+Security Review runs global `golang-security` in addition to the local
+checklist. Record findings in the feature log audit report.

 # feature-dev-workflow/SKILL.md + devops-workflow/SKILL.md
+Before any dependency add/upgrade, query `context7` for breaking changes.
+Attach the migration notes link to the Decisions Log.

 # AGENTS.md + workflow-evolution.md
+Step 7.5 persists gotchas and decisions via memory_store (+Markdown mirror);
+session start recalls domain-relevant memories.
```

## 5. Next Steps

Grill resolution (2026-10-09): scope Backend Go first, SKILL.md-level
integration, context7 on all upgrades, memory stores gotchas plus decisions.
Awaiting user review of this proposal before implementation.
