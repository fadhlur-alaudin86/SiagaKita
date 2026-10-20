# Plan 14: Exhibition Demo Deployment on DigitalOcean

## 1. Overview & Problem Statement

- **Target**: First stable release point `v1.1.0`, backed by a temporary public demo environment for the SiagaKita exhibition.
- **Problem**:
  1. The exhibition runs for two days and needs a **publicly reachable** backend. There is no production domain, TLS certificate, or CI/CD secret set up, and no droplet exists yet.
  2. The standard delivery path (`.github/workflows/release-deploy.yml`) pushes an image to Docker Hub and deploys over SSH to `VPS_HOST`. Both are unconfigured, so pushing a `v*.*.*` tag would start a pipeline that fails at the Docker Hub login step.
  3. The three Flutter clients are built with hardcoded endpoints injected at compile time (`String.fromEnvironment('API_BASE_URL')`). Without a stable public address, the APKs and desktop console cannot be demonstrated to visitors.
  4. Demo credibility requires realistic data (accounts across all roles, agencies, live SOS markers, pending KYC) instead of an empty database.

- **Goal**: Stand up a disposable, HTTP-only demo stack on a single droplet within the exhibition window, seed it with presentation-ready data, and cut the first release tag **without** triggering the unfinished deployment pipeline.

- **Non-goals**:
  - No TLS, no domain, no Cloudflare origin certificate. HTTP over the droplet IP only.
  - No Docker Hub publishing, no GitHub Secrets, no CI/CD run for this deployment.
  - No iOS build (the iPad only plays advertising video/web content).
  - Production `nginx.conf` and `docker-compose.prod.yml` remain untouched.

---

## 2. Technical Scope & Specifications

### 2.1 Droplet Sizing and Cost

| Item | Value |
| :--- | :--- |
| Provider / region | DigitalOcean, `sgp1` (Singapore) |
| Size | `s-1vcpu-2gb`, 1 vCPU, 2 GB RAM, 50 GB SSD |
| Price | $12/month, $0.01786/hour, per-second billing |
| Image | Ubuntu 24.04 LTS |
| Exposure | Inbound TCP 22 (workstation IP) and TCP 80 (world) via DO Cloud Firewall |
| Lifecycle | Destroyed after the exhibition; no backups enabled |
| Monitoring | `--enable-monitoring` (free basic metrics, useful to confirm teardown) |
| Kernel tuning | `net.core.somaxconn=1024` during bootstrap, so a burst of Flutter clients does not overflow the listen backlog |

A 2 GB droplet is the smallest size that comfortably runs PostgreSQL 15, Redis 7, the Go backend, and Nginx together. A 2 GB swapfile is created during bootstrap as headroom against the Go GC and PostgreSQL shared buffers.

### 2.2 Why a Separate Compose File

`docker-compose.demo.yml` is standalone rather than an override of `docker-compose.prod.yml` because Docker Compose merges volume lists for the same container target path non-deterministically. The demo needs a different Nginx config mounted at `/etc/nginx/nginx.conf` while dropping the `./ssl` mount entirely; overriding that reliably is not guaranteed by Compose merge semantics.

| Concern | `docker-compose.prod.yml` | `docker-compose.demo.yml` |
| :--- | :--- | :--- |
| Backend image | Docker Hub `${DOCKERHUB_USERNAME}/siagakita-api` | local `siagakita-api:${IMAGE_TAG}` |
| Nginx config | `nginx.conf` (TLS + 443 redirect) | `nginx.demo.conf` (HTTP only) |
| Published ports | 80, 443 | 80 |
| TLS volume | `./ssl` mounted | none |
| Env file | `.env.prod` | `.env.demo` |

**Compose interpolation requires `--env-file`.** Docker Compose resolves `${...}` in the YAML in two independent stages, and only one of them consults `env_file:`:

| Mechanism | Source |
| :--- | :--- |
| `env_file:` in the service definition | injects variables into the **container** environment |
| `${VAR}` written in the YAML | interpolated by the **compose CLI** from the shell environment plus the project-directory `.env` |

Because the demo file is named `.env.demo` rather than `.env`, the second stage finds nothing, and `${DB_USER}`, `${DB_PASSWORD}`, `${DB_NAME}`, and `${REDIS_PASSWORD}` all resolve to empty strings. PostgreSQL then aborts with `Database is uninitialized and superuser password is not specified` while Redis starts without a password. `remote_setup.sh` therefore passes `--env-file "$APP_DIR/.env.demo"` on every Compose call through a single `dc()` wrapper, and pre-flight asserts those four keys exist so the failure surfaces immediately rather than as a confusing PostgreSQL init error.

This is the mechanism by which the production workflow gets away without the flag: it exports `DOCKERHUB_USERNAME` and `IMAGE_TAG` into the shell and only ever runs `up -d --no-deps backend`, so no service that needs `${DB_USER}` is ever interpolated.

### 2.3 Image Transport

The backend image is built on the workstation and moved with `docker save | gzip` -> `scp` -> `docker load`. No registry credentials are involved, which keeps the demo independent of Docker Hub availability and of GitHub Actions.

### 2.4 Migration Handling (critical)

The API container **does not auto-migrate**. `backend-go/Dockerfile` ships two binaries: `siagakita-api` (the server) and `siagakita-migrate` (a CLI). Schema changes are therefore an explicit deployment step:

```
docker compose -f docker-compose.demo.yml run --rm --no-deps backend ./siagakita-migrate up
```

Skipping this leaves the database empty and the backend failing every query.

### 2.5 Demo Environment Rendering

`infrastructure/.env.demo` is generated per droplet from the operator's existing `infrastructure/.env.prod` (which already holds the real database, Redis, JWT, Gmail OAuth, and Firebase credentials). Only the following keys are rewritten:

| Key | Demo value |
| :--- | :--- |
| `API_HOST` | droplet IP |
| `API_BASE_URL` | `http://<ip>:80/api/v1` |
| `WS_BASE_URL` | `ws://<ip>:80/v1/ws/connect` |
| `UPLOAD_BASE_URL` | `http://<ip>:80/uploads` |
| `CORS_ALLOWED_ORIGINS` | `http://<ip>,http://localhost:8080,http://127.0.0.1:8080` (see 2.9 for why `*` cannot work) |
| `IMAGE_TAG` | `1.1.0-demo` |
| `DOCKERHUB_USERNAME` | empty (unused) |

`GO_ENV=production` is retained so the demo behaves like the real service rather than enabling the development-only Swagger mount and open WebSocket origin check.

> [!WARNING]
> `.env.demo` is git-ignored (`infrastructure/.env.*`). It is generated into `/tmp/opencode/siagakita-demo-stage`, never committed, and only ever copied to the droplet over SSH.

### 2.6 Demo Seed Data

`scripts/demo/seed_demo_data.sql` is a standalone, idempotent SQL file (fixed UUIDs + `ON CONFLICT DO NOTHING`) executed after migrations. All demo accounts share one demo password supplied out of band. Only its bcrypt hash (cost 12, matching the application's `user` service) is committed, so the seeder stays self-contained while the plaintext never enters the public repository. The checks read `SIAGAKITA_DEMO_PASSWORD` or the git-ignored `env/demo.secrets.env`.

| Role | Account | Purpose |
| :--- | :--- | :--- |
| `admin` | `admin@siagakita.demo` | Admin console: stats, KYC queue, users, ranks |
| `agency` | `agensi.medis@siagakita.demo` | Second console instance: dispatch and handling |
| `agency` | `agensi.damkar@siagakita.demo` | Fire agency login |
| `agency_personnel` | `petugas.pmi@siagakita.demo` | Responder app mission board |
| `agency_personnel` | `petugas.damkar@siagakita.demo` | Second responder |
| `volunteer` | `relawan.budi@siagakita.demo` | Verified volunteer, nearby SOS feed |
| `volunteer` | `relawan.sari@siagakita.demo` | Verified volunteer with a running mission |
| `volunteer` | `relawan.rina@siagakita.demo` | Pending KYC, for the admin approval demo |
| `civilian` | `warga.agus@siagakita.demo` | Primary SOS trigger account |
| `civilian` | `warga.dewi@siagakita.demo` | Secondary SOS trigger account |
| `civilian` | `warga.wati@siagakita.demo` | Passive reporter owning all seeded active SOS |

**Design constraint discovered during rehearsal.** `incident.Repository.FindActiveByReporter` rejects a new SOS while the reporter has any incident whose status is not `resolved`, `false_alarm`, or `canceled`, returning "SOS sudah aktif". Seeding active incidents onto `warga.agus` or `warga.dewi` would therefore make the live SOS demonstration impossible. All seeded *active* incidents are owned by `warga.wati`, leaving both trigger accounts free; the resolved and canceled history rows stay on `agus` and `dewi` so their history screens are populated.

Seeded incidents cover `broadcasting` (2), `grace_period` (1), `handling` (1), `resolved` (1), and `canceled` (1), plus three non-emergency citizen reports (`sent`, `processing`, `resolved`). Coordinates are centered on Bandung.

`m_ranks` is not seeded by any migration, so the file inserts four ranks and advances its sequence. `m_badges` is already seeded by migration 022 with 17 rows; the seeder only guards on it being non-empty.

### 2.7 Release Point

The first release point is tag `v1.1.0` on `dev`. Because `release-deploy.yml` triggers on `v*.*.*` and requires Docker Hub plus VPS secrets that do not exist, the workflow is **disabled** before tagging and re-enabled when the pipeline is actually wired:

```
gh workflow disable release-deploy.yml
# bump VERSION and any manifests, commit the release prep, then:
git tag -a v1.1.0 -m "SiagaKita v1.1.0"
git push origin dev
git push origin v1.1.0
gh workflow enable release-deploy.yml
gh release create v1.1.0 --title "SiagaKita v1.1.0" --notes-file <changelog>
```

Order matters: the tag push is the last action taken while the workflow is disabled. The workflow is re-enabled only after the tag exists, and the GitHub Release is created manually afterwards so the changelog reflects the exhibition milestone rather than an automated run.

### 2.8 Provisioning Constraints (discovered against the real account)

The DigitalOcean API token available for this deployment is scoped to **Droplets only**. DigitalOcean does not allow editing the scopes of an existing token, and the following were rejected with HTTP 403:

| Operation | Required scope | Result |
| :--- | :--- | :--- |
| `compute ssh-key list` / `import` | SSH Keys | 403 Forbidden |
| `compute firewall list` / `create` | Firewalls | 403 Forbidden |
| `--tag-names` on create | Tags | 403 Forbidden |
| `account get` | Account | 403 Forbidden |

Consequences and the resulting design:

1. **No DO Cloud Firewall.** `do_create_droplet.sh` selects a host-firewall strategy automatically: `firewall` when the Firewalls and SSH Keys scopes are present, otherwise `userdata`. In `userdata` mode the boundary is `ufw` inside the droplet, allowing only 22/tcp and 80/tcp. PostgreSQL, Redis, and the backend are published only on the private Docker network, so the practical exposure is identical.
2. **No DO-registered SSH key.** The public key is injected through cloud-init `write_files` into `/root/.ssh/authorized_keys`, plus the top-level `ssh_authorized_keys` for the `ubuntu` user as a backup path. Ubuntu cloud images do **not** apply `ssh_authorized_keys` to `root`, so writing root's key explicitly is required.
3. **No tags.** Cosmetic only; dropped.

> [!IMPORTANT]
> SSH source restriction is best-effort. The script pins 22/tcp to the workstation's egress IP when it can resolve one. If that lookup fails (for example when tethering), it falls back to `0.0.0.0/0` and prints a loud multi-line warning rather than failing the deployment, because a lockout during an exhibition is worse than a key-only port open for 48 hours. Root password authentication stays disabled in both cases. Set `SSH_ALLOWED_SOURCES=<ip>/32` to pin it explicitly.

Three further failure modes were hit and fixed during provisioning. They are recorded because each one is silent and costs a droplet rebuild:

- **A passphrase-protected SSH private key is unusable.** The scripts run SSH with `BatchMode=yes`, which cannot prompt, so every call returns `Permission denied (publickey)` with no hint that a passphrase is the cause. A dedicated passphrase-free key is now the default (`~/.ssh/id_ed25519_siagakita_demo`), and `do_create_droplet.sh` refuses to start if the configured key needs a passphrase.
- **Expired root password from DigitalOcean.** With no `--ssh-keys` argument, DigitalOcean provisions a random root password and marks it expired. sshd's PAM account phase then rejects *every* session, including key-based ones, with `You are required to change your password immediately`. cloud-init clears this with `chage -d "$(date +%F)" -M 99999 root`. Note that this error is not an authentication failure, which is why the key appeared to be the problem.
- **Escaping can silently corrupt cloud-init YAML.** The first attempt embedded `printf '%s\n'` inside a YAML double-quoted scalar; YAML turned `\n` into a real newline and the command became invalid, so the key was never installed. User-data is now written from a quoted heredoc and validated as YAML (structure plus key content) before the droplet is created. `DRY_RUN=1` stops after validation.

### 2.9 Web Console for the macOS Laptop

The exhibition plan calls for two console instances on a macOS laptop. The console's `macos/` target has never been built, there is no `Podfile` or `Podfile.lock` in any client, so a first-time native macOS build would begin with a cold CocoaPods dependency resolve inside a 20 to 40 minute window. That is not a risk worth carrying into an exhibition.

Instead the console is served as a Flutter **web** bundle from the droplet, so a laptop needs nothing installed and two browser tabs provide the admin and agency consoles side by side:

```bash
flutter build web --release --base-href=/console/ --no-web-resources-cdn \
  --dart-define-from-file=../env/demo.env
```

| Decision | Reason |
| :--- | :--- |
| `--base-href=/console/` | Flutter writes `<base href="/">` by default, so a bundle mounted under `/console/` would request its own assets from the site root and 404. |
| `--no-web-resources-cdn` | Places CanvasKit under `build/web/canvaskit/`. The default fetches it from a Google CDN at first paint, which couples the demo to venue internet for the UI shell itself. |
| `CORS_ALLOWED_ORIGINS` becomes a concrete list | `CheckOrigin` in `backend-go/internal/ws/handler.go` compares the header literally (`strings.TrimSpace(allowed) == origin`), so `*` never matches a browser. A browser console would fail its WebSocket handshake and appear to connect but never alert. |
| The browser reaches the console at `http://localhost:8080`, not `http://<ip>` | `flutter_secure_storage`'s web implementation throws `UnsupportedError` when `window.isSecureContext` is false (verified in `flutter_secure_storage_web-2.1.1`, the `_crypto` getter). An HTTP origin on a bare IP is not a secure context, but `http://localhost` is. Serving the bundle from the bare IP therefore loads the login screen and then fails on submit, because `AuthService.login` writes the token through secure storage and throws before navigating. The symptom is the red banner "Koneksi gagal. Pastikan server berjalan." on an otherwise healthy server, which is easy to misdiagnose as an outage. An SSH tunnel (`-L 8080:127.0.0.1:80`) supplies a secure context. |

Two console instances need separate token storage, and both tabs on one origin would
share `localStorage`. The two consoles therefore use different hostnames:
`http://localhost:8080/console/` for admin and `http://127.0.0.1:8080/console/` for
agency. Distinct origins give each console its own storage, so the second login
cannot overwrite the first console's session. Both origins are rendered into
`CORS_ALLOWED_ORIGINS`.

The nginx demo config therefore gains a `location /console/` that serves the uploaded bundle from `/opt/siagakita/console-web`, and `docker-compose.demo.yml` mounts that directory read-only into the nginx container.

Native clients are unaffected by the origin change: they send no `Origin` header, and the upgrader returns `true` for that case before any list check.

---

## 3. Tasks & Implementation Checklist

### 3.1 Artifacts

- [x] `infrastructure/nginx/nginx.demo.conf` - HTTP-only reverse proxy for REST, WebSocket, uploads, health, and the static `/console/` bundle. A `/docs/` location is proxied too, but `GO_ENV=production` means the backend never mounts Swagger, so it answers 404 in the demo.
- [x] `infrastructure/docker-compose.demo.yml` - standalone demo stack.
- [x] `scripts/demo/seed_demo_data.sql` - idempotent demo seeder.
- [x] `scripts/demo/do_create_droplet.sh` - firewall, SSH key, and droplet provisioning.
- [x] `scripts/demo/deploy_demo.sh` - image export, env rendering, upload, remote bootstrap, health verification.
- [x] `scripts/demo/remote_setup.sh` - droplet bootstrap: swap, Docker, directories, image load, migrate, compose up, seed.
- [x] `scripts/demo/smoke_test.py` - cross-role pre-exhibition verification (22 checks; the three `/console/` checks report SKIP when the bundle is not deployed).
- [x] `scripts/demo/smoke_test_console.py` - browser-driven console verification: real login plus `INCOMING_EMERGENCY` over the browser's own WebSocket.
- [x] `scripts/demo/destroy_droplet.sh` - teardown with an explicit confirmation plus a post-delete verification poll.
- [x] `scripts/demo/write_client_env.sh` - emits the shareable five-key client config at `env/demo.env` (generated, then git-ignored because it embeds the throwaway droplet IP).
- [x] `scripts/demo/README.md` - operator runbook, accounts, web console access, teardown.
- [x] `scripts/demo/DEMO_FLOW.md` - visitor run-of-show plus the demo credential card.
- [x] `scripts/demo/RESTART_AFTER_REBOOT.md` - day-of checklist for re-establishing laptop-side access.

### 3.2 Execution

- [x] Create the DigitalOcean API token and write it to `/tmp/opencode/do-token`.
- [x] Run `do_create_droplet.sh`; record the droplet IP (droplet `siagakita-demo`, id 610356997, `167.71.207.160`, sgp1).
- [x] Run `deploy_demo.sh <ip>`; confirm `http://<ip>/health` responds.
- [x] Run `smoke_test.py <ip>`; 22 checks pass.
- [x] Generate `env/demo.env` with `write_client_env.sh` for teammates.
- [x] Build both Android release APKs against `http://<ip>`.
- [x] Build and upload the Flutter web console; two browser tabs serve as the admin and agency consoles over an SSH tunnel.
- [ ] Rehearse the SOS flow on the real devices once; a browser-driven end-to-end run already passes.
- [ ] Disable `release-deploy.yml`, tag `v1.1.0`, push, re-enable, publish the GitHub Release manually.
- [ ] Destroy the droplet after the exhibition with `scripts/demo/destroy_droplet.sh`.

---

## 4. Affected Components & Files

| File | Change |
| :--- | :--- |
| `infrastructure/nginx/nginx.demo.conf` | New, HTTP-only demo proxy |
| `infrastructure/docker-compose.demo.yml` | New, standalone demo stack |
| `scripts/demo/seed_demo_data.sql` | New, idempotent demo seeder |
| `scripts/demo/do_create_droplet.sh` | New, DO provisioning |
| `scripts/demo/deploy_demo.sh` | New, deployment orchestrator |
| `scripts/demo/remote_setup.sh` | New, droplet bootstrap |
| `scripts/demo/smoke_test.py` | New, cross-role verification |
| `scripts/demo/write_client_env.sh` | New, generates the shareable client build config |
| `env/demo.env` | New (generated), client-only endpoints for teammates |
| `scripts/demo/README.md` | New, operator runbook |
| `.planning/README.md` | Catalog entry for this plan |

No production file is modified. `nginx.conf`, `docker-compose.prod.yml`, `docker-compose.yml`, and all backend and client source files are untouched.

---

## 5. Verification & Acceptance Criteria

### 5.1 Local Rehearsal (completed before any droplet spend)

The exact image, schema, seeder, Nginx config, and rendered environment were exercised on a clean PostgreSQL volume on the workstation:

| Check | Result |
| :--- | :--- |
| Backend image `siagakita-api:1.1.0-demo` builds | Pass |
| `siagakita-migrate up` on an empty database reaches version 23 | Pass |
| All four containers reach healthy state | Pass |
| `seed_demo_data.sql` commits and is re-runnable | Pass |
| `GET /health` through the demo nginx | Pass |
| Login as admin, agency, personnel, volunteer, civilian | Pass |
| `warga.agus` and `warga.dewi` have zero active SOS | Pass |
| Civilian SOS creates a new `broadcasting` incident | Pass |
| Two console WebSockets open at once and both receive `INCOMING_EMERGENCY` | Pass |
| Volunteer nearby feed + mission accept | Pass |
| Agency handle + resolve | Pass |
| Six console read endpoints used by the admin/agency shell | Pass |

**Gap the rehearsal did not cover.** The rehearsal invoked Compose with `--env-file` by hand, so it never exercised the interpolation path that the on-droplet script has to reproduce from scratch. That is precisely where the first real deploy failed (see 2.2). The lesson recorded here is that a rehearsal proves the *stack* but not the *invocation*, and the invocation is what a provisioning script actually owns.

### 5.2 On-Droplet Acceptance (verified)

| Check | Result |
| :--- | :--- |
| `http://167.71.207.160/health` returns `{"status":"ok","service":"SiagaKita REST API"}` | Pass |
| `smoke_test.py 167.71.207.160 80` | Pass, 22/22 |
| `siagakita-migrate version` on a fresh database | Pass, version 23 |
| Seeded rows present (11 accounts, 4 agencies, 2 personnel, 3 reports, 5 incidents) | Pass |
| Four containers healthy (`backend`, `nginx`, `postgres`, `redis`) | Pass |
| Civilian SOS reaches **both** console WebSockets as `INCOMING_EMERGENCY` | Pass |
| Volunteer nearby feed, mission accept, agency handle, agency resolve | Pass |
| `ufw` exposes only 22/tcp and 80/tcp | Pass |
| Both Android APKs install and log in against the droplet | Pending, device not yet attached |
| Two console windows connect simultaneously on real hardware | Pending, desktop launch not yet run |

### 5.3 Operational Risks

| Risk | Mitigation |
| :--- | :--- |
| 2 GB RAM pressure during peak demo | 2 GB swapfile created at bootstrap; swapiness set to 10 |
| Droplet IP changes | Demo is disposable; rebuild takes about 5 minutes from a known-good image |
| Mac console build never attempted | Console is demonstrated on the Linux workstation; macOS remains a stretch goal |
| Seeded active SOS blocks the live demo | Active incidents owned by the passive reporter `warga.wati` |
| Tag push triggers the unfinished deploy pipeline | `release-deploy.yml` disabled around the tag push |
