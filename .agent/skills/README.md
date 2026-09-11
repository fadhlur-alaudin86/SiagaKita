# Agent Skills Catalog — SiagaKita

This directory contains all **agent skills** available for the SiagaKita project. Each skill has its own subdirectory containing instructions for AI agents.

---

## Directory Structure

```
.agent/skills/
├── README.md                           ← You are here (catalog + activation guide)
├── stacks.md                           ← Stack config (repo, VPS, board, priorities)
├── devops-workflow/
│   ├── SKILL.md                         ← Agent instructions: CI/CD, branching, deployment
├── gh-project-manager/
│   ├── SKILL.md                         ← Agent instructions: Issues, sprints, progress
│   └── gh-proj-manager.md               ← Command reference for gh CLI
├── karpathy-guidelines/
│   └── SKILL.md                         ← Behavioral guidelines: Think before coding, surgical edits
├── grill-me/
│   └── SKILL.md                         ← Architectural alignment: Design tree frontier interviews
├── component-mapping/
│   └── SKILL.md                         ← Multi-client parity: Flutter Mobile & Console <-> Go <-> DB
├── cavecrew/
│   └── SKILL.md                         ← Subagent delegation: compact outputs, context conservation
├── caveman/
│   └── SKILL.md                         ← Token-efficient communication: zero fluff, technical substance
└── feature-dev-workflow/
    ├── SKILL.md                         ← Agent instructions: Feature pipeline
    ├── stacks.md                        ← Specific stack config (Go + Flutter)
    ├── backend-standards.md            ← Go coding standards & error wrapping
    ├── flutter-standards.md            ← Flutter/Dart standards & async safety
    ├── postgres-patterns.md            ← PostgreSQL 15 & pgx v5 patterns
    ├── review-standards.md             ← Pre-PR review checklists (Security, DB, Silent-Failure)
    ├── workflow-evolution.md           ← Evolutionary workflow protocol (minor/major updates)
    └── testing.md                      ← Test conventions, Hybrid TDD & sanitization
```

**Agent execution steps when receiving a task:**
1. Read this `README.md` → identify the relevant skill.
2. Read `<skill>/SKILL.md` → understand rules and workflow.
3. Read `stacks.md` → understand stack & project configuration.
4. Run Step -3 (Backlog Overview) if using `feature-dev-workflow` or `gh-project-manager`.

---

## Skill Catalog

| Skill | Trigger Keywords | Directory | Description |
|-------|------------------|-----------|-------------|
| **devops-workflow** | `deploy`, `CI/CD`, `workflow`, `pipeline`, `rollback`, `VPS`, `branch protection` | [`devops-workflow/`](devops-workflow/SKILL.md) | Manage CI/CD, branching strategy, VPS deployments & rollbacks |
| **gh-project-manager** | `backlog`, `issue`, `sprint`, `task`, `milestone`, `progress report`, `assign` | [`gh-project-manager/`](gh-project-manager/SKILL.md) | Manage GitHub Issues, milestones, labels, and sprints via `gh` CLI |
| **feature-dev-workflow** | `new feature`, `feature`, `implementation`, `new endpoint`, `new screen`, `API` | [`feature-dev-workflow/`](feature-dev-workflow/SKILL.md) | Contract-first pipeline for Go + Flutter feature development |
| **karpathy-guidelines** | `karpathy`, `surgical change`, `coding standards`, `clean code`, `simplicity` | [`karpathy-guidelines/`](karpathy-guidelines/SKILL.md) | Behavioral guidelines for surgical, non-speculative, goal-driven coding |
| **grill-me** | `grill-me`, `grill`, `interview`, `architecture review`, `stress test plan` | [`grill-me/`](grill-me/SKILL.md) | Relentless architectural alignment interview via Design Tree Frontier |
| **component-mapping** | `component mapping`, `multi-client parity`, `endpoint mapping`, `screen mapping` | [`component-mapping/`](component-mapping/SKILL.md) | Maps Mobile & Desktop screens to Go Fiber routes, DB tables, and WS events |
| **cavecrew** | `delegate to subagent`, `cavecrew`, `spawn investigator`, `spawn builder`, `spawn reviewer` | [`cavecrew/`](cavecrew/SKILL.md) | Subagent delegation guide with compact outputs to conserve context |
| **caveman** | `caveman mode`, `token efficient`, `be brief`, `less tokens`, `/caveman` | [`caveman/`](caveman/SKILL.md) | Terse communication mode cutting token usage while preserving technical accuracy |


---

> **Human Documentation:** See `docs/skills/README.md` for developer-facing usage guides.
