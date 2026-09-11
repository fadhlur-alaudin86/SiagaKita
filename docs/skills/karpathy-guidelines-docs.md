# Karpathy Guidelines — Developer Guide

This document provides developer guidelines based on Andrej Karpathy's engineering observations to ensure AI agents and engineers maintain extreme discipline, simplicity, and safety when working on SiagaKita.

---

## The 4 Invariants

### 1. Think Before Coding
- **State Assumptions First**: Never proceed on unstated hunches. If a requirement has multiple interpretations, state them explicitly.
- **Autonomous Discovery**: Never ask human developers questions that code exploration (`grep`, `codegraph`, `find`) can answer.
- **Push Back on Complexity**: If a proposed design is needlessly complicated, propose a simpler KISS alternative.

### 2. Simplicity First (KISS & YAGNI)
- **Minimum Code That Solves the Problem**: Do not build speculative hooks, generic interfaces for single-use implementations, or unneeded configuration options.
- **Flat Over Nested**: Keep code linear, readable, and easy to trace.
- **Conciseness**: Prefer 40 lines of clear procedural code over 150 lines of over-abstracted layers.

### 3. Surgical Changes
- **Target Line Focus**: Modify strictly the symbols and lines required to complete the task.
- **Preserve Adjacent Context**: Never reformat, "beautify", or touch adjacent code or unrelated comments.
- **Prune Self-Created Orphans**: If an edit makes an import, variable, or localization key obsolete, remove it immediately.
- **Zero Unrequested Refactoring**: If you notice unrelated dead code or bugs, report them; do not modify them in the current turn.

### 4. Goal-Driven Execution
- **Verifiable Success Criteria**: Every task must be backed by a clear test command or linter check (`go test ./...`, `flutter analyze --fatal-infos`).
- **Milestone Loop**: Implement -> Verify -> Confirm. Never declare completion without automated verification.

---

## Code File Hygiene

### Architecture Header
Every non-trivial file (`.go`, `.dart`) should begin with an architecture header comment:
```go
// Package auth handles user authentication, session issuance, and token rotation.
//
// Purpose:
//   Authenticates civilians, volunteers, and agency dispatchers using JWT credentials.
//
// Data & Logic Flow:
//   1. Request credentials parsed and sanitized.
//   2. User looked up in PostgreSQL via pgx/v5.
//   3. Password verified with bcrypt.
//   4. JWT JTI session stored in Redis for single-device SessionGuard.
//   5. Tokens returned to client.
//
// Key Components:
//   - LoginHandler: HTTP Fiber entrypoint.
//   - AuthService: Business logic and credential verification.
//   - SessionGuard: Redis single-device enforcement.
```

### Visual Breathing Room
- Maintain 2 blank lines between major functions, structs, endpoint handlers, and distinct logic sections to ensure clean visual separation of concerns.
