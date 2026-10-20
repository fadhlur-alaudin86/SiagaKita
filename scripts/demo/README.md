# Exhibition Demo Deployment

Disposable, HTTP-only SiagaKita demo stack on a single DigitalOcean droplet. No TLS, no domain, no Docker Hub, no CI. The backend image is built locally and copied over SSH.

Related plan: [`.planning/14-demo-deploy-digitalocean.md`](../../.planning/14-demo-deploy-digitalocean.md)

Day-of checklist: [`RESTART_AFTER_REBOOT.md`](./RESTART_AFTER_REBOOT.md), what to re-establish after a laptop reboot.

Visitor run-of-show and demo account credentials: [`DEMO_FLOW.md`](./DEMO_FLOW.md).

---

## Prerequisites

- `docker`, `python3`, `ssh`, `scp`, `curl` on the workstation.
- `doctl` installed:
  ```bash
  curl -sSL https://github.com/digitalocean/doctl/releases/latest/download/doctl-$(uname -s | tr '[:upper:]' '[:lower:]')-amd64.tar.gz \
    | sudo tar -xz -C /usr/local/bin doctl
  ```
- A DigitalOcean API token. **Droplets** scope alone is sufficient: `do_create_droplet.sh` detects the missing Firewalls/SSH Keys scopes and falls back to cloud-init (`ufw` inside the droplet plus an injected `authorized_keys`). Add **Firewalls**, **SSH Keys** (read/create), **Images** (read), and **Tags** (create/read) if you want a DO Cloud Firewall and DO-registered keys instead. DigitalOcean cannot re-scope an existing token, so those scopes must be chosen at creation. Write it to `/tmp/opencode/do-token`:

  ```bash
  printf '%s' 'dop_v1_...' > /tmp/opencode/do-token
  chmod 600 /tmp/opencode/do-token
  ```

- `infrastructure/.env.prod` present with the real credentials. It is the source for the generated demo environment.
- An SSH key pair **without a passphrase**; the default is `~/.ssh/id_ed25519_siagakita_demo`. The scripts run SSH with `BatchMode=yes`, so a passphrase-protected key fails with `Permission denied (publickey)`. Generate a dedicated one if needed:

  ```bash
  ssh-keygen -t ed25519 -N '' -C siagakita-demo-droplet -f ~/.ssh/id_ed25519_siagakita_demo
  ```

---

## Deploy

```bash
# 1. Provision firewall + droplet, print the IP
export DO_API_TOKEN=$(cat /tmp/opencode/do-token)
./scripts/demo/do_create_droplet.sh

# 2. Build, ship, migrate, seed, verify
./scripts/demo/deploy_demo.sh <droplet-ip>

# 3. Prove the stack is presentation-ready
python3 scripts/demo/smoke_test.py <droplet-ip> 80
```

A fresh droplet takes roughly 3 to 6 minutes for step 2: Docker installation dominates, followed by the image load (~132 MB compressed) and the migration/seed pass.

### What step 2 does

1. Verifies (or builds) `siagakita-api:1.1.0-demo`.
2. Renders `.env.demo` from `infrastructure/.env.prod`, rewriting only the IP-dependent keys.
3. `docker save | gzip` the backend image.
4. Uploads the image, compose file, Nginx config, seeder, and bootstrap script.
5. Runs `remote_setup.sh` on the droplet: 2 GB swap, Docker Engine, directory layout, `docker load`, **`siagakita-migrate up`**, `compose up`, then the seeder.
6. Verifies `http://<ip>/health` from the workstation.

> [!IMPORTANT]
> The API container does not apply migrations on boot. `deploy_demo.sh` runs `./siagakita-migrate up` explicitly; any manual rebuild must do the same or the backend will fail every query.

---

## Demo accounts

Every account in this table uses one shared demo password. The value is not stored in this repository (it is public): export `SIAGAKITA_DEMO_PASSWORD`, or keep it in the git-ignored `env/demo.secrets.env` that ships in the operator package. The smoke tests read the same two sources and stop with an instruction when neither is present.

| Role | Email | Login endpoint | Used for |
| :--- | :--- | :--- | :--- |
| admin | `admin@siagakita.demo` | `/auth/console/login` | Admin console |
| agency | `agensi.medis@siagakita.demo` | `/auth/console/login` | Second console instance |
| agency | `agensi.damkar@siagakita.demo` | `/auth/console/login` | Fire agency |
| personnel | `petugas.pmi@siagakita.demo` | `/auth/personnel/login` | Responder app |
| personnel | `petugas.damkar@siagakita.demo` | `/auth/personnel/login` | Responder app |
| volunteer | `relawan.budi@siagakita.demo` | `/auth/login` | Citizen app, mission accept |
| volunteer | `relawan.sari@siagakita.demo` | `/auth/login` | Volunteer with a running mission |
| volunteer | `relawan.rina@siagakita.demo` | `/auth/login` | Pending KYC (admin approval demo) |
| civilian | `warga.agus@siagakita.demo` | `/auth/login` | Primary SOS trigger |
| civilian | `warga.dewi@siagakita.demo` | `/auth/login` | Secondary SOS trigger |
| civilian | `warga.wati@siagakita.demo` | `/auth/login` | Owns the seeded active SOS markers; do not use to trigger |

> [!WARNING]
> The backend refuses a new SOS while the reporter has any incident that is not `resolved`, `false_alarm`, or `canceled`, answering "SOS sudah aktif". `warga.agus` and `warga.dewi` are deliberately left with zero active incidents. After a demo run, resolve or cancel the incident from the console before using the same account again, or switch to the other civilian account.

---

## Sharing the build config with teammates

Teammates do not need any credentials to build the apps. Generate a client-only config:

```bash
./scripts/demo/write_client_env.sh <droplet-ip>
# writes env/demo.env
```

Then anyone with the repository does:

```bash
cd mobile-flutter            && flutter build apk --release   --dart-define-from-file=../env/demo.env
cd mobile-flutter-responder  && flutter build apk --release   --dart-define-from-file=../env/demo.env
cd windows_console_flutter   && flutter build linux --release --dart-define-from-file=../env/demo.env
```

`env/demo.env` contains public endpoints and no secrets, so it is safe to send to a teammate. It is nevertheless gitignored (`env/*.env`) because the host inside it is a throwaway droplet IP that stops existing at teardown; regenerate it with `write_client_env.sh` instead of committing it. It carries five keys because the clients read different variables:

| Key | Read by |
| :--- | :--- |
| `API_BASE_URL`, `WS_BASE_URL` | `mobile-flutter`, `windows_console_flutter` |
| `API_HOST`, `API_PORT`, `WS_PORT` | `mobile-flutter-responder` (composes the URL itself; it has no `API_BASE_URL` support) |

> [!WARNING]
> `docs/DEPLOYMENT_GUIDE.md`, `docs/README.md`, `README.md`, and `docs/SETUP.md` instruct readers to pass `--dart-define-from-file=../infrastructure/.env.prod` directly. That file holds the database password, `JWT_SECRET`, Gmail OAuth tokens, and the Firebase service-account private key. Flutter ignores the unknown keys, so it builds fine, but anyone following those instructions is handed production secrets. Use `env/demo.env` or a client-only file instead, and never send `infrastructure/.env.prod` to a teammate.

---

## Web console (no install required)

The desktop console also builds for the web and is served by the droplet itself, so a laptop needs nothing installed.

```bash
cd windows_console_flutter
flutter build web --release --base-href=/console/ --no-web-resources-cdn \
  --dart-define-from-file=../env/demo.env
```

`deploy_demo.sh` uploads `windows_console_flutter/build/web` to `/opt/siagakita/console-web` whenever it exists, and nginx serves it under `/console/`.

### Reaching the web console from a browser

Open the console through an SSH tunnel, not through the droplet IP:

```bash
ssh -i ~/.ssh/id_ed25519_siagakita_demo -o ServerAliveInterval=15 -N \
  -L 8080:127.0.0.1:80 root@<ip>
```

| Console | URL | Account |
| :--- | :--- | :--- |
| Admin | `http://localhost:8080/console/` | `admin@siagakita.demo` |
| Agency | `http://127.0.0.1:8080/console/` | `agensi.medis@siagakita.demo` |

`http://<ip>/console/` serves the bundle correctly but cannot log in: the console
persists its JWT with `flutter_secure_storage`, whose web implementation throws
`UnsupportedError` when `window.isSecureContext` is false, and an HTTP origin on a
bare IP is not a secure context. The failure surfaces as the red banner
"Koneksi gagal. Pastikan server berjalan." on an otherwise working login screen.
`http://localhost` and `http://127.0.0.1` are secure contexts, so the tunnel is what
makes the browser console usable. Using two different hostnames also gives each
console its own browser origin, hence its own token storage, so the second login
cannot overwrite the first console's session.

Four requirements are easy to get wrong:

| Requirement | Why it is needed |
| :--- | :--- |
| `--base-href=/console/` | Flutter defaults to `<base href="/">`, so the bundle would request `/main.dart.js` and 404 under `/console/`. |
| `--no-web-resources-cdn` | Bundles CanvasKit into `build/web/` instead of fetching it from a Google CDN on first paint, a venue with flaky internet does not stall the UI. |
| `CORS_ALLOWED_ORIGINS` must list every console origin | `backend-go/internal/ws/handler.go` compares the `Origin` header literally, so `*` never matches a browser and the console's WebSocket handshake would be rejected. `deploy_demo.sh` renders `http://<ip>`, `http://localhost:8080`, and `http://127.0.0.1:8080`. |
| A secure-context origin reaches the console | See the tunnel above. Only the browser is affected; the Android and desktop clients use the platform keystore and send no `Origin` header at all. |

To verify the browser path end to end, drive the real console UI and assert that its
own WebSocket receives the emergency broadcast:

```bash
python3 scripts/demo/smoke_test_console.py http://localhost:8080/console/ \
  --api-base http://localhost:8080/api/v1
```

This needs Playwright (`pip install playwright`) plus a Chrome or Brave binary. It
logs in through the form, triggers a live SOS over the API, waits for
`INCOMING_EMERGENCY` on the browser socket, and then resolves the incident so the
trigger account is free again.

Making `CORS_ALLOWED_ORIGINS` a concrete list does not affect the native clients: the Android apps and the desktop build send no `Origin` header at all, and the upgrader allows that unconditionally.

Map tiles still come from OpenStreetMap over the internet, so the venue needs outbound internet for the map to draw. Everything else, API, WebSocket, console bundle, CanvasKit, is served from the droplet.

---

## Building the clients against the droplet

`./scripts/demo/write_client_env.sh <ip>` generates `env/demo.env`, and adding `--dart-define-from-file=../env/demo.env` to each command below is equivalent to the explicit flags. Both forms are shown because the flags are useful when you only want to override one key.

```bash
IP=<droplet-ip>

# Citizen app
cd mobile-flutter
flutter build apk --release \
  --dart-define=API_BASE_URL=http://$IP/api/v1 \
  --dart-define=WS_BASE_URL=ws://$IP/v1/ws/connect

# Responder app
cd ../mobile-flutter-responder
flutter build apk --release \
  --dart-define=API_HOST=$IP --dart-define=API_PORT=80 --dart-define=WS_PORT=80

# Desktop console
cd ../windows_console_flutter
flutter build linux --release \
  --dart-define=API_BASE_URL=http://$IP/api/v1 \
  --dart-define=WS_BASE_URL=ws://$IP/v1/ws/connect
```

Both Android packages use distinct application IDs (`com.siagakita.app.mobile` and `com.siagakita.app.responder`), so they install side by side on one phone. Both manifests set `android:usesCleartextTraffic="true"`, which HTTP requires.

To run two console instances from one release build:

```bash
cd windows_console_flutter/build/linux/x64/release/bundle
./siagakita_console &   # log in as admin@siagakita.demo
./siagakita_console &   # log in as agensi.medis@siagakita.demo
```

---

## Operating

```bash
ssh -i ~/.ssh/id_ed25519_siagakita_demo root@<ip>

# Every compose call must pass --env-file: docker-compose.demo.yml interpolates
# ${DB_USER} and friends, and env_file: alone does not supply those values.
docker compose --env-file /opt/siagakita/.env.demo -f /opt/siagakita/docker-compose.demo.yml ps
docker logs --tail 100 siagakita_backend
docker exec -it siagakita_postgres psql -U siagakita_admin -d siagakita
```

Useful queries:

```sql
-- Active SOS currently on the console map
SELECT id, incident_type, status, address_detail, created_at
FROM incidents WHERE status NOT IN ('resolved','false_alarm','canceled')
ORDER BY created_at DESC;

-- Free the primary trigger account after a run
UPDATE incidents SET status = 'canceled', updated_at = now()
WHERE reporter_id = '11111111-1111-4111-8111-000000000008'
  AND status NOT IN ('resolved','false_alarm','canceled');
```

Re-running `deploy_demo.sh <ip>` is safe: the image load is skipped when the tag already exists, migrations are versioned, and the seeder uses fixed UUIDs with `ON CONFLICT DO NOTHING`.

Re-seeding by hand:

```bash
scp -i ~/.ssh/id_ed25519_siagakita_demo scripts/demo/seed_demo_data.sql root@<ip>:/opt/siagakita/
ssh -i ~/.ssh/id_ed25519_siagakita_demo root@<ip> 'docker exec -i siagakita_postgres sh -c \
  '"'"'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'"'"' \
  < /opt/siagakita/seed_demo_data.sql'
```

---

## Before opening the doors

1. `python3 scripts/demo/smoke_test.py <ip> 80`, every check must pass.
2. `python3 scripts/demo/smoke_test_console.py http://localhost:8080/console/`, the browser console must log in and receive the emergency broadcast.
3. Confirm both civilian trigger accounts report zero active SOS.
4. Start the console tunnel (see [RESTART_AFTER_REBOOT.md](./RESTART_AFTER_REBOOT.md), step 2) and open `http://localhost:8080/console/` as the admin plus `http://127.0.0.1:8080/console/` as the agency; confirm the map shows the seeded markers.
5. Trigger one SOS from the phone and confirm both console tabs alert.
6. Resolve that incident so the phone account is free again.

---

## Teardown

```bash
export DO_API_TOKEN=$(cat /tmp/opencode/do-token)
./scripts/demo/destroy_droplet.sh          # asks for the droplet name
# or, when nothing interactive is available:
./scripts/demo/destroy_droplet.sh --yes
```

The script deletes the droplet, deletes the `siagakita-demo-fw` Cloud Firewall when the `firewall` strategy was used, and then polls the droplet list to prove the name is gone, so "destroyed" is a checked claim rather than a fire-and-forget API call.

With the `userdata` strategy there is no DigitalOcean-side firewall to delete: the boundary is `ufw` inside the droplet, which disappears with it. Billing is per second, so destroying the droplet is the only step needed to stop charges.
