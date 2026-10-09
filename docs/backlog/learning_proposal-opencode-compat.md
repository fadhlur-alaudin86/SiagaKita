# Workflow Evolution Proposal: OpenCode Dual-Support (Major Batch 1-3)

## 1. Context & Motivation

The repository workflow is specialized for Antigravity (`.agent/skills/`, `GEMINI.md`, `ask_question`, `grep_search`).
OpenCode does not auto-load `GEMINI.md` or `.agent/` (singular), ignores trigger-keyword tables, and runs headless without interactive IDE memory.
Three frictions block `feature-dev-workflow` in OpenCode: governance classification omits OpenCode entrypoints, skill discovery fails, and interactive confirmation gates stall.

Prior minor fixes applied: `AGENTS.md` bootstrap pointer, `opencode.jsonc` with `skills: ["./.agent/skills"]`, dual-tool mapping in `karpathy-guidelines/SKILL.md:19` and `grill-me/SKILL.md:43`.

## 2. Proposed Changes

### P1 — Governance classification covers OpenCode entrypoints

- Target file(s): `.agent/skills/feature-dev-workflow/workflow-evolution.md:22`
- Summary of change: extend Major column target list from `.github/workflows/*.yml, review-standards.md, devops-workflow/SKILL.md, GEMINI.md` to include `AGENTS.md, opencode.jsonc, .opencode/commands/*.md`. Minor column stays for standards files. Rationale: `AGENTS.md` is now the OpenCode governance entrypoint; ungated edits to it diverge from `GEMINI.md` canonical.

### P2 — Skill discovery via description, not trigger keywords

- Target file(s): `.agent/skills/README.md:49-58`, each `<skill>/SKILL.md` frontmatter `description`, `feature-dev-workflow/SKILL.md:6-8`
- Summary of change: keep trigger-keyword tables for Antigravity readability, but declare `description` as the discovery contract for OpenCode (`skill` tool uses ID + name + description; `@<skill-id>` mention for explicit load). Rewrite each `description` to start with a verb plus when-to-use clause, under 20 words. No duplication into `.opencode/skills/`.

### P3 — Headless-safe confirmation for feature-dev-workflow

- Target file(s): `.agent/skills/feature-dev-workflow/SKILL.md:20,39`
- Summary of change: replace blocking assumption (5 clarifying questions in memory, confirm before writing, Swagger check at `localhost:8080/docs`) with: write discovery plan to `docs/backlog/features/F-XXX-name.md` first, then ask via native questioning tool (`ask_question` on Antigravity, `question` on OpenCode) with file-backed fallback. Swagger UI check gains headless alternative (`curl localhost:8080/openapi.yaml` or schema diff), so Step 2 passes without a browser.

## 3. Trade-offs & Risks

- Benefits: governance parity across IDEs, OpenCode skill autoinvoke works without duplication, feature pipeline no longer stalls in non-TTY runs.
- Potential Pitfalls: longer `description` lines increase catalog tokens slightly; file-backed plan adds one write per feature; dual-tool wording adds one line per affected rule. Mitigation: enforce 3-line rule and replace-dont-stack invariant.

## 4. Proposed DDL / YAML / Markdown Diff Preview

```diff
 # workflow-evolution.md:22
-| **Target Files** | `testing.md`, ... | `.github/workflows/*.yml`, `review-standards.md`, `devops-workflow/SKILL.md`, `GEMINI.md`. |
+| **Target Files** | `testing.md`, `postgres-patterns.md`, `backend-standards.md`, `flutter-standards.md`, `.agent/skills/README.md`. | `.github/workflows/*.yml`, `review-standards.md`, `devops-workflow/SKILL.md`, `GEMINI.md`, `AGENTS.md`, `opencode.jsonc`, `.opencode/commands/*.md`. |

 # feature-dev-workflow/SKILL.md frontmatter
-description: Contract-first feature development pipeline for SiagaKita (Go Fiber + Flutter). From Backlog Overview to PR to dev. Adapted from fast-prototyping-workflow for the Go+Flutter stack.
+description: Build Go Fiber + Flutter features contract-first from backlog to PR to dev. Use when adding endpoints, screens, migrations, or dispatch domains.

 # feature-dev-workflow/SKILL.md:20,39
-ask **5 clarifying questions**. Formulate plan and get user confirmation. | Discovery notes, 5 Q&A, Plan (in memory)
+ask up to 5 clarifying questions via native questioning tool. Write plan to `docs/backlog/features/F-XXX-name.md` first, then confirm. | Discovery notes, 5 Q&A, Plan (file-backed)
```

## 5. Next Steps

Grill resolution (2026-10-09): P1 keep `.opencode/commands/*.md` in Major list. P2 rewrite all 8 descriptions (verified 13-19 words). P3 file-backed plan mandatory, Swagger check via `curl openapi.yaml` plus diff. Implemented in working tree, uncommitted pending PR to `dev`.
