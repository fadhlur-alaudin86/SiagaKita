# Cavecrew Subagent Delegation Guide — Developer Documentation

This document provides human developers and AI coordinators with an overview of the **cavecrew** delegation pattern in SiagaKita.

---

## Overview

In complex multi-stack codebases like SiagaKita (`backend-go`, `mobile-flutter`, and `windows_console_flutter`), large conversations can quickly exhaust context windows due to verbose agent-to-agent chatter. **Cavecrew** standardizes three specialized subagent roles designed to execute tasks autonomously and return ultra-terse, structured receipts.

---

## Subagent Roles

### 1. `cavecrew-investigator`
- **Purpose**: Locates code references, call sites, API usages, and type definitions without suggesting architectural redesigns or edits.
- **Output Format**: Clean symbol tables indexed by `path:line`.
- **Usage Scenario**: Finding where an incident status enum or WebSocket message type is referenced across clients and backend.

### 2. `cavecrew-builder`
- **Purpose**: Performs small, surgical code modifications on 1 to 2 targeted files.
- **Constraints**: Refuses requests that span more than 2 files or introduce unrequested abstractions.
- **Usage Scenario**: Applying a quick bugfix to a Fiber handler, adding a localization lookup in a Flutter widget, or updating a database migration file.

### 3. `cavecrew-reviewer`
- **Purpose**: Conducts fast diff and pull request audits, checking for bugs, risks, or policy violations.
- **Severity Categories**: Uses ASCII severity tags (`[BUG]`, `[RISK]`, `[NIT]`, `[QUESTION]`) adhering strictly to the Clean Text Policy.
- **Usage Scenario**: Pre-PR sanity checks on changes before running the verification pipeline.

---

## Output Standards and Clean Text Compliance

All subagents under the cavecrew pattern strictly follow the repository governance:
1. **Clean Text**: No emojis or decorative icons are permitted in subagent outputs or reports.
2. **Deterministic Receipts**: Outputs must be parseable and predictable (e.g., `Totals: 1 [BUG], 0 [RISK]`).
3. **Auto-Clarity**: Full formal technical English is restored whenever critical security or destructive operational steps are encountered.
