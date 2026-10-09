# F-171: i18n Sweep + WS Lang Negotiation

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-171 |
| Title | i18n sweep plus WS lang negotiation |
| Requestor | audit Oct 2026 |
| Date Created | 2026-10-09 |
| GitHub Issue | #171 |
| Parent Plan | #167 audit program |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| WS pushes | ws/handler.go 4 sites | user-visible Indonesian strings, lang param dead |
| Headers | incident_service 10 sites, background 3, user multipart | raw auth maps |
| Hardcoded | mobile 5 sites + typeLabel/timeAgo, console 6 pages | dict keys added both locales |
| Orphans | check script | 0 orphans, nothing to prune |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| 0 | Branch | Done | 2026-10-09 | feature/F-171-i18n-sweep, issue in-progress |
| 4/5 | Implementation | Done | 2026-10-09 | WS locale, headers, strings, dict |
| 6 | Tests | Done | 2026-10-09 | hub, bilingual handler, both localization suites |
| 7 | CI + Review | Pending | | needs PR |
| 8 | Close Log | Pending | | |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-09 | Per-connection locale, not per-message renegotiation | pushes are single-recipient; handshake param suffices |
| 2026-10-09 | Export NormalizeLocale/ParseAcceptLanguage | WS handshake is net/http, outside fiber |
| 2026-10-09 | Isolate locale from persisted language_code | AppLocalization statics unavailable in isolate |
| 2026-10-09 | Prefix-key pattern for interpolated strings | dictionary is exact-match; precedent exists |

## Outputs Checklist

| # | Artifact | Status |
|---|----------|:------:|
| 1 | Feature log | [x] |
| 2 | WS lang end-to-end | [x] |
| 3 | Headers everywhere | [x] |
| 4 | Hardcoded strings fixed | [x] |
| 5 | Bilingual tests | [x] |
| 6 | Pull request to dev | [ ] |
