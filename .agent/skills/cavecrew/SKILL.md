---
name: cavecrew
description: >
  Decision guide for delegating tasks to compact subagents (investigator, builder, reviewer)
  with compressed context and structured output. Conserves parent context budget across long sessions
  while strictly adhering to the Clean Text and Icon Minimization Policy.
  Trigger: "delegate to subagent", "use cavecrew", "spawn investigator", "spawn builder",
  "spawn reviewer", "save context", "compressed subagent".
---

# Cavecrew Subagent Delegation Guide

Cavecrew defines structured, compact subagent delegation patterns designed to conserve the primary agent's context budget. When subagents return verbose prose, the parent context quickly degrades over multi-step workflows. Cavecrew specifies terse, deterministic output contracts for three specialized roles.

## Subagent Role Matrix

| Subagent Role | Primary Duty | Ideal Scope | Output Style |
|---|---|---|---|
| `cavecrew-investigator` | Locate definitions, references, call sites, file paths | Read-only discovery | Path-indexed symbol table, zero fix suggestions |
| `cavecrew-builder` | Surgical edits to 1-2 files | Known files, targeted changes | Edit receipt with verified diff range |
| `cavecrew-reviewer` | Review diffs, PRs, or file changes | Static audit against rules | Tagged line findings (`[BUG]`, `[RISK]`, `[NIT]`, `[QUESTION]`) |

## When to Use Cavecrew

- **Use `cavecrew-investigator`**: When identifying where symbols are declared, used, or tested across multiple domains (`backend-go`, `mobile-flutter`, `windows_console_flutter`).
- **Use `cavecrew-builder`**: When applying surgical edits (e.g., typos, function tweaks, localization adjustments) to at most 1-2 files where the exact paths and target lines are already identified.
- **Use `cavecrew-reviewer`**: When inspecting a branch diff, commit, or specific file against repository rules, safety invariants, and Clean Text policies.
- **Do NOT use subagents**: For trivial single-line changes already loaded in context, or cross-cutting architectural overhauls that require interactive parent alignment.

## Output Contracts

To minimize parent context consumption while honoring SiagaKita's Clean Text Policy (no decorative emojis/icons), all subagents must follow strict output contracts.

### 1. `cavecrew-investigator`
```
<Category>:
- <path:line> - `<symbol>` - <terse note <= 6 words>
- <path:line> - `<symbol>` - <terse note <= 6 words>

Totals: <N> defs, <N> refs, <N> tests.
```
- Grouping headers: `Defs:`, `Refs:`, `Callers:`, `Tests:`, `Imports:`.
- If zero matches found: emit single token `No match.`
- Refusal on fix/design requests: emit `Read-only. Delegate to builder or main thread.`

### 2. `cavecrew-builder`
```
<path:line-range> - <change description <= 10 words>.
verified: <re-read OK | mismatch @ path:line>.
```
- Hard boundary: maximum 2 files per invocation.
- Refusals (terminal single tokens):
  - 3+ files: `too-big. split: <tasks>.`
  - Ambiguous requirements: `ambiguous. ask: <question>.`
  - Verification regression: `regressed. revert path:line. cause: <error>.`

### 3. `cavecrew-reviewer`
```
<path:line>: [SEVERITY] <summary>. <remediation>.
Totals: <N> [BUG], <N> [RISK], <N> [NIT], <N> [QUESTION].
```
- Severity tags (ASCII standard):
  - `[BUG]`: Logic error, crash, security vulnerability, data loss.
  - `[RISK]`: Race condition, memory leak, unhandled edge case, performance cliff.
  - `[NIT]`: Style, documentation, minor formatting.
  - `[QUESTION]`: Ambiguous intent requiring clarification.
- If zero findings: emit single token `No issues.`

## Chaining Workflow

1. **Locate (`cavecrew-investigator`)**: Retrieve exact file paths and symbol references.
2. **Execute (`cavecrew-builder`)**: Apply surgical edits to specific target files.
3. **Verify (`cavecrew-reviewer` & pipeline)**: Review the resulting diff and run `python3 scripts/verify_pipeline.py`.

## Clean Text & Auto-Clarity Exceptions

- **Clean Text Mandate**: Under no circumstances should subagents emit emoji markers (e.g., colored circles or alert icons). Use standard ASCII tags (`[BUG]`, `[RISK]`).
- **Auto-Clarity Override**: Subagents must drop compression and use standard formal technical English for security warnings, destructive database/filesystem operations, or irreversible state transitions.
