# SiagaKita

SiagaKita is a comprehensive emergency response and reporting system designed to bridge the gap between citizens in distress and first responders (volunteers and official agencies). By leveraging real-time telemetries, geospatial data, and multi-platform accessibility, SiagaKita aims to significantly reduce emergency response times and streamline incident management.

## System Architecture

The SiagaKita system consists of four main components:

1. **Backend Server (Go Fiber)**: The core engine that handles business logic, real-time WebSockets, JWT authentication, background processing, and interaction with PostgreSQL and Redis databases.
2. **Citizen & Volunteer Mobile App (Flutter)**: A mobile application built for the general public and registered volunteers. Features include first-time visual onboarding, contextual permission priming, one-tap SOS triggering with offline guard, incident reporting (with multi-photo and audio support), real-time volunteer tracking, and gamification to encourage community participation.
3. **Agency & Admin Console (Flutter Desktop)**: A desktop application utilized by emergency agencies and central administrators to monitor live SOS alerts, dispatch responders, verify volunteer identities, and track operational statistics.
4. **Official Agency Responder Mobile App (Flutter)**: A dedicated tactical mobile application built specifically for official agency field personnel (police, firefighters, paramedics, disaster response teams). Features include badge-number credential authentication, tactical mission board, rapid status progression (`en_route` -> `on_scene` -> `resolved`), zero-churn background GPS telemetry, and integrated turn-by-turn navigation.

## Key Features

### For Citizens
*   **Instant SOS**: Trigger an emergency alert instantly. The system will broadcast the SOS to nearby volunteers and agencies.
*   **Background Telemetry**: If an SOS is active, the app transmits real-time GPS locations to responders, even when running in the background.
*   **Incident Reporting**: Report non-emergency incidents (e.g., traffic accidents, medical situations) with rich evidence, including photos and audio recordings.
*   **Offline Resilience & Auto-Sync**: Reports and SOS triggers created without an internet connection are saved locally. Pending SOS requests will automatically resume in the background the moment the device reconnects to the network, and their cooldown states are securely persisted to prevent circumvention.

### For Volunteers
*   **Real-time Radar**: View active SOS requests within a specified radius.
*   **Mission Acceptance**: Accept SOS calls and automatically share live location with the victim and monitoring agencies.
*   **Gamification & Ranks**: Earn experience points (XP) and badges for successfully completing rescue missions.
*   **Verification (KYC)**: Strict onboarding with mandatory identity fields (NIK validation, WhatsApp synchronization) and medical certification uploads to become a verified first responder.

### For Agencies & Admins
*   **Live Operational Map**: Monitor all active incidents and moving volunteers on an interactive map.
*   **Multi-Device Sync**: Console users can login from multiple devices simultaneously with real-time state synchronization via WebSockets.
*   **Incident Management**: Review incoming reports, assign urgency levels, dispatch personnel, and resolve incidents.
*   **User Management**: Approve or reject volunteer KYC applications, and manage SOS abuse (strikes and bans).
*   **Analytics Dashboard**: Real-time statistical aggregation of incidents with dynamic filtering periods (Week, Month, Year).
*   **Agency Customization**: Dynamic profiles integrated natively into the dashboard UI for respective emergency agencies.

### For Agency Responders
*   **Dual Authentication**: Secure sign-in utilizing agency personnel credentials (badge number or official email) validated against official agency rosters.
*   **Tactical Mission Board**: Real-time incoming incident assignments, priority level indicators, victim contact details, and incident history.
*   **Rapid Status Progression**: Clear step-by-step mission workflow transitions (`assigned` -> `en_route` -> `on_scene` -> `resolved`) synchronized with the central desktop console and victim app.
*   **Adaptive Background Telemetry**: Zero-churn GPS telemetry streaming via `sync.Pool` backend ingestion, updating dispatchers in real time while preserving mobile battery life.
*   **Tactical Map & Navigation**: Interactive OpenStreetMap tracking incident epicenter, victim location, and external map routing handoff (Google Maps / Waze).

### System Reliability
*   **Single-Device Mobile Session**: Prevents account sharing and enhances security by enforcing one active session per mobile user via Redis-backed JTI validation.
*   **Idempotent Operations**: Ensures consistency for critical state changes using `X-Idempotency-Key` headers, preventing duplicate actions from synchronized devices.

## Technology Stack

*   **Mobile & Desktop Frontend**: Flutter (Dart)
*   **Backend Framework**: Go 1.26 with Fiber v2 + Sonic + Zerolog
*   **Database**: PostgreSQL 15
*   **Caching & Session Store**: Redis (Mandatory for Session Guard & Sync)
*   **Deployment**: Docker & Docker Compose
*   **Maps & Geocoding**: OpenStreetMap (OSM) & Nominatim API

## Project Structure

*   `.agent/skills/`: AI Agent skill specifications (`devops-workflow`, `gh-project-manager`, `feature-dev-workflow`).
*   `.github/workflows/`: GitHub Actions CI/CD automation pipelines (`ci-dev.yml`, `ci-main.yml`, `release-deploy.yml`, `auto-tag.yml`).
*   `backend-go/`: Go server source code, migrations, and domain logic.
*   `mobile-flutter/`: Mobile application source code for citizens and volunteers.
*   `mobile-flutter-responder/`: Tactical mobile application source code for official emergency agency responders.
*   `windows_console_flutter/`: Desktop console application source code for emergency agencies and admins.
*   `infrastructure/`: Global environment configurations (`.env`) and Docker Compose files.
*   `docs/`: Comprehensive technical documentation, architecture guides, database schemas, and developer skill guides (`docs/skills/`).
*   `VERSION`: Plain-text file containing the current system release version (e.g., `1.0.25`).

## Development & Git Workflow

### Branch Strategy
- `main`: Protected production branch (deploys via release tags `v*.*.*`).
- `dev`: Active integration branch (all feature branches merge here via Pull Request).
- `feature/F-XXX-name`: Feature development branch (created from `dev`).
- `fix/F-XXX-name`: Bug fix branch (created from `dev`).

### Conventional Commits
All commits must follow the format: `<type>(<scope>): <short description>`
- Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `style`, `perf`
- Example: `feat(incident): add volunteer dispatch endpoint`

### Release Procedure
1. Increment the version number in the root `VERSION` file (e.g., `1.0.25`).
2. Create a PR from `dev` to `main`.
3. Upon PR approval and merge to `main`, GitHub Actions automatically creates git tag `v1.0.25`.
4. The release workflow builds Docker images, deploys to production VPS with automated rollback protection, and publishes a GitHub Release.

## Getting Started

To run the project locally:

1. Ensure Docker, Go, and Flutter are installed on your machine.
2. Navigate to `infrastructure/` and configure `.env` based on `.env-example`.
3. Start database and caching services using Docker Compose:
   ```bash
   cd infrastructure && docker compose up -d postgres redis
   ```
4. Run database migrations to bring the schema up to date:
   ```bash
   cd backend-go && go run cmd/migrate/main.go up
   ```
5. Run the backend server:
   ```bash
   go run cmd/api/main.go
   ```
   Interactive Swagger UI documentation will be available at `http://localhost:8080/docs/*`.
6. Run the mobile application:
   ```bash
   cd ../mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env
   ```
7. Run the desktop console application:
   ```bash
   cd ../windows_console_flutter && flutter run -d linux --dart-define-from-file=../infrastructure/.env
   ```
8. Run the official agency responder mobile application:
   ```bash
   cd ../mobile-flutter-responder && flutter run --dart-define-from-file=../infrastructure/.env
   ```

## Documentation & AI Agent Skills

For comprehensive documentation and guides:
*   [docs/README.md](docs/README.md): Main technical documentation catalog.
*   [docs/BACKEND_ARCHITECTURE.md](docs/BACKEND_ARCHITECTURE.md): Go Fiber backend architecture, DDD layout, and security guards.
*   [docs/DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md): PostgreSQL schema v12 specifications and migration CLI runbook.
*   [docs/design/README.md](docs/design/README.md): Living Mermaid visual architecture (Database ERD, Use Cases, Sequence Flows).
*   [docs/api/openapi.yaml](docs/api/openapi.yaml): Modular OpenAPI 3.0 API contracts (served locally via Swagger UI).
*   [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md): Production VPS deployment, Nginx reverse proxy, and automated CI/CD.
*   [docs/skills/README.md](docs/skills/README.md): Human developer guide for AI Agent Skills.
