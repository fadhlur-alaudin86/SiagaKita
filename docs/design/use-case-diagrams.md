# Use Case Diagrams — SiagaKita

> **System Architecture Reference:** SiagaKita Emergency Management Platform  
> **Target Actors:** Civilian, Volunteer, Agency Dispatcher, Admin, Superadmin, and System Background Workers.

---

## 1. Actor Role Matrix

| Actor | Primary Interface | Responsibility & Capabilities |
|---|---|---|
| **Civilian (Warga)** | Mobile Flutter App | Trigger emergency SOS, manage 10s grace period, cancel SOS, submit community reports (Jalur B), manage personal medical biodata, and emergency contacts. |
| **Volunteer (Relawan)** | Mobile Flutter App | Receive real-time nearby emergency radar alerts, accept rescue missions, stream GPS coordinates, upload on-scene proof of resolution, and gain XP/Ranks. |
| **Agency Responder (Petugas Lapangan)** | Mobile Responder Flutter App | Authenticate with official badge number, monitor tactical mission board, update response status (`en_route` -> `on_scene` -> `resolved`), stream zero-churn background GPS telemetry, and navigate via OpenStreetMap/external maps. |
| **Agency (Instansi)** | Desktop Flutter Console | Monitor live municipal emergencies, dispatch field personnel, review volunteer completion evidence, resolve incidents, and penalize false alarms. |
| **Admin** | Desktop Flutter Console | Review civilian NIK KYC and volunteer certifications, manage user accounts, ban/unban abusive users, and inspect operational metrics. |
| **Superadmin** | Desktop Flutter Console / CLI | Seed and manage regional admin accounts, register emergency agencies, and configure global system settings. |
| **System Worker** | Go Fiber Backend / Redis | Enforce 10-second grace period timers, listen to Redis expired-key heartbeat events, stream WebSocket broadcasts, and parse SMS fallback coordinates. |

---

## 2. Global Use Case Diagram

```mermaid
flowchart TB
    %% Actors
    subgraph Actors["System Actors"]
        Warga["Civilian (Warga)"]
        Relawan["Volunteer (Relawan)"]
        Petugas["Agency Responder (Petugas)"]
        Instansi["Agency (Instansi / Dispatcher)"]
        Admin["Admin & Superadmin"]
        System["System Background Worker"]
    end

    %% Use Cases: Auth & Identity
    subgraph UC_Auth["1. Authentication & Identity"]
        UC_Reg["Register & Verify OTP (Email/WA)"]
        UC_Login["Login & Session Handshake"]
        UC_Bio["Update Profile & Medical Biodata"]
        UC_NIK["Submit NIK Identity Verification"]
    end

    %% Use Cases: Emergency SOS
    subgraph UC_SOS["2. Emergency SOS (Jalur A)"]
        UC_TriggerSOS["Trigger SOS Emergency"]
        UC_GracePeriod["Cancel SOS in 10s Grace Period"]
        UC_SelectType["Select Incident Category"]
        UC_StreamCoord["Stream Real-Time GPS Coordinates"]
        UC_UploadEvidence["Upload Post-Broadcast Evidence (Cam/Audio)"]
    end

    %% Use Cases: Community Reports
    subgraph UC_Report["3. Community Reports (Jalur B)"]
        UC_SubmitReport["Submit Public Hazard Report"]
        UC_CancelReport["Cancel Pending Report"]
        UC_ViewReportHistory["View Citizen Report History"]
    end

    %% Use Cases: Volunteer Operations
    subgraph UC_Volunteer["4. Volunteer Response & Gamification"]
        UC_SubmitCert["Submit Volunteer Verification KYC"]
        UC_NearbyRadar["Monitor Nearby SOS Radar"]
        UC_AcceptMission["Accept Rescue Mission"]
        UC_NavLocation["Stream Live Response Location"]
        UC_CompleteMission["Upload Resolution Proof (Photo)"]
        UC_EarnRep["Earn XP, Ranks & Badges"]
    end

    %% Use Cases: Agency Responder Tactical Operations
    subgraph UC_Responder["5. Agency Responder Tactical Operations"]
        UC_BadgeLogin["Login with Badge / Official Credentials"]
        UC_MissionBoard["Inspect Assigned Incident Missions"]
        UC_ProgressStatus["Progress Response Status (En Route, On Scene)"]
        UC_StreamTelemetry["Stream Live GPS Telemetry (sync.Pool)"]
        UC_TacticalNav["Open Turn-by-Turn External Navigation"]
    end

    %% Use Cases: Agency Dispatch
    subgraph UC_Agency["6. Agency Dispatch & Incident Command"]
        UC_LiveMap["Monitor Citywide Live Map"]
        UC_AgencyHandle["Mark SOS Handled by Agency"]
        UC_ReviewVol["Review & Approve Volunteer Response"]
        UC_ResolveSOS["Resolve SOS Incident"]
        UC_MarkFalseAlarm["Mark False Alarm & Issue Strike"]
        UC_TriageReport["Triage & Update Community Report"]
    end

    %% Use Cases: Administration
    subgraph UC_Admin["7. Administration & Security"]
        UC_ApproveKYC["Review & Approve Volunteer / NIK KYC"]
        UC_ManageAgency["Register Agency & Personnel Accounts"]
        UC_ManageAdmin["Create Regional Admin Accounts"]
        UC_ModUser["Audit Strikes, Ban / Unban Users"]
        UC_ManageMaster["Manage Ranks & Badges Catalog"]
        UC_ViewStats["View Operational Analytics & SLA"]
    end

    %% Use Cases: Background System
    subgraph UC_System["8. Automated System Operations"]
        UC_AutoBroadcast["Auto-Promote Grace Period to Broadcasting"]
        UC_WSBroadcast["Broadcast WS Event (INCOMING_EMERGENCY)"]
        UC_SMSFallback["Parse Inbound SMS Fallback Coordinates"]
        UC_SessionHeartbeat["Monitor Heartbeat & Clear Expired Sessions"]
    end

    %% Connections: Warga
    Warga --> UC_Reg
    Warga --> UC_Login
    Warga --> UC_Bio
    Warga --> UC_NIK
    Warga --> UC_TriggerSOS
    Warga --> UC_GracePeriod
    Warga --> UC_SelectType
    Warga --> UC_StreamCoord
    Warga --> UC_UploadEvidence
    Warga --> UC_SubmitReport
    Warga --> UC_CancelReport
    Warga --> UC_ViewReportHistory

    %% Connections: Relawan
    Relawan --> UC_Reg
    Relawan --> UC_Login
    Relawan --> UC_SubmitCert
    Relawan --> UC_NearbyRadar
    Relawan --> UC_AcceptMission
    Relawan --> UC_NavLocation
    Relawan --> UC_CompleteMission
    Relawan --> UC_EarnRep

    %% Connections: Agency Responder
    Petugas --> UC_BadgeLogin
    Petugas --> UC_MissionBoard
    Petugas --> UC_ProgressStatus
    Petugas --> UC_StreamTelemetry
    Petugas --> UC_TacticalNav

    %% Connections: Instansi
    Instansi --> UC_Login
    Instansi --> UC_LiveMap
    Instansi --> UC_AgencyHandle
    Instansi --> UC_ReviewVol
    Instansi --> UC_ResolveSOS
    Instansi --> UC_MarkFalseAlarm
    Instansi --> UC_TriageReport

    %% Connections: Admin & Superadmin
    Admin --> UC_Login
    Admin --> UC_ApproveKYC
    Admin --> UC_ManageAgency
    Admin --> UC_ManageAdmin
    Admin --> UC_ModUser
    Admin --> UC_ManageMaster
    Admin --> UC_ViewStats

    %% Connections: System
    System --> UC_AutoBroadcast
    System --> UC_WSBroadcast
    System --> UC_SMSFallback
    System --> UC_SessionHeartbeat
```

---

## 3. Subsystem Breakdown

### 3.1 Emergency Operations (Jalur A vs Jalur B)

```mermaid
flowchart LR
    subgraph JalurA["Jalur A — Darurat (SOS)"]
        A1["Civilian: Trigger SOS"] --> A2{"Grace Period (10s)"}
        A2 -->|Cancel by Reporter| A3["Status: canceled"]
        A2 -->|Timeout / Select Type| A4["Status: broadcasting"]
        A4 --> A5["WebSocket Broadcast to Agency & Volunteer Radar"]
        A5 --> A6["Volunteer Accepts Mission"]
        A6 --> A7["Volunteer: On-Scene Navigation & Evidence Upload"]
        A7 --> A8["Agency: Review Evidence & Mark Resolved"]
        A5 --> A9["Agency Dispatches Field Responder"]
        A9 --> A11["Responder: Accept Mission & En Route"]
        A11 --> A12["Responder: Stream Background GPS Telemetry"]
        A12 --> A13["Responder: Arrive On-Scene & Mitigate"]
        A13 --> A8
        A4 -.->|If False Emergency| A10["Agency: Mark False Alarm (Strike +1)"]
    end

    subgraph JalurB["Jalur B — Non-Darurat (Laporan Warga)"]
        B1["Civilian: Submit Report (Type, GPS, Photos, Audio)"] --> B2["Status: sent / pending"]
        B2 --> B3["Agency Console: Triage & Assignment"]
        B3 --> B4["Status: in_progress"]
        B4 --> B5["Field Verification & Resolution"]
        B5 --> B6["Status: resolved"]
    end
```

### 3.2 Governance, Gamification & Trust Flow

```mermaid
flowchart TD
    subgraph KYC_Trust["Trust & Verification Subsystem"]
        C1["Civilian: Upload NIK & KTP"] --> C2["Admin: Review Identity"]
        C2 -->|Approve| C3["Status: Verified Civilian (Higher SOS Trust)"]
        C2 -->|Reject| C4["Status: Rejected (Standard Trust)"]

        V1["User: Apply for Volunteer KYC (Upload Certificates)"] --> V2["Admin: Review Certifications"]
        V2 -->|Approve| V3["Role Upgraded: Volunteer (Access to Mission Radar)"]
        V2 -->|Reject| V4["Application Rejected (Remains Civilian)"]
    end

    subgraph Gamification["Volunteer Gamification Subsystem"]
        M1["Volunteer Completes Mission"] --> M2["Agency Approves Review"]
        M2 --> M3["Award EXP Points (+100 XP)"]
        M3 --> M4{"Check XP >= Next Rank Threshold?"}
        M4 -->|Yes| M5["Promote to Next Rank (m_ranks)"]
        M4 -->|No| M6["Update Total Rescues & Keep Rank"]
        M5 --> M7["Evaluate Milestone Badges (m_badges)"]
        M6 --> M7
    end
```
