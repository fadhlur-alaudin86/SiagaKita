# Plan 05: Production Assets & DevOps Deployment Readiness

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issues [#34](https://github.com/fadhlur-alaudin86/SiagaKita/issues/34) & [#35](https://github.com/fadhlur-alaudin86/SiagaKita/issues/35) (completing Parent Issue [#9](https://github.com/fadhlur-alaudin86/SiagaKita/issues/9))
- **Problem**:
  1. The siren audio file at `windows_console_flutter/assets/audio/alarm.mp3` is currently a 0-byte placeholder. When an emergency alert arrives in the Desktop Console, `AudioService` fails to play sound or throws an audio player error.
  2. The automated deployment pipeline (`.github/workflows/release-deploy.yml`) has not been dry-run with production tag releases, and server-side `.env` variables (`SUPERADMIN_EMAIL`, `SUPERADMIN_PASS`) must be verified to prevent startup crashes or failed admin account provisioning on the VPS.
- **Goal**: Provision high-clarity, royalty-free siren audio assets and validate end-to-end zero-downtime deployment, container health checks, and rollback triggers in the DevOps pipeline.

---

## 2. Technical Scope & Specifications

### 2.1 Audio Siren Asset Standardization ([#34](https://github.com/fadhlur-alaudin86/SiagaKita/issues/34))
- Source a valid, royalty-free / CC0 emergency alarm sound in MP3 format (128–192 kbps, stereo/mono, duration 3–5 seconds looped).
- Place file at: `windows_console_flutter/assets/audio/alarm.mp3`.
- Verify declaration in `windows_console_flutter/pubspec.yaml`:
  ```yaml
  flutter:
    assets:
      - assets/audio/alarm.mp3
  ```
- Test `AudioService`:
  - Verify `AudioService.playAlarm()` loops cleanly on incoming SOS.
  - Verify `AudioService.stopAlarm()` mutes the sound immediately when an operator clicks the mute button or selects an incident.

### 2.2 Automated Deployment Pipeline & Config Audit ([#35](https://github.com/fadhlur-alaudin86/SiagaKita/issues/35))
1. **Server Configuration (`.env.prod` on VPS)**:
   - Ensure `SUPERADMIN_EMAIL` and `SUPERADMIN_PASS` are configured with strong production credentials.
   - Verify that `seedSuperAdmin` in `backend-go/cmd/api/main.go` creates or updates the root administrator account seamlessly during initialization.
   - Verify JWT and database variables: `JWT_SECRET`, `JWT_ACCESS_TTL=15m`, `JWT_REFRESH_TTL=168h`, `DB_HOST`, `REDIS_HOST`.
2. **CI/CD Pipeline (`.github/workflows/release-deploy.yml`)**:
   - Trigger condition: git tag push matching `v[0-9]+.[0-9]+.[0-9]+*`.
   - Workflow stages:
     1. Build Docker image with multi-stage caching.
     2. Push to Docker registry.
     3. SSH into production VPS and execute zero-downtime rolling restart:
        - Pull latest container image.
        - Run automated database migration via `cmd/migrate`.
        - Spin up new container.
        - Poll `/health` endpoint for up to 30 seconds until HTTP 200 is confirmed.
     4. Automated Rollback:
        - If `/health` polling fails, revert to previous container image, run `cmd/migrate down 1` if necessary, and alert via GitHub Actions summary.

---

## 3. Tasks & Implementation Checklist

### 3.1 Audio Asset Tasks ([#34](https://github.com/fadhlur-alaudin86/SiagaKita/issues/34))
- [x] Provide valid, royalty-free audio file and overwrite `windows_console_flutter/assets/audio/alarm.mp3`.
- [x] Verify `pubspec.yaml` assets configuration in `windows_console_flutter`.
- [x] Test audio playback and mute control in `windows_console_flutter/lib/core/services/audio_service.dart`.

### 3.2 DevOps & Deployment Verification Tasks ([#35](https://github.com/fadhlur-alaudin86/SiagaKita/issues/35))
- [x] Audit `.github/workflows/release-deploy.yml` steps for syntax and error handling.
- [x] Verify health-check polling loop and rollback trap in the deployment script.
- [x] Prepare production `.env.prod.example` template with all required keys documented.
- [x] Verify that `seedSuperAdmin` handles existing vs new superadmin credentials without race conditions.

---

## 4. Affected Components & Files

- `windows_console_flutter/assets/audio/alarm.mp3`
- `windows_console_flutter/pubspec.yaml`
- `windows_console_flutter/lib/core/services/audio_service.dart`
- `.github/workflows/release-deploy.yml`
- `backend-go/cmd/api/main.go`

---

## 5. Verification & Acceptance Criteria

1. **Audio Verification**:
   - Running the Desktop Console and triggering `AudioService.playAlarm()` produces clear alarm audio without platform exceptions.
   - Clicking "Matikan Alarm" immediately stops the audio stream.
2. **Pipeline Verification**:
   - Push of a test tag `v0.1.0-alpha` or release dry-run successfully executes all workflow stages.
   - Container health check at `GET https://api.siagakita.com/health` returns `{"status":"ok"}`.
   - Closing Issue #34 and Issue #35 satisfies and closes Parent Issue #9.
