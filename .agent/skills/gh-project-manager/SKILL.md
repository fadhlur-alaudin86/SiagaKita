---
name: gh-project-manager
description: Manage GitHub Issues, milestones, labels, sprint planning, and progress tracking for SiagaKita via gh CLI. Use this skill when asked to organize project backlogs, sprints, or issue statuses.
---

## Trigger Keywords

`backlog`, `issue`, `sprint`, `task`, `milestone`, `progress report`, `assign`, `standup`, `retro`, `project board`, `status update`, `create issue`, `close issue`, `check progress`

## Stack Reference

Read [stacks.md](../stacks.md) for configuration details (repo name, label conventions, milestone naming).

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`)
- `jq` installed
- Access to repo `SuperBypassUdinnn/SIAGAKITA`

## Configuration

```
REPO          = SuperBypassUdinnn/SIAGAKITA
STATUSES      = [Backlog, In Progress, In Review, Done]
PRIORITIES    = [P0, P1, P2]
LABELS_STATUS = status: in-progress, status: in-review, status: ready
LABELS_TYPE   = type: feature, type: fix, type: chore, type: docs, type: refactor, type: security, type: gamification, type: kyc, type: telemetry, type: dispatch
LABELS_COMP   = component: backend, component: mobile, component: desktop, component: infra
LABELS_PRIO   = priority: P0, priority: P1, priority: P2
```

## GitHub Issues Best Practices

Every issue must have:
- **Title**: `F-XXX: [Short Description]` (e.g., `F-014: Volunteer Dispatch from Console`)
- **Body**: Description, acceptance criteria, affected components
- **Labels**: At least 1 type label + 1 component label + 1 priority label
- **Milestone**: Assigned sprint milestone
- **Assignee**: Assigned developer

## Milestone Naming Convention

```
Format: Sprint X (vMAJOR.MINOR.PATCH) — DD Month YYYY
Example: Sprint 25 (v1.0.25) — 15 August 2026
```

## Command Reference

### List Issues
```bash
# All open issues
gh issue list --repo SuperBypassUdinnn/SIAGAKITA

# Filter by label
gh issue list --repo SuperBypassUdinnn/SIAGAKITA --label "status: in-progress"

# Filter by milestone
gh issue list --repo SuperBypassUdinnn/SIAGAKITA --milestone "Sprint 25 (v1.0.25)"

# Filter by assignee
gh issue list --repo SuperBypassUdinnn/SIAGAKITA --assignee "@me"

# JSON output for scripting
gh issue list --repo SuperBypassUdinnn/SIAGAKITA --json number,title,assignees,labels,milestone,state
```

### Create Issue
```bash
gh issue create \
  --repo SuperBypassUdinnn/SIAGAKITA \
  --title "F-014: Volunteer Dispatch from Console" \
  --body "**Description:**\n...\n\n**Acceptance Criteria:**\n- [ ] ..." \
  --label "type: feature" \
  --label "component: desktop" \
  --label "component: backend" \
  --label "priority: P1" \
  --milestone "Sprint 25 (v1.0.25)" \
  --assignee "username"
```

### Update Issue Labels (Status Transitions)
```bash
# Work started: add status: in-progress (manual when starting work)
gh issue edit <number> --repo SuperBypassUdinnn/SIAGAKITA \
  --add-label "status: in-progress"

# Note: PR created (in-review), PR approved (ready), and PR merged (close)
# are automatically handled by issue-status-labeler.yml GitHub Actions workflow.
```

### Add Comment (mandatory on status change)
```bash
gh issue comment <number> \
  --repo SuperBypassUdinnn/SIAGAKITA \
  --body "🚀 Starting implementation of F-014. Branch: feature/F-014-dispatch-volunteer"
```

### Assign Issue
```bash
gh issue edit <number> --repo SuperBypassUdinnn/SIAGAKITA \
  --add-assignee "username"
```

### List & Create Milestones
```bash
# List milestones
gh api repos/SuperBypassUdinnn/SIAGAKITA/milestones

# Create milestone
gh api repos/SuperBypassUdinnn/SIAGAKITA/milestones \
  --method POST \
  -f title="Sprint 25 (v1.0.25) — 15 August 2026" \
  -f due_on="2026-08-15T07:00:00Z"
```

### Progress Report
```bash
# Count issues per status label
for label in "status: in-progress" "status: in-review" "status: ready"; do
  count=$(gh issue list --repo SuperBypassUdinnn/SIAGAKITA --label "$label" --json number | jq '. | length')
  echo "$label: $count"
done

# Completed (closed) issues this month
gh issue list --repo SuperBypassUdinnn/SIAGAKITA \
  --state closed \
  --json number,title,closedAt,assignees \
  | jq -r '.[] | "\(.number) \(.title) — closed: \(.closedAt | split("T")[0]). Assignee: \(.assignees[0].login // "unassigned")"'
```

## Workflow Recipes

### `/list-backlog`
List all open issues with status and priority:
```bash
gh issue list --repo SuperBypassUdinnn/SIAGAKITA \
  --json number,title,labels,assignees,milestone \
  | jq -r '.[] | "#\(.number) \(.title) | \(.labels | map(.name) | join(", ")) | \(.assignees[0].login // "unassigned")"'
```

### `/my-tasks`
List tasks assigned to active user:
```bash
gh issue list --repo SuperBypassUdinnn/SIAGAKITA \
  --assignee "@me" \
  --json number,title,labels
```

### `/create-issue <title> [--body <desc>] [--priority P0/P1/P2] [--component <comp>]`
1. Determine next F-XXX number from issue list
2. `gh issue create` with matching labels and milestone
3. Add comment: "Issue F-XXX created, ready for sprint planning"

### `/close-task <number>`
1. `gh issue close <number>`
2. Add comment: brief summary of what was accomplished

### `/sprint-report`
Progress summary per developer:
```bash
gh issue list --repo SuperBypassUdinnn/SIAGAKITA \
  --json number,title,labels,assignees,state \
  | jq -r 'group_by(.assignees[0].login // "unassigned") | .[] | "\(.[0].assignees[0].login // "unassigned"): \(length) issues"'
```

### `/sprint-retro`
List all closed issues with dates:
```bash
gh issue list --repo SuperBypassUdinnn/SIAGAKITA \
  --state closed \
  --json number,title,labels,assignees,closedAt
```

## Agent Rules

1. **Read stacks.md first** — before creating or modifying anything.
2. **Check for duplicates before creating** — always run `gh issue list` to verify a similar issue doesn't already exist.
3. **Mandatory comments** — every status change (label change) must be accompanied by an explanatory comment detailing reason/progress.
4. **Milestone assignment** — every new issue must be assigned to an appropriate active milestone.
5. **Do not close issue without merge** — issues are only closed after the PR merges to `dev`.
6. **F-XXX numbering** — use GitHub issue number as ID. Title format is always `F-<number>: <description>`.
7. **Mandatory labels** — every issue must have at least 1 type label + 1 component label + 1 priority label.
