# SiagaKita AI Worker Governance & System Rules

Welcome to the **SiagaKita** repository. This document outlines project-level governance rules, coding invariants, and best practices for AI agents and human contributors working on this multi-stack repository (`backend-go`, `mobile-flutter`, and `windows_console_flutter`).

---

## 1. Localization Governance (MANDATORY)

Full details are documented in [`.agent/rules/localization.md`](.agent/rules/localization.md). Every developer and AI assistant must adhere to these 5 invariants:

1. **Client Zero Hardcoding & Active Dictionary Hygiene**:
   - User-visible text in Flutter must use `.tr(context)` or `AppLocalization.translate(...)`.
   - Never commit hardcoded raw strings for user messages.
   - Maintain dictionary parity between Indonesian (`id`) and English (`en`) in `mobile-flutter/lib/core/localization/app_localization.dart` and `windows_console_flutter/lib/core/localization/app_localization.dart`.
   - **Prune Unused Entries**: When deleting or refactoring UI text, immediately prune orphaned dictionary entries in `app_localization.dart`. Never leave dead, prototype, or duplicate keys in the dictionary.
2. **Dynamic Client Synchronization**:
   - Outbound HTTP requests must automatically send the `Accept-Language` header reflecting active user preference.
   - Real-time WebSocket connections must append `&lang=<locale>` or pass language parameters in headers.
   - Language preferences must persist across app restarts using local storage.
3. **Backend Transparent Interception**:
   - Backend responses must utilize `utils.ErrorResponse` and `utils.SuccessResponseWithMsg` which automatically resolve localized text through `internal/i18n`.
   - Fiber context extracts language preference via `i18n.GetLocale(c)`.
   - CORS configuration must include `Accept-Language` in `AllowHeaders`.
4. **Bilingual Verification**:
   - Backend unit tests must assert both Indonesian and English outputs (`go test ./...`).
   - Flutter static analysis must report zero warnings or errors (`flutter analyze`).
5. **Dictionary Pruning & Dead Translation Elimination**:
   - Localization dictionaries must not retain orphaned, unused, or duplicate entries.
   - All entries in `app_localization.dart` must correspond to active UI or service calls.

---

## 2. Recommended Architectural Governance Rules

### Rule A — Multi-Client API Contract Parity
- **Rationale**: SiagaKita operates both a Flutter Mobile client (for civilians & volunteers) and a Flutter Windows Desktop Console (for agency dispatchers & system admins).
- **Rule**: When adding or updating backend endpoints, DTO models, or WebSocket event payloads, ensure that contract changes are mirrored consistently across both `mobile-flutter` and `windows_console_flutter`. Avoid proprietary API dialects for one client unless explicitly scoped to that platform's role.

### Rule B — Unified Machine-Readable Error Codes
- **Rationale**: Relying solely on error messages causes fragile frontend conditional logic when string phrasing or languages change.
- **Rule**: Every backend error response should return a standardized error code in addition to the localized message:
  ```json
  {
    "code": "ERR_INCIDENT_ALREADY_ACCEPTED",
    "message": "Insiden ini telah ditangani oleh instansi lain"
  }
  ```
  Client apps can switch on `code` for logic/navigation while displaying `message` directly in the UI.

### Rule C — CI / Pre-Commit Localization Linting & Orphan Detection
- **Rationale**: Catching untranslated strings before PR review prevents localization regressions, while detecting orphaned keys prevents dictionary bloat.
- **Rule**: Include an automated check in GitHub Actions (`.github/workflows/ci-dev.yml`) to:
  1. Scan newly added Dart files for raw Indonesian or English text literals inside `Text(...)` or `showSnackBar(...)` that lack `.tr(context)`.
  2. Verify that all dictionary entries in `app_localization.dart` have at least 1 active reference across client source files.

### Rule D — Database Schema Single-Source of Truth
- **Rationale**: Schema drift between SQL migrations and documentation leads to invalid joins and broken services.
- **Rule**: Always review `docs/DATABASE_SCHEMA.md` before authoring new `.sql` migrations in `backend-go/migrations/`. Update `docs/DATABASE_SCHEMA.md` immediately upon introducing schema changes.

### Rule E — Karpathy Behavioral Guidelines
- **Rationale**: Unrestrained AI modifications, speculative code, and non-surgical edits cause cascading regressions and hidden bugs.
- **Rule**: Every AI worker and human contributor must adhere to the 4 Karpathy invariants documented in `.agent/skills/karpathy-guidelines/SKILL.md`:
  1. **Think Before Coding**: Surface assumptions explicitly, inspect the codebase autonomously before asking questions, and explain trade-offs.
  2. **Simplicity First (KISS & YAGNI)**: Implement the minimum code that solves the problem. Forbid speculative abstractions, unrequested features, or deep nesting.
  3. **Surgical Changes**: Restrict code edits strictly to target symbols. Never modify adjacent lines, reformat untouched code, or refactor unrelated files. Prune only self-created orphaned imports or symbols.
  4. **Goal-Driven Execution**: Define objective verification commands (unit tests, static analysis, linters) before applying changes and loop until all criteria pass.

### Rule F — Code File Hygiene & Architecture Headers
- **Rationale**: Uniform file headers and visual breathing room accelerate code reviews and data-flow comprehension across Go and Flutter.
- **Rule**:
  1. **Top-of-File Architecture Header**: Non-trivial source files (`.go`, `.dart`) should feature an architectural header comment detailing:
     - `Purpose`: Why the file exists and its primary responsibility.
     - `Data & Logic Flow`: High-level summary of inputs, processing pipeline, and outputs.
     - `Key Components`: Primary structs, classes, handlers, or services.
  2. **Visual Breathing Room**: Maintain 2 blank lines between major functions, structs, endpoint handlers, and distinct logic sections to ensure readable separation between execution phases.

---

## 3. Git & Operational Constraints
- **Strictly No Uninstructed Commits/Pushes**: AI workers must never create Git commits, push branches, or open Pull Requests unless specifically commanded by the user in the current turn.
- **Language Policy**:
  - All written code, repository artifacts, documentation, and agent task files must be in formal **technical English**.
  - Interactive chat dialogue with the user adapts to the user's conversational preference (e.g., Bahasa Indonesia).
