# F-172: Schema, Mapping Docs, and Test Parity

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-172 |
| Title | Schema, mapping docs, and test parity |
| Requestor | audit Oct 2026 |
| Date Created | 2026-10-09 |
| GitHub Issue | #172 |
| Parent Plan | #167 audit program |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| 008 down | trigger_method width/null/default wrong | true inverse is varchar(20) NOT NULL DEFAULT timeout |
| Schema doc | triple version claim, ENUM blocks | v13 reality is VARCHAR+CHECK per 021 |
| Mapping | 6 gone paths, stale endpoints, dead award row | all 22 paths verified present after fix |
| Tests | no 4-case handler shape | CancelSOS table test added with DB cleanup |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| 0 | Branch | Done | 2026-10-09 | feature/F-172-schema-test-parity, issue in-progress |
| 3 | DB Migration docs | Done | 2026-10-09 | 008 inverse fixed (history-only, rollback path) |
| 4/5 | Docs | Done | 2026-10-09 | schema single claim, mapping refresh, varchar exception |
| 6 | Tests | Done | 2026-10-09 | CancelSOS table test green with live DB, skips without |
| 7 | CI + Review | Pending | | needs PR |
| 8 | Close Log | Pending | | |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-09 | Keep 017, amend rule instead of reverting | applied history; destructive revert needs own migration |
| 2026-10-09 | Keep v13 label for 022/023 | additive changes, no generation bump |
| 2026-10-09 | Delete award row, not stub it | no endpoint, handler, or UI exists |
| 2026-10-09 | Tests against dev DB with cleanup | mirrors existing getTestDB skip pattern |
