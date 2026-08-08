# gh CLI Command Reference — SiagaKita

Comprehensive reference for `gh` CLI commands for issue management and progress tracking in SiagaKita.
Sub-file of [SKILL.md](SKILL.md).

## Quick Reference

| Intent | Command |
|--------|---------|
| List all open issues | `gh issue list --repo SuperBypassUdinnn/SIAGAKITA` |
| List my issues | `gh issue list --repo SuperBypassUdinnn/SIAGAKITA --assignee "@me"` |
| Create new issue | `gh issue create --repo SuperBypassUdinnn/SIAGAKITA --title "..."` |
| Edit issue labels | `gh issue edit <N> --repo SuperBypassUdinnn/SIAGAKITA --add-label "..."` |
| Add comment | `gh issue comment <N> --repo SuperBypassUdinnn/SIAGAKITA --body "..."` |
| Close issue | `gh issue close <N> --repo SuperBypassUdinnn/SIAGAKITA --reason completed` |
| Assign issue | `gh issue edit <N> --repo SuperBypassUdinnn/SIAGAKITA --add-assignee "<user>"` |
| List milestones | `gh api repos/SuperBypassUdinnn/SIAGAKITA/milestones` |
| Create milestone | `gh api repos/SuperBypassUdinnn/SIAGAKITA/milestones --method POST -f title="..."` |

## Status Transition Labels

```
[Open] ─┬─► [status: in-progress] ─► [status: in-review] ─► [status: ready] ─► [Closed]
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
