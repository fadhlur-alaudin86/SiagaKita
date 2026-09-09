# Plan 03: Desktop Console Admin Shell Integration

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issues [#14](https://github.com/fadhlur-alaudin86/SiagaKita/issues/14), [#15](https://github.com/fadhlur-alaudin86/SiagaKita/issues/15), [#16](https://github.com/fadhlur-alaudin86/SiagaKita/issues/16), [#17](https://github.com/fadhlur-alaudin86/SiagaKita/issues/17) (completing Parent Issue [#3](https://github.com/fadhlur-alaudin86/SiagaKita/issues/3))
- **Problem**: The Flutter Windows Desktop Console features sophisticated, high-fidelity UI screens under `lib/features/admin/presentation/pages/`, but they currently operate on static mock data or placeholder methods without complete API wiring to the backend.
- **Goal**: Connect all four Admin Shell modules (Volunteer KYC, User Management, Gamification Ranks, and Statistics/Analytics) to their respective backend Go REST endpoints, ensuring robust error handling, responsive state updates, and strict localization compliance.

---

## 2. Module Specifications

### 2.1 Modul KYC Relawan ([#14](https://github.com/fadhlur-alaudin86/SiagaKita/issues/14))
- **Target Page**: `windows_console_flutter/lib/features/admin/presentation/pages/kyc_relawan_page.dart`
- **Data Source**: `GET /api/v1/admin/volunteers/pending`
- **Interactions**:
  - Render list of pending volunteer verification submissions.
  - Image rendering: Display KTP photo via `Image.network` with loading spinner and error fallback.
  - Document viewing: Launch certificate documents or PDF attachments via `url_launcher`.
  - Approve Action: `POST /api/v1/admin/volunteers/:id/approve` with confirmation dialog.
  - Reject Action: `POST /api/v1/admin/volunteers/:id/reject` with reason input dialog.
  - State Update: Remove verified volunteer from queue immediately upon success.

### 2.2 Modul User Management ([#15](https://github.com/fadhlur-alaudin86/SiagaKita/issues/15))
- **Target Page**: `windows_console_flutter/lib/features/admin/presentation/pages/user_management_page.dart`
- **Data Source**: `GET /api/v1/admin/users?role=&banned=&high_strike=&search=`
- **Interactions**:
  - Search field and filter chips (Role, Banned Only, High Strikes).
  - Strike Badge color coding:
    - 0–1 strikes: Green (`Colors.green`)
    - 2 strikes: Amber/Yellow (`Colors.amber`)
    - 3+ strikes / Banned: Crimson Red (`Colors.redAccent`)
  - Ban Dialog: Input duration in days (1, 3, 7, 30, permanent) + mandatory reason field -> calls `POST /api/v1/admin/users/:id/ban`.
  - Unban Action: Confirmation dialog -> calls `POST /api/v1/admin/users/:id/unban`.
  - Reset Strike Action: Confirmation dialog -> calls `DELETE /api/v1/admin/users/:id/strike`.

### 2.3 Modul Gamifikasi Ranks ([#16](https://github.com/fadhlur-alaudin86/SiagaKita/issues/16))
- **Target Page**: `windows_console_flutter/lib/features/admin/presentation/pages/gamifikasi_page.dart`
- **Data Source**: `GET /api/v1/admin/ranks`
- **Interactions**:
  - Dynamically load and render rank progression cards sorted by `min_exp`.
  - Modal Form for Add & Edit:
    - Input fields: Rank Name, Minimum XP, and Icon URL.
    - Form validation: XP must be $\ge 0$, name must be non-empty.
    - POST to `/api/v1/admin/ranks` on create; PUT to `/api/v1/admin/ranks/:id` on update.
  - Delete Action: Confirmation modal highlighting impacted volunteers -> calls `DELETE /api/v1/admin/ranks/:id`.

### 2.4 Modul Statistik & Analytics ([#17](https://github.com/fadhlur-alaudin86/SiagaKita/issues/17))
- **Target Page**: `windows_console_flutter/lib/features/admin/presentation/pages/statistik_page.dart`
- **Data Source**: `GET /api/v1/admin/stats?period=week|month|year`
- **Interactions**:
  - Segmented Period Selector (1 Minggu, 1 Bulan, 1 Tahun).
  - Dynamic KPI cards: Total SOS, Selesai (Resolved), Rata-rata Respons (Minutes), Rasio False Alarm (%), Relawan Aktif (Global).
  - `LineChart` (`fl_chart`): Smooth multi-point incident frequency trend over selected timeline.
  - `PieChart` (`fl_chart`): Dynamic categorical distribution of incidents by type.

---

## 3. Tasks & Implementation Checklist

- [ ] Connect `kyc_relawan_page.dart` to `AdminApiService`:
  - Wire queue fetching, KTP network images, certificate `url_launcher`, and approve/reject dialogs.
- [ ] Connect `user_management_page.dart` to `AdminApiService`:
  - Wire search query, role/strike filters, ban modal with days/reason, unban confirmation, and reset strike.
- [ ] Connect `gamifikasi_page.dart` to `AdminApiService`:
  - Wire rank cards list, add/edit modal form, and deletion confirmation modal.
- [ ] Connect `statistik_page.dart` to `AdminApiService`:
  - Wire period selector, refresh listeners, dynamic LineChart, and PieChart data mappings.
- [ ] Maintain localization compliance:
  - Add missing strings to `windows_console_flutter/lib/core/localization/app_localization.dart`.
  - Verify zero raw strings inside `Text(...)`, `SnackBar`, or modal dialogs (`.tr(context)`).
  - Prune any dead or duplicate keys.

---

## 4. Affected Components & Files

- `windows_console_flutter/lib/core/services/api_services.dart`
- `windows_console_flutter/lib/features/admin/presentation/pages/kyc_relawan_page.dart`
- `windows_console_flutter/lib/features/admin/presentation/pages/user_management_page.dart`
- `windows_console_flutter/lib/features/admin/presentation/pages/gamifikasi_page.dart`
- `windows_console_flutter/lib/features/admin/presentation/pages/statistik_page.dart`
- `windows_console_flutter/lib/core/localization/app_localization.dart`

---

## 5. Verification & Acceptance Criteria

1. **Automated Analysis**:
   - `cd windows_console_flutter && flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
2. **Acceptance Criteria**:
   - Approving or rejecting a KYC submission updates the queue in real-time.
   - Banning a user immediately reflects in their strike counter and ban badge.
   - Adding/editing ranks updates the gamification list without JSON serialization errors.
   - Switching stats time period re-renders charts smoothly without UI stutter or memory leak.
   - Closing Sub-Issues #14, #15, #16, and #17 satisfies and closes Parent Issue #3.
