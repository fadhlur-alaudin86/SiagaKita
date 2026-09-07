# gh CLI Command Reference — SiagaKita

Comprehensive reference for `gh` CLI commands for issue management and progress tracking in SiagaKita.
Sub-file of [SKILL.md](SKILL.md).

## Quick Reference

| Intent | Command |
|--------|---------|
| List all open issues | `gh issue list --repo fadhlur-alaudin86/SiagaKita` |
| List my issues | `gh issue list --repo fadhlur-alaudin86/SiagaKita --assignee "@me"` |
| Create new issue | `gh issue create --repo fadhlur-alaudin86/SiagaKita --title "..."` |
| Edit issue labels | `gh issue edit <N> --repo fadhlur-alaudin86/SiagaKita --add-label "..."` |
| Add comment | `gh issue comment <N> --repo fadhlur-alaudin86/SiagaKita --body "..."` |
| Close issue | `gh issue close <N> --repo fadhlur-alaudin86/SiagaKita --reason completed` |
| Assign issue | `gh issue edit <N> --repo fadhlur-alaudin86/SiagaKita --add-assignee "@me"` |
| List milestones | `gh api repos/fadhlur-alaudin86/SiagaKita/milestones` |
| Create milestone | `gh api repos/fadhlur-alaudin86/SiagaKita/milestones --method POST -f title="..."` |

## Status Transition Labels

```
[Open] ─┬─► [status: in-progress] ─► [status: in-review] ─► [status: ready] ─► [status: done] (Closed)
```

## Issue Body Template

```markdown
## Description

[Short description of feature or bug]

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Affected Components

- Backend: [endpoint/handler]
- Mobile: [screen/widget]
- Desktop: [screen/widget]
- DB: [table/migration]

## Conventional Commit Reference

`feat(scope): description` or `fix(scope): description`
```
