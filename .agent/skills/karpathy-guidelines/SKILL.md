---
name: karpathy-guidelines
description: Behavioral guidelines to reduce common LLM coding mistakes in SiagaKita. Enforces thinking before coding, simplicity first (KISS/YAGNI), surgical edits without side-effects, and goal-driven execution across Go Fiber and Flutter codebases.
license: MIT
---

# Karpathy Behavioral Guidelines — SiagaKita

Behavioral guidelines to reduce common AI assistant and developer coding pitfalls in the multi-stack SiagaKita codebase (Go Fiber backend, Flutter mobile, and Flutter desktop console), derived from Andrej Karpathy's observations on LLM engineering antipatterns.

---

## 1. Think Before Coding

**Do not assume. Do not hide confusion. Surface trade-offs proactively.**

Before writing or modifying code:
- **State Assumptions Explicitly**: If an issue or user prompt leaves room for interpretation, declare the working assumption before acting.
- **Inspect Before Asking**: Never ask the user questions that can be answered by exploring the codebase via `grep_search`, `find_by_name`, `view_file`, or `codegraph`.
- **Surface Multiple Interpretations**: If a requirement has multiple viable architectural paths, present them with pros and cons rather than choosing silently.
- **Push Back on Complexity**: If a simpler alternative exists, state it directly and recommend the cleaner approach.
- **Halt on Uncertainty**: If a domain rule, state transition, or schema relation is ambiguous, pause immediately, identify the exact ambiguity, and ask for clarification.

---

## 2. Simplicity First (KISS & YAGNI)

**Write the minimum code that solves the problem. Never introduce speculative engineering.**

- **No Premature Features**: Build strictly what was requested. Never add unrequested options, speculative configuration hooks, or unused parameters.
- **No Single-Use Abstractions**: Avoid introducing interfaces, generics, wrapper layers, or helper abstractions when direct, concrete code is clearer.
- **Flat Over Nested**: Keep logic structures flat and readable. Avoid deep nesting, complex ternary operators, or clever one-liners.
- **Standard Over Custom**: Prefer standard library packages and proven existing dependencies over novel custom constructs.
- **Conciseness Review**: If an implementation spans 150 lines where 40 lines of clear procedural code suffices, rewrite it cleanly.

---

## 3. Surgical Changes

**Touch only what is strictly necessary. Clean up only your own impact.**

When editing existing code:
- **Preserve Adjacent Code**: Never reformat, "clean up", or edit adjacent lines, unrelated comments, or untouched functions.
- **Preserve Existing Style**: Match the local idiom and indentation of the file being modified, even if you prefer a different convention.
- **Do Not Fix Unrelated Issues**: If you spot unrelated dead code or bugs during an edit, mention them to the user or note them in an issue; do not touch them in the current turn.
- **Prune Self-Created Orphans**: If your changes render an import, variable, helper, or localization key unused, prune it immediately. Never leave orphaned symbols behind.
- **Traceability Test**: Every single modified line in a git diff must trace directly to the explicit user request or requirement.

---

## 4. Goal-Driven Execution

**Define verifiable success criteria upfront. Loop until verified.**

Transform every task into an objective, automated validation loop:
- **Bug Fixes**: Reproduce the failure via a targeted test or analyzer run first, apply the surgical fix, then verify the test passes.
- **Refactoring**: Ensure existing unit test suites and linters pass cleanly before and after the change.
- **Multi-Stack Parity**: When modifying API routes or DTOs, verify parity across backend Go handlers, Flutter mobile, and Flutter desktop console.

For multi-step implementations, structure work into explicit verifiable milestones:
```text
1. [Milestone Action] -> Verify: [Exact test / analyze command]
2. [Milestone Action] -> Verify: [Exact test / analyze command]
```
Strong, deterministic success criteria enable confident execution without guesswork.
