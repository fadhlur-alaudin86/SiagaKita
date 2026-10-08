# SiagaKita Agent Bootstrap (OpenCode + Antigravity dual-support)

This file is the OpenCode entrypoint. Canonical governance remains in `GEMINI.md`.

## Session Start (mandatory)

1. Read `GEMINI.md` for localization, architecture, git, and planning invariants.
2. Read `.agent/rules/localization.md` for the 5 localization invariants.
3. Read `.agent/skills/README.md` + `.agent/skills/stacks.md` to select the active skill.
4. Read the active skill `SKILL.md` under `.agent/skills/<skill>/` before acting.

## Tool Mapping

Antigravity tool names differ from OpenCode. Follow the dual-tool table inside each skill when present:

| Antigravity | OpenCode native |
|-------------|-----------------|
| `grep_search` | `grep` |
| `find_by_name` | `glob` |
| `view_file` | `read` |
| `ask_question` | `question` |
| skill trigger keywords | `skill` tool with skill ID, or `@<skill-id>` mention |

If a skill mentions only the Antigravity name, use the OpenCode equivalent above.

## Verification Defaults

- Backend: `go test ./...`, `go vet ./...`, `gofmt -l .`
- Mobile/Desktop: `flutter analyze`, `dart format --output=none --set-exit-if-changed .`
- Pipeline gate: `python3 scripts/verify_pipeline.py --fast` for iterations, full `python3 scripts/verify_pipeline.py` before PR.
- Backlog parity: `python3 scripts/sync_backlog_status.py --check`

## Constraints

- Dual-support: do not duplicate `.agent/skills/` into `.opencode/skills/`. Single source is `.agent/skills/`, registered via `opencode.jsonc`.
- No uninstructed commits, pushes, or PRs.
- Written artifacts in formal technical English. Chat adapts to user language.
- Keep `GEMINI.md` canonical. Propose `AGENTS.md` changes via minor workflow update, major governance changes via `/grill-me`.
