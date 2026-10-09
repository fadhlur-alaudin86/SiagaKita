#!/usr/bin/env bash
#
# setup_workstation.sh — Zero-guess workstation check for SiagaKita contributors.
#
# Verifies toolchains, IDE wiring, and MCP reachability for both OpenCode and
# Antigravity on Linux, macOS, and Windows (Git Bash). Check-only by default;
# installs or mutating actions run only after explicit per-component approval.
#
# Usage:
#   ./scripts/setup_workstation.sh
#
# Exit codes: 0 all PASS, 1 one or more FAIL, 2 unsupported environment.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PASS=0
WARN=0
FAIL=0

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

OS="$(detect_os)"
if [ "$OS" = "unknown" ]; then
    echo "[FAIL] Unsupported OS: $(uname -s). Linux, macOS, or Windows (Git Bash) required."
    exit 2
fi
echo "Detected OS: $OS"
echo ""

report() {
    # $1 = PASS|WARN|FAIL, $2 = label, $3 = detail/fix (optional)
    case "$1" in
        PASS) PASS=$((PASS + 1)); echo "[PASS] $2" ;;
        WARN) WARN=$((WARN + 1)); echo "[WARN] $2${3:+ — $3}" ;;
        FAIL) FAIL=$((FAIL + 1)); echo "[FAIL] $2${3:+ — $3}" ;;
    esac
}

ask_install() {
    # $1 = prompt label. Returns 0 only on explicit yes.
    local answer=""
    printf "Install/fix '%s' now? [y/N] " "$1"
    read -r answer || true
    [ "$answer" = "y" ] || [ "$answer" = "Y" ]
}

install_hint() {
    # $1 = tool, $2 = linux hint, $3 = macos hint, $4 = windows hint
    case "$OS" in
        linux) echo "$2" ;;
        macos) echo "$3" ;;
        windows) echo "$4" ;;
    esac
}

check_cmd() {
    # $1 = command, $2 = purpose, $3 = install hint
    if command -v "$1" >/dev/null 2>&1; then
        report PASS "$1 available ($2)"
        return 0
    fi
    if ask_install "$1 ($2). Hint: $3"; then
        echo "Run manually: $3 (re-run this script afterwards)"
    fi
    report FAIL "$1 missing ($2)" "$3"
    return 0
}

check_version() {
    # $1 = command, $2 = version args, $3 = required prefix/desc, $4 = purpose
    local out=""
    out="$("$1" $2 2>&1 | head -1)" || out="unknown"
    echo "  version: $out (requires: $3)"
}

echo "=== 1. Core toolchain ==="
check_cmd git "version control" "$(install_hint git 'sudo apt install git' 'brew install git' 'winget install Git.Git')"
check_cmd gh "GitHub CLI" "$(install_hint gh 'see https://cli.github.com' 'brew install gh' 'winget install GitHub.cli')"
if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
        report PASS "gh authenticated as $(gh api user -q .login 2>/dev/null || echo '?')"
    else
        report WARN "gh not authenticated" "run: gh auth login"
    fi
fi
check_cmd go "backend toolchain" "$(install_hint go 'see https://go.dev/dl' 'brew install go' 'winget install GoLang.Go')"
if command -v go >/dev/null 2>&1; then check_version go version "go >= 1.27" "backend"; fi
check_cmd flutter "mobile/desktop toolchain" "$(install_hint flutter 'see https://docs.flutter.dev/get-started/install' 'brew install flutter' 'see https://docs.flutter.dev/get-started/install/windows')"
check_cmd dart "Dart SDK (ships with Flutter)" "$(install_hint dart 'install Flutter' 'install Flutter' 'install Flutter')"
check_cmd python3 "pipeline scripts" "$(install_hint python3 'sudo apt install python3' 'brew install python3' 'winget install Python.Python.3')"
check_cmd node "MCP servers via npx" "$(install_hint node 'see https://nodejs.org' 'brew install node' 'winget install OpenJS.NodeJS')"
check_cmd uvx "Python MCP servers" "$(install_hint uvx 'pip install uv / see https://docs.astral.sh/uv' 'brew install uv' 'winget install astral-sh.uv')"
check_cmd jq "script JSON parsing" "$(install_hint jq 'sudo apt install jq' 'brew install jq' 'winget install jqlang.jq')"
check_cmd docker "postgres/redis via compose" "$(install_hint docker 'see https://docs.docker.com/engine/install' 'brew install --cask docker' 'winget install Docker.DockerDesktop')"

echo ""
echo "=== 2. Quality gates ==="
check_cmd golangci-lint "Go lint gate" "$(install_hint golangci-lint 'see https://golangci-lint.run/welcome/install' 'brew install golangci-lint' 'see https://golangci-lint.run/welcome/install')"
check_cmd govulncheck "Go vuln gate" "go install golang.org/x/vuln/cmd/govulncheck@v1.8.0"

echo ""
echo "=== 3. Repo wiring ==="
if [ -f "$REPO_ROOT/scripts/install_git_hooks.sh" ]; then
    if [ -x "$REPO_ROOT/.git/hooks/pre-commit" ]; then
        report PASS "git pre-commit hook installed"
    else
        if ask_install "git hooks (formats staged Go/Dart on commit)"; then
            "$REPO_ROOT/scripts/install_git_hooks.sh"
        else
            report WARN "git hooks not installed" "run: ./scripts/install_git_hooks.sh"
        fi
    fi
fi
if [ -f "$REPO_ROOT/infrastructure/.env-example" ] && [ ! -f "$REPO_ROOT/infrastructure/.env" ]; then
    report WARN "infrastructure/.env missing" "copy from infrastructure/.env-example"
else
    report PASS "infrastructure env file present (or no example to copy)"
fi

echo ""
echo "=== 4. IDE wiring (verify only, never auto-installs IDEs) ==="
[ -f "$REPO_ROOT/AGENTS.md" ] && [ -f "$REPO_ROOT/opencode.jsonc" ] \
    && report PASS "OpenCode entrypoint (AGENTS.md + opencode.jsonc)" \
    || report FAIL "OpenCode entrypoint missing" "pull latest dev"
[ -f "$REPO_ROOT/GEMINI.md" ] && [ -d "$REPO_ROOT/.agent/skills" ] \
    && report PASS "Antigravity entrypoint (GEMINI.md + .agent/skills/)" \
    || report FAIL "Antigravity entrypoint missing" "pull latest dev"
if command -v opencode >/dev/null 2>&1; then
    report PASS "opencode CLI installed"
else
    report WARN "opencode CLI not found" "see https://opencode.ai/docs (Antigravity-only contributors may skip)"
fi

echo ""
echo "=== 5. Core MCP reachability ==="
if command -v codegraph >/dev/null 2>&1; then
    report PASS "codegraph CLI ($(codegraph --version 2>/dev/null | head -1))"
else
    report WARN "codegraph CLI missing" "install codegraph to enable code intelligence MCP"
fi
if command -v npx >/dev/null 2>&1; then
    report PASS "npx available (serves github + context7 MCPs)"
else
    report WARN "npx missing" "install Node.js to enable github/context7 MCPs"
fi
if [ -d "$HOME/.config/opencode/memory-mcp" ] || [ -d "%APPDATA%/opencode/memory-mcp" ]; then
    report PASS "memory MCP checkout present"
else
    report WARN "memory MCP not detected" "optional: needed only for cross-session lesson recall"
fi

echo ""
echo "======================================================="
echo " Scorecard: $PASS pass, $WARN warn, $FAIL fail"
echo "======================================================="
if [ "$FAIL" -gt 0 ]; then
    echo "Resolve FAIL items above, then re-run this script."
    exit 1
fi
echo "Workstation ready. See docs/SETUP.md for the full guide."
