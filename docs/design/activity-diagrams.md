# 🔄 Activity & State Machine Diagrams — SiagaKita

> **Operational Workflows:** Real-Time Emergency Response, Incident Lifecycles, and Verification State Machines.

---

## 1. SOS Emergency Response Lifecycle (Jalur A)

The diagram below details the entire end-to-end lifecycle across the 4 key participants: **Reporter (Warga)**, **Backend (Go + Redis + WS)**, **Volunteer (Relawan)**, and **Agency (Instansi Console)**.

```mermaid
sequenceDiagram
    autonumber
    actor W as 👤 Reporter (Warga)
    participant B as ⚙️ Backend (Fiber + Redis + WS)
    actor V as ⛑️ Volunteer (Relawan)
    actor A as 🏢 Agency (Console)

    %% 1. Trigger SOS
    Note over W, B: Step 1 — Emergency Trigger & Grace Period (10s)
    W->>B: POST /api/v1/incidents/trigger {lat, lng, address}
    B->>B: Verify Ban Status (user_profiles.is_sos_banned)
    B-->>W: 201 Created (incident_id, status: "grace_period")
    
    alt Reporter Cancels within 10 seconds
        W->>B: POST /api/v1/incidents/{id}/canceled
        B->>B: Update status = "canceled"
        B-->>W: 200 OK (SOS Aborted)
    else Grace Period Expires OR Category Selected
        opt Select Type Early
            W->>B: PATCH /api/v1/incidents/{id}/type {incident_type}
        end
        B->>B: Service promotes status = "broadcasting"
        
        %% 2. Real-Time Broadcast
        Note over B, A: Step 2 — Real-Time WebSocket Alarm Broadcast
        par WebSocket Alarm Broadcast
            B->>A: WS: "INCOMING_EMERGENCY" (Sound Siren & Map Pin)
            B->>V: WS: "INCOMING_EMERGENCY" (Vibrate & Push Radar Notification)
        end

        %% Background Evidence Upload
        opt Background Evidence Upload
            W->>B: POST /api/v1/incidents/{id}/evidence (Camera Photo + 5s Audio)
            B->>A: WS: "SOS_STATUS_UPDATE" (Attach media to console card)
        end

        %% 3. Volunteer Mission Response
        Note over V, A: Step 3 — Response & On-Scene Operations
        alt Volunteer Accepts Emergency
            V->>B: POST /api/v1/incidents/{id}/accept
            B->>B: Insert incident_responses (status: "on_scene")
            B->>B: Update incidents.status = "handled"
            par Notify Parties
                B->>W: WS: "VOLUNTEER_HANDLING" (Show Volunteer Name & Distance)
                B->>A: WS: "SOS_STATUS_UPDATE" (Show Assigned Volunteer)
            end

            %% Live Telemetry Loop
            loop During Travel (every 10s - 30s)
                V->>B: PUT /api/v1/incidents/{id}/response-location {lat, lng}
                B->>W: WS: "VOLUNTEER_LOCATION_UPDATE" (Live Map Tracker)
                B->>A: WS: "VOLUNTEER_LOCATION_UPDATE" (Console Map Tracker)
            end

            %% Volunteer Completes
            V->>B: POST /api/v1/incidents/{id}/volunteer-complete (Photo Proof)
            B->>B: Update incident_responses.status = "waiting_review"
            B->>A: WS: "INCIDENT_UPDATED" (Waiting Agency Review)

            %% Agency Review
            A->>B: POST /api/v1/incidents/{id}/agency-review {volunteer_id, approve: true}
            B->>B: Award XP (+100 XP), Update Total Rescues, Check Rank Up
            B->>V: WS: "MISSION_APPROVED" (Display XP Earned & Rank Dialog)
            
            A->>B: POST /api/v1/incidents/{id}/agency-resolve
            B->>B: Update incidents.status = "resolved", completed_at = NOW()
            par Incident Complete
                B->>W: WS: "SOS_RESOLVED" (Reset UI)
                B->>A: WS: "INCIDENT_RESOLVED" (Archive Card)
            end

        else Agency Directly Dispatches Field Unit
            A->>B: POST /api/v1/incidents/{id}/agency-handle
            B->>B: Update incidents.handled_by_agency_id, status = "handled"
            B->>W: WS: "AGENCY_HANDLING" (Official Unit En Route)
            A->>B: POST /api/v1/incidents/{id}/agency-resolve
            B->>B: Update incidents.status = "resolved", completed_at = NOW()
            B->>W: WS: "SOS_RESOLVED" (Reset UI)

        else False Alarm Flagged
            A->>B: POST /api/v1/incidents/{id}/mark-false-alarm {reason}
            B->>B: Update incidents.status = "false_alarm"
            B->>B: Insert sos_strikes (audit record)
            B->>B: Increment user_profiles.sos_strike_count
            opt Strike Count >= 3
                B->>B: Set user_profiles.is_sos_banned = TRUE
            end
            B->>W: WS: "SOS_FALSE_ALARM" (Reset UI, Display Strike Warning)
            B->>A: WS: "SOS_STATUS_UPDATE" (Closed as False Alarm)
        end
    end
```

---

## 2. Incident State Machine (`incidents.status`)

The state machine diagram below models all permissible state transitions for emergency SOS incidents in PostgreSQL:

```mermaid
stateDiagram-v2
    [*] --> grace_period : POST /incidents/trigger

    state grace_period {
        [*] --> TimerRunning : 10s Window
        TimerRunning --> UserCanceled : Reporter presses Cancel
        TimerRunning --> TypeSelected : Reporter selects category
        TimerRunning --> Timeout : 10s Timer expires
    }

    grace_period --> canceled : UserCanceled (Reporter abort)
    grace_period --> broadcasting : Timeout or TypeSelected

    broadcasting --> handled : Volunteer accepts OR Agency handles
    broadcasting --> false_alarm : Agency marks false alarm
    broadcasting --> canceled : Reporter cancels late

    state handled {
        [*] --> EnRouteOrOnScene : Responder assigned
        EnRouteOrOnScene --> WaitingReview : Volunteer uploads resolution photo
        EnRouteOrOnScene --> AgencyResolving : Agency field unit finishes
        WaitingReview --> Reviewed : Agency approves volunteer proof
    }

    handled --> resolved : Agency confirms resolution
    handled --> false_alarm : On-scene unit detects hoax

    resolved --> [*]
    canceled --> [*]
    false_alarm --> [*]
```

---

## 3. Community Hazard Report Lifecycle (Jalur B)

Unlike emergency SOS, community reports follow an asynchronous triage workflow for public incidents (potholes, fallen trees, broken streetlights, minor accidents):

```mermaid
stateDiagram-v2
    [*] --> sent : Civilian submits report with photos & audio

    sent --> pending : Stored in database & indexed for agency triage
    pending --> canceled : Civilian cancels pending report
    
    pending --> in_progress : Agency operator triages & assigns to field team
    in_progress --> resolved : Field team addresses hazard & closes ticket
    in_progress --> canceled : Invalid or duplicate report rejected

    resolved --> [*]
    canceled --> [*]
```

---

## 4. Identity & Verification State Machines

### 4.1 Civilian NIK Verification (`user_profiles.nik_verification_status`)

```mermaid
stateDiagram-v2
    [*] --> unverified : User account created

    unverified --> pending : User uploads NIK & KTP photo
    pending --> verified : Admin approves identity document
    pending --> rejected : Admin rejects (photo blurry / mismatch)
    rejected --> pending : User re-submits corrected KTP document

    verified --> [*]
```

### 4.2 Volunteer Certification & Verification (`volunteer_certifications.status`)

```mermaid
stateDiagram-v2
    [*] --> pending : User submits SAR/PMI/Damkar certificate

    pending --> approved : Admin approves certificate document
    pending --> rejected : Admin rejects certificate with reason

    state approved {
        [*] --> TriggerFired : DB Trigger Executes
        TriggerFired --> ActiveVerified : user_profiles.is_verified_volunteer = TRUE
    }

    approved --> expired : Certificate validity date passes
    state expired {
        [*] --> CheckOtherCerts : DB Trigger checks other certs
        CheckOtherCerts --> RevokeRole : If no other active certs, is_verified_volunteer = FALSE
    }

    rejected --> pending : Volunteer re-uploads valid documentation
```
