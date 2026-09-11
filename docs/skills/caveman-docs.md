# Caveman Communication Mode — Developer Documentation

This document explains the purpose and usage of the **caveman** skill in SiagaKita.

---

## What is Caveman Mode?

**Caveman Mode** is an optional communication preset that instructs AI workers to communicate using terse, direct language without filler words or decorative pleasantries. It cuts conversational token consumption by up to 60%, allowing extended development and debugging sessions without hitting context limits.

---

## When to Use

- When working through long, repetitive debugging cycles.
- When running multiple exploratory queries or trace analyses.
- Whenever you prefer direct, unembellished answers rather than introductory and concluding politeness phrases.

## How to Trigger

Type in the chat:
- `caveman mode` or `/caveman`
- Specify an intensity if desired: `/caveman lite` or `/caveman ultra`
- To deactivate: `normal mode` or `disable caveman`

---

## Invariants & Guardrails

Even in Caveman Mode, the AI strictly preserves:
1. **Verbatim Code & Errors**: Error messages, stack traces, file paths, and code snippets are never shortened or degraded.
2. **Clean Text Policy**: No decorative emojis or symbols are used.
3. **Repository Artifact Quality**: Written repository files (`docs/`, commit messages, PRs, code files) are always authored in standard formal technical English.
4. **Safety Overrides**: If a command is destructive or involves critical security risks, the AI automatically expands into full, clear sentences before proceeding.
