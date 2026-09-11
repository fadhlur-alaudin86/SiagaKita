# Plan 10: Gamification Badges & Personal Incident History

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issues [#32](https://github.com/fadhlur-alaudin86/SiagaKita/issues/32) & [#33](https://github.com/fadhlur-alaudin86/SiagaKita/issues/33) (completing Parent Issue [#8](https://github.com/fadhlur-alaudin86/SiagaKita/issues/8))
- **Priority**: P2 (Normal)
- **Status**: Ready for Backlog Execution
- **Problem**:
  - While XP and Tier Ranks are implemented, the badge achievement system is static and lacks automated evaluation. Volunteers who successfully resolve emergencies do not automatically receive achievement badges (`m_badges`), diminishing motivation and engagement.
  - In `mobile-flutter`, volunteers cannot view their full history of past emergency missions or see which badges they have unlocked vs locked.
- **Goal**:
  - Implement an automated badge evaluation engine on the backend triggered upon incident resolution.
  - Build the Badges Grid and Personal Mission History screens in `mobile-flutter`.

---

## 2. Technical Scope & Specifications

### 2.1 Automated Badge Evaluation Engine ([#32](https://github.com/fadhlur-alaudin86/SiagaKita/issues/32))
- **Trigger**: Execution of `MarkResolved` in `incident.Repository` / `incident.Service`.
- **Evaluation Criteria**:
  - *First Responder*: Awarded on completing 1st rescue mission.
  - *Medic Specialist*: Awarded on completing 5 medical emergency missions.
  - *Night Owl*: Awarded on completing missions between 22:00 and 05:00 local time.
  - *Community Guardian*: Awarded on reaching 25 total verified rescues.
- **Persistence**:
  - Insert record into `volunteer_badges_acquired` with `acquired_at = NOW()`.
  - Emit WebSocket celebration event `BADGE_UNLOCKED` to the volunteer's mobile device.

### 2.2 Mobile Badges Grid & Personal Mission History ([#33](https://github.com/fadhlur-alaudin86/SiagaKita/issues/33))
- **Profile Screen**:
  - Display interactive Badges Grid showing earned badges in full vibrant color.
  - Locked badges rendered in grayscale with lock icon and criteria description tooltip.
- **Personal Mission History**:
  - Dedicated screen listing all incidents handled by the logged-in volunteer.
  - Display incident type, date, location address, XP earned, and proof photo preview.

---

## 3. Tasks & Implementation Checklist

### 3.1 Backend Badge Evaluation Tasks ([#32](https://github.com/fadhlur-alaudin86/SiagaKita/issues/32))
- [ ] Create `EvaluateBadges(userID string)` engine in `incident.Service` or `user.Service`.
- [ ] Implement query checking badge eligibility against `volunteer_reputation` and `incident_responses`.
- [ ] Add unit tests verifying badge unlocking logic and duplicate prevention.
- [ ] Emit real-time notification on badge unlock via `hub.Hub`.

### 3.2 Mobile UI Tasks ([#33](https://github.com/fadhlur-alaudin86/SiagaKita/issues/33))
- [ ] Build `BadgeGridWidget` with grayscale color filter for unacquired badges.
- [ ] Build `MissionHistoryScreen` consuming `GET /api/v1/incidents/missions/history`.
- [ ] Add celebration pop-up / confetti animation when a `BADGE_UNLOCKED` event is received via WebSocket.
- [ ] Update Indonesian and English localization dictionaries.

---

## 4. Affected Components & Files

- `backend-go/internal/domain/incident/service.go`
- `backend-go/internal/domain/incident/repository.go`
- `mobile-flutter/lib/features/profile/widgets/badge_grid_widget.dart` (new)
- `mobile-flutter/lib/features/history/mission_history_screen.dart` (new)
- `mobile-flutter/lib/core/localization/app_localization.dart`
- `docs/backlog/features/F-032-F-033-gamification-badges.md` (new)

---

## 5. Verification & Acceptance Criteria

1. **Automatic Unlocking**:
   - When an admin/agency approves a volunteer's mission completion, qualifying badges are inserted into `volunteer_badges_acquired` without manual admin intervention.
2. **Visual Feedback**:
   - The volunteer's mobile app immediately displays an in-app celebration alert.
   - The badge transitions from grayscale to full color in the profile grid.
3. **Quality**:
   - `flutter analyze` passes with 0 warnings.
   - `go test -v ./...` passes with zero regressions.
