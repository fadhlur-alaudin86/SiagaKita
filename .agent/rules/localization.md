# Localization Rules & Invariants — SiagaKita

This document defines the architectural rules and coding standards for localization (i18n / l10n) across all SiagaKita components: `backend-go`, `mobile-flutter`, and `windows_console_flutter`.

---

## Invariant 1 — Zero Hardcoded Strings in Client UI

All user-visible strings displayed in Flutter applications (`mobile-flutter` and `windows_console_flutter`) MUST NOT be hardcoded without localization support.

1. **Extension Usage**:
   - In UI widgets with access to `BuildContext`:
     ```dart
     Text('Batal'.tr(context))
     ```
   - In non-widget contexts (services, background handlers):
     ```dart
     AppLocalization.translate('Batal')
     ```
2. **Dictionary Parity & Bi-directional Hygiene**:
   - Whenever a new user-facing string is introduced, entries for BOTH Indonesian (`id`) and English (`en`) must be registered in:
     - `mobile-flutter/lib/core/localization/app_localization.dart`
     - `windows_console_flutter/lib/core/localization/app_localization.dart`
   - When user-facing text is deleted, refactored, or renamed, the corresponding entries MUST be deleted or renamed in `app_localization.dart` simultaneously.
3. **Dynamic Template Strings**:
   - Use dynamic regex pattern matchers in `AppLocalization` or string interpolation with localized fragments rather than concatenating untranslated sentences.

---

## Invariant 2 — Client-to-Backend Language Synchronization

Clients MUST inform the backend of the user's active language preference on every network interaction.

1. **HTTP Requests**:
   - Every outbound HTTP call (via `Dio`, `http.Client`, or centralized API helper) MUST include the `Accept-Language` header:
     ```dart
     headers: {
       'Accept-Language': AppLocalization.currentLocaleCode,
     }
     ```
   - In `Dio` interceptors, dynamically inject `'Accept-Language': AppLocalization.currentLocaleCode`.
2. **WebSocket Realtime Connections**:
   - Append `?lang=<locale>` query parameter to the WebSocket connection URL:
     ```dart
     final wsUrl = '$rawWsUrl?token=$token&lang=${AppLocalization.currentLocaleCode}';
     ```
3. **Persistence**:
   - Language selection must persist across app restarts using secure or shared local storage (`FlutterSecureStorage` or `SharedPreferences`) and synchronize `AppLocalization.currentLocale` on initialization before rendering the initial view.

---

## Invariant 3 — Transparent Backend Localization Interception

The backend MUST serve responses in the client's requested language based on `Accept-Language` or WebSocket connection parameters.

1. **Context Locale Extraction**:
   - Middleware extracts language via `i18n.GetLocale(c)` and stores it in `c.Locals("locale")`.
   - Supported locales: `id` (default fallback) and `en`.
2. **Response Utility Interception**:
   - All controller responses must route through `utils.ErrorResponse` and `utils.SuccessResponse` / `utils.SuccessResponseWithMsg`.
   - `utils.ErrorResponse` automatically translates the error message via:
     ```go
     translatedMsg := i18n.Translate(locale, message, args...)
     ```
3. **Machine-Readable Codes**:
   - Backend error responses should provide structured, static error codes (e.g., `ERR_AUTH_INVALID_CREDENTIALS`, `ERR_INCIDENT_ALREADY_ACCEPTED`) alongside human-readable translated messages to decouple UI logic from display text.
4. **CORS Configuration**:
   - `Accept-Language` MUST always be included in CORS `AllowHeaders` in Fiber configuration (`cmd/api/main.go`).

---

## Invariant 4 — Bilingual Automated Testing & CI Verification

Localization behavior must be verified continuously through tests.

1. **Backend Unit Tests**:
   - New domains and endpoints returning user messages must include test cases asserting both Indonesian (`Accept-Language: id` or empty) and English (`Accept-Language: en`) responses.
   - Run `go test ./internal/i18n/...` to verify dictionary completeness.
2. **Client Static Analysis**:
   - Run `flutter analyze` across `mobile-flutter` and `windows_console_flutter` to ensure zero syntax or typing errors following localization additions.

---

## Invariant 5 — Dictionary Pruning & Dead Translation Elimination

Localization dictionaries MUST NOT accumulate orphaned or dead keys.

1. **Simultaneous Pruning on Refactor/Deletion**:
   - When removing UI widgets, screens, mock prototypes, or error messages, developers and AI workers MUST search for and remove the obsolete dictionary entries from `mobile-flutter/lib/core/localization/app_localization.dart` and `windows_console_flutter/lib/core/localization/app_localization.dart`.
2. **Prohibition of Orphaned Translations**:
   - Do NOT retain prototype strings, platform-mismatched strings (e.g. desktop admin console text in the mobile dictionary), or duplicate keys with inconsistent whitespace/newlines.
3. **Audit Verification**:
   - Every major feature PR or refactor involving localization should verify that all registered keys in `_idToEn` are actively consumed by at least one `.tr(context)` or `AppLocalization.translate(...)` call.

