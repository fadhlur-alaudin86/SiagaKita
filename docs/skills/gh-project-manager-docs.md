# GitHub Project Manager — SiagaKita Developer Guide

This guide details how to manage GitHub Issues, milestones, sprint planning, and progress tracking for SiagaKita.

---

## Issue Conventions

### Title Format
```
F-<number>: <short description>
```
Example: `F-014: Volunteer Dispatch from Console to Nearest Responders`

### Body Template
```markdown
## Description
[Brief summary of feature or fix]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Affected Components
- Backend: [endpoint/domain]
- Mobile: [screen/widget]
- Desktop: [screen/widget]
- DB: [table/migration]
```

### Mandatory Labels (At least 3 per issue)

| Category | Label Name | Usage |
|----------|------------|-------|
| **Type** | `type: feature` | New features |
| | `type: fix` | Bug fixes |
| | `type: chore` | Maintenance |
| | `type: docs` | Documentation |
| **Component** | `component: backend` | Go Fiber backend |
| | `component: mobile` | Flutter mobile app |
| | `component: desktop` | Flutter desktop console |
| | `component: infra` | Docker & infrastructure |
| **Priority** | `priority: P0` | Urgent / critical |
| | `priority: P1` | High priority |
| | `priority: P2` | Normal priority |
| **Status** | `status: in-progress` | Work in progress |
| | `status: in-review` | PR submitted |
| | `status: ready` | Approved, ready to merge |

---

## Issue Lifecycle

```
[Open] ──► [status: in-progress] ──► [status: in-review] ──► [status: ready] ──► [Closed]
```

**Every status transition MUST be accompanied by an explanatory comment.**
