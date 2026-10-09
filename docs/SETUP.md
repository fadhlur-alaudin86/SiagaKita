# SiagaKita Workstation Setup (OpenCode + Antigravity)

One-time onboarding for new contributors. Start with the automated check,
then follow your IDE path below.

```bash
./scripts/setup_workstation.sh
```

The script is check-only by default: it reports PASS/WARN/FAIL per component
and installs or mutates nothing without explicit per-component approval.
Re-run it until the scorecard shows 0 failures.

## Part A — Shared toolchain

| Component | Minimum | Verify |
|-----------|---------|--------|
| Git | any recent | `git --version` |
| GitHub CLI (`gh`) + auth | logged in | `gh auth status`, `gh api user -q .login` |
| Go | 1.27 | `go version` |
| Flutter / Dart | stable | `flutter doctor` |
| Python 3 | 3.10 | `python3 --version` |
| Node.js + npx | LTS | `node --version` |
| uvx | any | `uvx --version` |
| jq | any | `jq --version` |
| Docker + Compose | any recent | `docker compose version` |
| golangci-lint | latest | `golangci-lint --version` |
| govulncheck | v1.8.0 | `go install golang.org/x/vuln/cmd/govulncheck@v1.8.0` |

OS-specific install hints are printed by the script (apt/brew/winget).

### Services and first run

1. `cp infrastructure/.env-example infrastructure/.env` (if missing) and fill secrets.
2. `cd infrastructure && docker compose up -d postgres redis`.
3. `cd ../backend-go && go run cmd/migrate/main.go up`, then `go run cmd/api/main.go` (Swagger UI at `http://localhost:8080/docs/`).
4. `cd ../mobile-flutter && flutter pub get && flutter run`; desktop: `cd ../windows_console_flutter && flutter run -d linux`.
5. Install repo git hooks once: `./scripts/install_git_hooks.sh` (auto-formats staged Go/Dart on commit).
6. Sanity gate: `python3 scripts/verify_pipeline.py --fast`.

## Part B — OpenCode path

1. Install the OpenCode CLI (see https://opencode.ai/docs). Antigravity-only contributors may skip this.
2. Session start (mandatory, from `AGENTS.md`): read `GEMINI.md`, `.agent/rules/localization.md`, `.agent/skills/README.md` + `stacks.md`, then the active skill `SKILL.md`. Recall domain-relevant memories before planning.
3. Skills resolve from `./.agent/skills` via `opencode.jsonc` (single source, no `.opencode/` duplication). Load with the `skill` tool or `@<skill-id>` mention.
4. Interactive interviews use the native `question` tool in frontier rounds.
5. Session end: persist gotchas and decisions via memory plus Markdown mirror, then notify the user.

## Part C — Antigravity path

1. Open the repo folder; governance root is `GEMINI.md` (canonical).
2. Skill catalog is `.agent/skills/README.md`; stack config is `.agent/skills/stacks.md`. Read both before acting, then the active `<skill>/SKILL.md`.
3. Trigger keywords per skill are listed in each `SKILL.md` and the catalog table.
4. Interactive pairing uses the `ask_question` tool; dual-tool tables in each skill map Antigravity names to OpenCode equivalents.

## Part D — MCP appendix

Core four (verified by the script):

| MCP | Used for | Disable if |
|-----|----------|------------|
| codegraph | Code intelligence over the indexed graph | navigating a small checkout manually |
| github | Issue/PR ops alternative to `gh` CLI | `gh` CLI covers your flow |
| context7 | Live library docs on every dependency upgrade | working offline |
| memory | Cross-session gotchas and decisions | single-session tasks |

Optional: `docker` (container ops), `genoffice` (office docs), `stocky`
(stock photos). None is required to build or test the project.

Before any push, confirm `gh api user -q .login` shows an account with write
access: the active `gh` account can flip between sessions, and git resolves
push credentials through it.
