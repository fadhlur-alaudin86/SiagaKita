# F-168: Contract Error Codes End-to-End (Rule B)

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-168 |
| Title | Contract error codes end-to-end (Rule B) |
| Requestor | audit Oct 2026 |
| Date Created | 2026-10-09 |
| GitHub Issue | #168 |
| Parent Plan | N/A (audit program #167) |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| Go envelope | internal/utils/response.go | APIResponse lacks code field; 175 ErrorResponse sites |
| Backend paths | user/agency register 409, KYC duplicate | need semantic codes |
| Mobile parse | mobile-flutter api_client.dart | branches on status/message |
| Desktop parse | windows_console_flutter api_services.dart | body[data][message] chains |
| String branches | home_screen.dart 409, kyc_screen.dart sudah-terdaftar | replace with code checks |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| -3 | Backlog Overview | Done | 2026-10-09 | parent #167 plus children created |
| -2 | Discovery | In Progress | | envelope plus client parse mapped |
| -1 | Resolve backlog | Done | | issue #168 in-progress, branch created |
| 0 | Branch | Done | | feature/F-168-contract-error-codes |
| 1 | Read mapping | Done | 2026-10-09 | envelope, client parse, 409/KYC paths mapped |
| 2 | API Contract | Done | 2026-10-09 | code field in schemas.yaml ErrorResponse |
| 4 | Backend Implementation | Done | 2026-10-09 | envelope defaults + ERR_EMAIL_TAKEN + ERR_NIK_TAKEN |
| 5 | Flutter Implementation | Done | 2026-10-09 | mobile codes + console record codes |
| 6 | Tests | Done | 2026-10-09 | envelope table tests + sentinel chain + handler 400-code |
| 7 | CI + Review | Done | 2026-10-09 | fast gate 7/7, analyzes clean, needs full gate + PR |
| 8 | Close Log | Pending | | |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-09 | Keep ErrorResponse signature, add ErrorResponseWithCode | 175 sites migrate incrementally; no flag-day |
| 2026-10-09 | Semantic codes only on auth/register/KYC/SOS paths first | per-site judgment needed; remainder get explicit generic code later |

## Outputs Checklist

| # | Artifact | Status |
|---|----------|:------:|
| 1 | Feature log | [x] |
| 2 | Code field in APIResponse | [ ] |
| 3 | Client code switching (mobile + console) | [ ] |
| 4 | String-branch removal (409, sudah-terdaftar) | [ ] |
| 5 | Code assertion tests | [ ] |
| 6 | Pull request to dev (Squash Merge) | [ ] |
