# SiagaKita Infrastructure

Local development infrastructure for the SiagaKita platform: PostgreSQL, Redis,
Nginx reverse proxy, and the Toxiproxy-based weak-network harness used for
offline/SOS resilience testing.

## Directory layout

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Base dev stack (PostgreSQL + Redis). |
| `docker-compose.test.yml` | Test stack wired to Toxiproxy for weak-network tests. |
| `docker-compose.demo.yml` | Demo stack. |
| `docker-compose.prod.yml` | Production VPS stack. |
| `.env.weaknet` | Environment overrides used for weak-network E2E runs. |
| `.env.dev` / `.env.prod` / `.env.example` | Dev / prod / example environment files. |
| `nginx/` | Nginx reverse-proxy configuration. |
| `ssl/` | SSL certificates. |
| `toxiproxy.test.json` | Toxiproxy toxic configuration (latency/bandwidth/outage). |

## Weak-network harness

The weak-network harness simulates flaky/offline conditions for the mobile SOS
path (audit findings F1-F6). Run the test stack with Toxiproxy, then launch the
mobile client with `--dart-define-from-file=../infrastructure/.env.weaknet`:

```bash
cd infrastructure && docker compose -f docker-compose.test.yml up -d
cd ../mobile-flutter && flutter run --dart-define-from-file=../infrastructure/.env.weaknet
```

The E2E reconnect scenario (offline trigger, ~2 min outage, reconnect) is
executed against the AVD named `agent`.

### Emulator prerequisite — Google Location Accuracy (F4)

Before running weak-network E2E, **enable Google Location Accuracy in the
emulator settings**:

1. Open the Android emulator settings → Location.
2. Turn on **Location**.
3. Select **Google Location Accuracy** → improve location accuracy (high
   accuracy mode using GPS + Wi-Fi + mobile networks).

Reason: the Google Location Accuracy system dialog is purely platform behavior.
On first location request during an SOS it can surface as a full-screen system
dialog that covers the SOS banner. The SOS flow never loops on or blocks for
that dialog — `LocationService.getCurrentPosition` is a single one-shot request
and, on denial/disable, the flow catches and falls back gracefully rather than
re-requesting. With Google Location Accuracy pre-enabled in the emulator, the
dialog does not re-open on every location request during the SOS path.

## Backend

From the repository root:

```bash
cd backend-go && go run cmd/migrate/main.go up
go run cmd/api/main.go
```

Interactive Swagger UI is served at `http://localhost:8080/docs/*`.
