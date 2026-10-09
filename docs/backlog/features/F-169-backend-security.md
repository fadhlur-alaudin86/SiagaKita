# F-169: Backend Security Hardening Batch

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-169 |
| Title | Backend security hardening batch |
| Requestor | audit Oct 2026 |
| Date Created | 2026-10-09 |
| GitHub Issue | #169 |
| Parent Plan | #167 audit program |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| SQL concat | incident/repository.go:267 | WHERE built via += with ? placeholder |
| HTTP no timeout | otp/gateway.go:62, gmail_api_gateway.go:101 | http.DefaultClient.Do unbounded |
| Background ctx | telemetry/handler.go:52,88, incident/service.go:633, repository.go:454,749 | breaks cancellation |
| WS timeout | ws/server.go:31-37 | lacks WriteTimeout |
| CORS | cmd/api/main.go:149 | Accept-Language missing |
| Redis fire-forget | user/service, otp/service, telemetry, incident | auth paths blind |
| Redaction | ~40 err.Error passthroughs | relocated from F-168 |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| 0 | Branch | Done | 2026-10-09 | feature/F-169-backend-security, issue in-progress |
| 4 | Backend Implementation | Done | 2026-10-09 | SQL allowlist, OTP timeout, ctx, WS+CORS, Redis logs, repo route, redaction |
| 6 | Tests | Done | 2026-10-09 | touched packages pass, govulncheck 0, vet clean |
| 7 | CI + Review | Pending | | needs PR + full gate |
| 8 | Close Log | Pending | | |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-09 | Shared 5s/10s HTTP client helper for OTP gateways | single timeout policy, testable |
| 2026-10-09 | Redaction via message allowlist at handler edge | codes already machine-readable since F-168 |
