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
└── feature-dev-workflow/
    ├── SKILL.md                         ← Agent instructions: Feature pipeline
    ├── stacks.md                        ← Specific stack config (Go + Flutter)
    ├── backend-standards.md            ← Go coding standards & error wrapping
    ├── flutter-standards.md            ← Flutter/Dart standards & async safety
    ├── postgres-patterns.md            ← PostgreSQL 15 & pgx v5 patterns
    ├── review-standards.md             ← Pre-PR review checklists (Security, DB, Silent-Failure)
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

---

> **Human Documentation:** See `docs/skills/README.md` for developer-facing usage guides.
