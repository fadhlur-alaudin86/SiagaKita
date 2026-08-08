# Agent Skills — SiagaKita Developer Guide

This directory contains human-readable documentation explaining the AI agent skills available in the SiagaKita project. These skills help both human developers and AI agents collaborate smoothly.

> **Note:** Technical agent instruction files reside in `.agent/skills/`. The files in `docs/skills/` are formatted **for human developers**.

---

## Skill Directory

| Skill | Use Case | Documentation |
|-------|----------|---------------|
| **devops-workflow** | CI/CD, branching, deployments, rollbacks, release strategy | [devops-workflow-docs.md](devops-workflow-docs.md) |
| **gh-project-manager** | GitHub issues, sprint planning, backlogs, progress reporting | [gh-project-manager-docs.md](gh-project-manager-docs.md) |
| **feature-dev-workflow** | Contract-first feature implementation (Go + Flutter) | [feature-dev-workflow-docs.md](feature-dev-workflow-docs.md) |

---

## How to Activate Skills in Chat

In your AI chat session, initiate a skill by typing:

```
Skill: <skill-name>
[Task description]
```

### Examples

```
Skill: feature-dev-workflow
Build volunteer dispatch feature from desktop console to nearest responders.
```

```
Skill: gh-project-manager
/sprint-report
```

```
Skill: devops-workflow
Update workflow ci-dev.yml to include go test step.
```

---

## Conventional Commits (MANDATORY for all developers)

All developers MUST adhere to the Conventional Commits format to support automated GitHub Release notes generation:

```
<type>(<scope>): <short description>
```

Examples:
- `feat(incident): add volunteer dispatch endpoint`
- `fix(mobile): resolve SOS cooldown bypass on restart`
- `chore: update go dependencies`
- `ci: add flutter analyze to ci-dev.yml`

See [devops-workflow-docs.md](devops-workflow-docs.md#conventional-commits) for full specifications.

---

## Branch Naming Conventions

```
feature/F-XXX-feature-name    ← New features
fix/F-XXX-bug-name            ← Bug fixes
feature/F-XXX-name/sub-be     ← Backend sub-branch
feature/F-XXX-name/sub-mobile ← Mobile sub-branch
```

> `F-XXX` represents the GitHub Issue number (e.g., `feature/F-014-dispatch-volunteer`).
