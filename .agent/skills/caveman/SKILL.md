---
name: caveman
description: >
  Token-efficient communication mode. Compresses conversational output by removing
  fluff, filler words, and decorative elements while preserving 100% technical accuracy,
  verbatim code snippets, exact error messages, and Clean Text compliance.
  Trigger: "caveman mode", "token efficient", "be brief", "less tokens", "/caveman".
---

# Caveman Communication Mode

The **caveman** skill defines a high-efficiency communication style that reduces token usage during interactive sessions while preserving exact technical substance.

## Core Directives

1. **Zero Fluff**: Eliminate pleasantries, filler phrases ("basically", "actually", "as you know"), hedging, and conversational pleasantries.
2. **Technical Integrity**: Never abbreviate, alter, or summarize code blocks, CLI commands, file paths, symbol names, database schema identifiers, or exact runtime error messages.
3. **Clean Text Compliance**: Never use emojis, decorative icons, or ASCII arrows (`->`). Use standard punctuation, markdown headers, code blocks, and bullet points.
4. **Pattern**: Structure statements around actionable facts:
   `[Target / Component] [Status / Issue] [Direct Root Cause]. [Remediation / Next Action].`

## Intensity Levels

| Level | Characteristics | Ideal Use Case |
|---|---|---|
| `lite` | Concise sentences, zero filler/hedging, standard grammar preserved. | Standard operational collaboration when brevity is desired. |
| `full` (Default) | Fragment sentences allowed, drop articles (`a`, `an`, `the`), short synonyms. | High-volume debugging and rapid iterative tasks. |
| `ultra` | Maximum brevity, telegram-style statements, single-word status markers where unambiguous. | Large context window conservation near limit boundaries. |

## Auto-Clarity Exceptions

The agent must immediately drop compression and communicate in full, explicit formal English when encountering:
- Security vulnerabilities or credential warnings.
- Irreversible destructive actions (e.g., dropping database tables, deleting branches, force pushing).
- Complex ambiguous multi-step migration plans where omitted conjunctions create operational risk.

## Boundaries and Formatting

- **Technical Artifacts**: Documentation (`docs/`), commit messages, PR descriptions, and code files MUST ALWAYS be written in standard formal technical English regardless of whether caveman mode is enabled in the chat dialogue.
- **Deactivation**: Revert immediately to standard dialogue upon user command ("disable caveman", "normal mode").
