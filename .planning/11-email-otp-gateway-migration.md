# Plan 11: Email OTP Gateway Migration to Transactional Provider (Resend)

## 1. Overview & Problem Statement
- **Target Issue**: Issue [#45](https://github.com/fadhlur-alaudin86/SiagaKita/issues/45)
- **Priority**: P2 (Normal)
- **Status**: Ready for Backlog Execution
- **Problem**:
  1. The existing email OTP gateway (`gmail_api_gateway.go`) relies on Google Cloud OAuth2 user refresh tokens. Because the Google Cloud OAuth app is in "Testing" mode, refresh tokens expire every 7 days (`invalid_grant`), causing authentication and password reset OTP deliveries to suddenly fail.
  2. Free Gmail accounts have strict quotas (500 emails/day) and lack dedicated IP reputation, leading to OTP messages being routed to spam.
  3. VPS hosters frequently block outbound SMTP ports (25, 465, 587) by default.
- **Goal**:
  - Migrate the backend email gateway from Gmail OAuth2 to a modern Transactional Email Service Provider (ESP) operating via HTTPS REST API (port 443).
  - Implement Resend (or Brevo fallback) using direct API Key authorization, eliminating OAuth2 token expiration and port blocking.

---

## 2. Technical Scope & Specifications

### 2.1 Provider Selection & Domain Verification
- **Recommended Provider**: Resend (`https://resend.com`).
  - Free tier offers 3,000 emails/month (100 emails/day), ample for staging and early production.
  - Zero token expiration: authenticated via persistent API key (`re_...`).
  - Supports custom domain DKIM/SPF/DMARC alignment (`siagakita.com` / `mail.siagakita.com`).
  - Fallback option: Brevo (Sendinblue) or Amazon SES.

### 2.2 Backend Gateway Implementation
- **Interface**: `otp.EmailGateway` in `backend-go/internal/domain/otp/`:
  ```go
  type EmailGateway interface {
      SendEmail(ctx context.Context, toEmail, subject, bodyHTML string) error
  }
  ```
- **New Gateway**: `resend_gateway.go`:
  - Issues HTTPS `POST https://api.resend.com/emails` with header `Authorization: Bearer <RESEND_API_KEY>`.
  - JSON payload: `{ "from": "SiagaKita <noreply@siagakita.com>", "to": [toEmail], "subject": subject, "html": bodyHTML }`.
  - Configurable request timeout: 5 seconds.
- **Configuration**:
  - Update `internal/config/config.go`:
    - `EmailProvider`: `"resend"` (or `"gmail"` for local fallback).
    - `EmailAPIKey`: string.
    - `EmailFrom`: e.g. `"noreply@siagakita.com"`.
  - Deprecate/clean old OAuth variables: `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN`.

---

## 3. Tasks & Implementation Checklist

- [ ] Implement `ResendGateway` in `backend-go/internal/domain/otp/resend_gateway.go`.
- [ ] Add unit tests with mock HTTP server testing successful delivery and error handling.
- [ ] Update `config.Config` and `.env.example` templates with `EMAIL_PROVIDER` and `EMAIL_API_KEY`.
- [ ] Wire `ResendGateway` in `cmd/api/main.go` and deprecate `gmail_api_gateway.go`.
- [ ] Test end-to-end OTP dispatch for citizen registration, login, and password reset.

---

## 4. Affected Components & Files

- `backend-go/internal/domain/otp/resend_gateway.go` (new)
- `backend-go/internal/domain/otp/resend_gateway_test.go` (new)
- `backend-go/internal/config/config.go`
- `backend-go/cmd/api/main.go`
- `infrastructure/.env.example`
- `docs/backlog/features/F-045-email-otp-resend.md` (new)

---

## 5. Verification & Acceptance Criteria

1. **Reliability**:
   - OTP emails dispatch over HTTPS port 443 without OAuth2 token expiration or `invalid_grant` errors.
2. **Speed**:
   - Email delivery initiated in < 1 second; received by user inbox in < 5 seconds.
3. **Compatibility**:
   - `otp.Service` requires zero modifications; interface contract remains intact.
