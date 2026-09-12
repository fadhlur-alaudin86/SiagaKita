#!/usr/bin/env bash
#
# install_git_hooks.sh — Installs repository git hooks from .githooks/
# Usage: ./scripts/install_git_hooks.sh
#

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
GIT_DIR="$REPO_ROOT/.git"
HOOKS_SRC="$REPO_ROOT/.githooks"
HOOKS_DEST="$GIT_DIR/hooks"

if [ ! -d "$GIT_DIR" ]; then
    echo "[FAIL] .git directory not found. Please run this script inside the git repository."
    exit 1
fi

if [ ! -d "$HOOKS_SRC" ]; then
    echo "[FAIL] Source hooks directory $HOOKS_SRC not found."
    exit 1
fi

mkdir -p "$HOOKS_DEST"

# Install pre-commit hook
if [ -f "$HOOKS_SRC/pre-commit" ]; then
    cp "$HOOKS_SRC/pre-commit" "$HOOKS_DEST/pre-commit"
    chmod +x "$HOOKS_DEST/pre-commit"
    echo "[PASS] Installed .git/hooks/pre-commit (auto-formats staged Go and Dart files)"
fi

echo "[SUCCESS] Git hooks successfully installed."
