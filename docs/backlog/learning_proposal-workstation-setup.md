# Setup Proposal: Zero-Guess Workstation Onboarding (OpenCode + Antigravity)

## 1. Context & Motivation

Contributors currently assemble their workstation from scattered hints
(README lists only Docker/Go/Flutter). MCP servers, linters, git hooks, and
IDE wiring are tribal knowledge. Goal: one check-plus-install script and one
guide covering Linux, macOS, and Windows for both IDEs.

## 2. Proposed Changes

### S1 — `scripts/setup_workstation.sh` (check plus guided install)

- OS detection (Linux/macOS/WindowsGitBash) with per-OS install hints.
- Checks with minimum versions, prompts before installing anything:
  - Core: `git`, `gh` (auth status), Go >= 1.27, Flutter/Dart
    (`flutter doctor`), Python 3, Node/npx, `uvx`.
  - Quality gates: `golangci-lint`, `govulncheck`, `jq`.
  - Repo wiring: `scripts/install_git_hooks.sh`, `flutter pub get` and
    `go mod download` per workspace (no upgrades).
- IDE + MCP verification (never auto-installs IDEs, only verifies):
  - OpenCode CLI present, `AGENTS.md` + `opencode.jsonc` load.
  - Antigravity: `.agent/skills/` + `GEMINI.md` readable.
  - Core MCPs reachable: `codegraph` CLI, `github`, `context7` (npx),
    `memory` server. GenOffice/stocky/docker stay optional.
- Final scorecard PASS/WARN/FAIL per component with exact fix commands.

### S2 — `docs/SETUP.md` (both IDEs, full path)

- Part A (shared): toolchain table with versions, Docker Compose for
  postgres/redis, `.env` from `.env-example`, migrations, run commands
  per client (mirrors README Getting Started, extended).
- Part B (OpenCode): CLI install, `AGENTS.md` session start/end, skill
  discovery via `opencode.jsonc`, `question` tool for interviews.
- Part C (Antigravity): `.agent/skills` catalog, `GEMINI.md` governance,
  trigger keywords, `ask_question` pairing mode.
- Part D (MCP appendix): the core four plus optional three, what each is
  used for in the workflow, and how to disable one.
- README Getting Started links to `docs/SETUP.md` as canonical onboarding.

## 3. Trade-offs & Risks

- Benefits: new contributors productive in one sitting; fewer
  works-on-my-machine issues; CI parity documented.
- Potential Pitfalls: install hints rot as vendors change URLs; Windows
  paths differ; script must stay read-mostly to stay trustworthy.
  Mitigation: script checks by default, installs only on explicit opt-in
  per component; versions pinned in one table in `docs/SETUP.md`.

## 4. Next Steps

Awaiting user review of this proposal before implementation.
