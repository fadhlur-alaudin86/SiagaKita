---
name: grill-me
description: A relentless architectural interview protocol to sharpen plans, technical designs, state lifecycles, and database schemas before implementation. Uses a Design Tree Frontier approach with explicit recommendations.
---

# Grill-Me Skill — SiagaKita

The `grill-me` skill conducts an exhaustive, relentless interview to pressure-test plans, uncover hidden assumptions, evaluate trade-offs, and resolve ambiguous requirements before any production code or schema migration is authored.

---

## Core Principles

1. **Fact-Finding First (Autonomous Discovery)**:
   - Never ask the user questions that can be answered by exploring the workspace.
   - Before formulating questions, inspect relevant routes in `backend-go`, screens in `mobile-flutter`/`windows_console_flutter`, database migrations in `backend-go/migrations/`, and living schemas in `docs/DATABASE_SCHEMA.md`.
   - The user decides *intent and trade-offs*; the agent uncovers *facts and constraints*.

2. **The Design Tree Frontier**:
   - Model the system design as a tree where decisions branch into dependent sub-decisions.
   - The **frontier** consists of decisions whose prerequisites are settled and can be asked immediately without guessing.
   - Work through the tree in sequential rounds. Resolving questions in round N pushes the frontier outward and unlocks dependent questions in round N+1.

3. **Explicit Recommendations**:
   - Every question presented to the user must provide concrete multiple-choice options.
   - The agent MUST mark the recommended option with `(Recommended)` and provide a brief technical rationale grounded in project invariants (e.g., KISS, multi-client parity, clean text, performance).

4. **Terminal Condition**:
   - The interview ends when the Design Tree Frontier is empty (every branch explored, zero unstated assumptions remaining) or when the user declares the plan final and commands execution.

---

## Interview Execution Protocol

### Step 1 — Codebase Reconnaissance
- Inspect existing implementations and documentation.
- Identify the target domain, affected API contracts, database tables, Flutter screens, and authentication requirements.

### Step 2 — Frontier Questioning Rounds
Present each round using the structured questioning format:
- Group related questions or ask sequentially.
- Prefix recommended options with `(Recommended)`.
- Use the `ask_question` tool when running interactively in agentic pairing mode.

Format per round:
```text
Question: [Clear question title]
- (Recommended) [Recommended option with technical rationale]
- [Alternative option A]
- [Alternative option B]
```

### Step 3 — Final Architecture Specification Artifact
Upon conclusion of the interview, the agent must document all resolved architectural decisions into:
`docs/backlog/features/F-XXX-spec.md` (or the task's corresponding feature log).

The specification artifact must include:
- **Scope & Goals**: Core problem, boundary, non-goals.
- **Architectural Decisions**: Summary of resolved branches from the interview.
- **API & Schema Contracts**: Impacted endpoints and database migrations.
- **Client Parity**: Concrete mapping for both Flutter Mobile and Flutter Windows Console.
- **Verification Criteria**: Specific unit and regression tests required before merge.
