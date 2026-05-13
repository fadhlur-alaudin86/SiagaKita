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
*   **Offline Resilience**: Reports created without an internet connection are saved locally and can be retried later.

### For Volunteers
*   **Real-time Radar**: View active SOS requests within a specified radius.
*   **Mission Acceptance**: Accept SOS calls and automatically share live location with the victim and monitoring agencies.
*   **Gamification & Ranks**: Earn experience points (XP) and badges for successfully completing rescue missions.
*   **Verification (KYC)**: Upload ID and medical certifications to become a verified first responder.

### For Agencies & Admins
*   **Live Operational Map**: Monitor all active incidents and moving volunteers on an interactive map.
*   **Incident Management**: Review incoming reports, assign urgency levels, dispatch personnel, and resolve incidents.
*   **User Management**: Approve or reject volunteer KYC applications, and manage SOS abuse (strikes and bans).

## Technology Stack

*   **Mobile & Desktop Frontend**: Flutter (Dart)
*   **Backend Framework**: Go 1.26 with Fiber v2
*   **Database**: PostgreSQL 15
*   **Caching & Live State**: Redis
*   **Deployment**: Docker & Docker Compose
*   **Maps & Geocoding**: OpenStreetMap (OSM) & Nominatim API

## Project Structure

*   `backend-go/`: Contains the Go server source code, migrations, and environment configurations.
*   `mobile-flutter/`: The mobile application code for citizens and volunteers.
*   `windows_console_flutter/`: The desktop application code for agencies and super-admins.
*   `infrastructure/`: Contains global environment files (`.env`) and Docker configurations.
*   `docs/`: Additional documentation including Database Schemas, API Endpoints, and Progress Reports.

## Getting Started

To run the project locally:

1.  Ensure you have Docker, Go, and Flutter installed on your machine.
2.  Navigate to the `infrastructure/` directory and configure your `.env` file based on `.env-example`.
3.  Start the database services using Docker Compose:
    `docker-compose up -d postgres redis`
4.  Run the backend server:
    `cd backend-go && go run cmd/api/main.go`
5.  Run the mobile application:
    `cd mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env`
6.  Run the desktop console:
    `cd windows_console_flutter && flutter run -d windows --dart-define-from-file=../infrastructure/.env` (or `linux`/`macos` depending on your OS)

## Documentation

For an in-depth understanding of the system, please refer to the documents in the `docs/` directory:
*   `DATABASE_SCHEMA.md`: Detailed view of the PostgreSQL tables and their relationships.
*   `PROGRESS_REPORT.md`: Comprehensive log of development sprints and feature implementations.
*   `DEPLOYMENT_GUIDE.md`: Instructions for deploying the system to a production environment.
