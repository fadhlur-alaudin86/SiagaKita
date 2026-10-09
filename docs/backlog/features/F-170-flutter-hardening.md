# F-170: Flutter Hardening (Storage, Timeouts, Silent Failures)

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-170 |
| Title | Flutter hardening (storage, timeouts, silent failures) |
| Requestor | audit Oct 2026 |
| Date Created | 2026-10-09 |
| GitHub Issue | #170 |
| Parent Plan | #167 audit program |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| Token | background_service.dart:223 | prefs read of never-written key; SOS timer already used SessionService |
| Timeouts | api_services.dart choke points | _requestWithRetry + _authedMultipart unbounded |
| Catches | 15 empty service blocks + UI sweep | 30+ UI catches already give feedback; 5 console empties fixed |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| 0 | Branch | Done | 2026-10-09 | feature/F-170-flutter-hardening, issue in-progress |
| 5 | Flutter Implementation | Done | 2026-10-09 | secure token, timeouts, logged catches |
| 6 | Tests | Done | 2026-10-09 | mobile 20 pass, console 27 pass, analyzes clean |
| 7 | CI + Review | Pending | | needs PR |
| 8 | Close Log | Pending | | |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-09 | Reuse SessionService.getToken in isolate | secure-first plus legacy migration plus null-safe already |
| 2026-10-09 | 15s standard, 60s upload timeouts | uploads need headroom; single choke points |
| 2026-10-09 | Log-only for retry loops, no behavior change | background semantics preserved |
| 2026-10-09 | debugPrint needs foundation import | dart:ui does not export it; caught by analyzer |
