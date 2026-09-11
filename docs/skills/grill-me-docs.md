# Grill-Me Alignment — Developer Guide

This document explains the `/grill-me` architectural interview protocol used by developers and AI agents in SiagaKita to pressure-test plans and align on technical decisions before authoring code.

---

## When to Use `/grill-me`

Invoke `/grill-me` whenever a task involves:
- Architectural redesigns or introducing new services/domains.
- Database schema changes (e.g. new tables, foreign keys, or indexing strategies).
- Critical state machine transitions (e.g. SOS dispatch lifecycle, volunteer strike escalation).
- Breaking changes to multi-client API contracts.
- Significant ambiguity with multiple technical trade-offs.

---

## How It Works: The Design Tree Frontier

1. **Autonomous Fact Exploration**:
   - The agent first scans the codebase (`docs/DATABASE_SCHEMA.md`, `backend-go/internal/domain/`, `mobile-flutter/`, `windows_console_flutter/`).
   - The agent never asks the user questions about existing facts that can be read directly from the code.

2. **Frontier Questioning in Rounds**:
   - The agent maps decisions into a dependency tree.
   - Questions whose prerequisites are already settled form the active **frontier**.
   - Questions are presented with numbered options and an explicit `(Recommended)` tag with technical rationale.

3. **Settling the Frontier**:
   - As the user answers, the frontier expands to dependent questions until all branches are explored.
   - The session terminates when the frontier is empty or the user commands execution.

4. **Output Specification Artifact**:
   - All aligned decisions are formalized into a feature specification artifact (`docs/backlog/features/F-XXX-spec.md`) before implementation begins.
