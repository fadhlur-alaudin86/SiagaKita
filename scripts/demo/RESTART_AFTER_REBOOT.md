# Restart Checklist After a Laptop Reboot

The exhibition stack runs on the droplet, not on this laptop. A laptop reboot does
not stop the demo; it only drops the laptop-side access, which is what this
checklist rebuilds. Work through it top to bottom.

Reference state: droplet `siagakita-demo` at `167.71.207.160`, four containers with
`restart: always`, image tag `1.1.0-demo`.

---

## What survives a reboot

| Thing | Survives? | Action |
| :--- | :--- | :--- |
| Droplet and its four containers | Yes, `restart: always` | none |
| Database contents and seed data | Yes, bind mount `./postgres-data` on the droplet disk | none |
| Both apps installed on the phone | Yes | relaunch only |
| SSH tunnel to `localhost:8080` | **No** | restart it, step 2 |
| Browser console tabs | **No** | reopen them, step 3 |
| `adb` server and USB authorization | Usually no | rebuild it, step 4 |
| `/tmp/opencode/do-token` | **No** | only needed for teardown |

---

## 1. Confirm the droplet is still serving

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://167.71.207.160/health
```

Expect `200`. If it does not answer, bring the stack up from inside the droplet:

```bash
ssh -i ~/.ssh/id_ed25519_siagakita_demo root@167.71.207.160
docker compose --env-file /opt/siagakita/.env.demo \
  -f /opt/siagakita/docker-compose.demo.yml up -d
docker ps
```

The `--env-file` flag is mandatory. `env_file:` injects variables into containers
only; the `${DB_USER}`-style placeholders in the compose file are interpolated by
the Compose CLI, which reads the shell environment plus a project-directory
`.env` and never `env_file:`. Without the flag, PostgreSQL starts uninitialized.

---

## 2. Restart the console tunnel

This is the step that matters most. The web console stores its JWT through
`flutter_secure_storage`, and the web implementation of that plugin throws
`UnsupportedError` whenever `window.isSecureContext` is false. A plain-HTTP
origin such as `http://167.71.207.160` is not a secure context, so the console
cannot log in from the droplet IP. `http://localhost` is a secure context, so the
console must be reached through a tunnel:

```bash
ssh -i ~/.ssh/id_ed25519_siagakita_demo -o ServerAliveInterval=15 -N \
  -L 8080:127.0.0.1:80 root@167.71.207.160
```

Leave that terminal open for as long as the console is in use. A dropped tunnel
shows up immediately as a failed login.

Verify the tunnel before opening a browser:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/health
```

---

## 3. Reopen the two console instances

| Console | URL | Account |
| :--- | :--- | :--- |
| Admin | `http://localhost:8080/console/` | `admin@siagakita.demo` |
| Agency | `http://127.0.0.1:8080/console/` | `agensi.medis@siagakita.demo` |

The two hostnames are deliberate. `localhost` and `127.0.0.1` are distinct browser
origins, so each console gets its own token storage and the second login does not
overwrite the first one's session. Both origins are already listed in
`CORS_ALLOWED_ORIGINS` on the droplet, which the backend compares literally
against the `Origin` header during the WebSocket handshake.

A symptom worth recognising: landing back on the login screen with the red banner
"Koneksi gagal. Pastikan server berjalan." means the origin is not a secure
context, not that the server is down. Check that the URL starts with
`http://localhost:8080/` or `http://127.0.0.1:8080/`.

---

## 4. Reconnect the phone

```bash
adb kill-server
adb start-server
adb devices
```

If the list stays empty, replug the cable, switch the USB mode on the phone to
file transfer, and accept the "Allow USB debugging" prompt. Both apps are already
installed, so a reboot only needs them relaunched: "SiagaKita" (civilian and
volunteer) and "SiagaKita Responder" (agency personnel). Only reinstall if one was
removed:

```bash
adb install -r mobile-flutter/build/app/outputs/flutter-apk/app-release.apk
adb install -r mobile-flutter-responder/build/app/outputs/flutter-apk/app-release.apk
```

---

## 5. Prove the whole flow again

```bash
python3 scripts/demo/smoke_test.py 167.71.207.160 80
python3 scripts/demo/smoke_test_console.py http://localhost:8080/console/
```

Every check must pass. The first proves the API, WebSocket, and all five roles; the
second drives the real console UI in a browser and proves it receives the
`INCOMING_EMERGENCY` broadcast. Then confirm the two console tabs show the seeded
markers on the map, trigger one SOS from the phone, watch both tabs alert, and
resolve that incident so the phone account is free again.

---

## 6. Local development containers (not needed for the demo)

The demo runs entirely on the droplet. Only start the local stack if you need the
development environment back:

```bash
cd infrastructure && docker compose up -d
```

---

## Before teardown, after the exhibition

The DigitalOcean API token lived at `/tmp/opencode/do-token` and is gone after the
reboot. Retrieve it again from the DigitalOcean control panel, then:

```bash
./scripts/demo/destroy_droplet.sh          # asks for the droplet name
```

The script reads `/tmp/opencode/do-token`, accepts `DO_API_TOKEN` or
`DIGITALOCEAN_ACCESS_TOKEN`, deletes the `siagakita-demo-fw` Cloud Firewall when
the `firewall` strategy was used, and polls the droplet list to prove the name is
gone. With the `userdata` strategy the boundary is `ufw` inside the droplet and
disappears with it.
