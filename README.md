# SiagaKita

SiagaKita is a comprehensive emergency response and reporting system designed to bridge the gap between citizens in distress and first responders (volunteers and official agencies). By leveraging real-time telemetries, geospatial data, and multi-platform accessibility, SiagaKita aims to significantly reduce emergency response times and streamline incident management.

## System Architecture

The SiagaKita system consists of three main components:

1. **Backend Server (Go Fiber)**: The core engine that handles business logic, real-time WebSockets, JWT authentication, background processing, and interaction with PostgreSQL and Redis databases.
2. **Citizen & Volunteer Mobile App (Flutter)**: A mobile application built for the general public and registered volunteers. Features include one-tap SOS triggering, incident reporting (with multi-photo and audio support), real-time volunteer tracking, and gamification to encourage community participation.
3. **Agency & Admin Console (Flutter Desktop)**: A desktop application utilized by emergency agencies and central administrators to monitor live SOS alerts, dispatch responders, verify volunteer identities, and track operational statistics.

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
*   `windows_console_flutter/`: Desktop console application source code for emergency agencies and admins.
*   `infrastructure/`: Global environment configurations (`.env`) and Docker Compose files.
*   `docs/`: Comprehensive technical documentation, architecture guides, database schemas, and developer skill guides (`docs/skills/`).
*   `VERSION`: Plain-text file containing the current system release version (e.g., `1.0.24`).

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
4. Run the backend server:
   ```bash
   cd backend-go && go run cmd/api/main.go
   ```
5. Run the mobile application:
   ```bash
   cd mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env
   ```
6. Run the desktop console application:
   ```bash
   cd windows_console_flutter && flutter run -d linux --dart-define-from-file=../infrastructure/.env
   ```

## Documentation & AI Agent Skills

For comprehensive documentation and guides:
*   [docs/README.md](docs/README.md): Main documentation directory index.
*   [docs/skills/README.md](docs/skills/README.md): Human developer guide for AI Agent Skills.
*   [docs/DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md): PostgreSQL schema v12 design and ERD.
*   [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md): Production VPS deployment & automated CI/CD.
*   [docs/PROGRESS_REPORT.md](docs/PROGRESS_REPORT.md): System changelogs and sprint progress tracking.
