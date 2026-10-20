# Exhibition Demo Flow

A repeatable run-of-show for showing SiagaKita to visitors, plus the credentials for
every demo account. Related: [README.md](./README.md) for deployment and
[RESTART_AFTER_REBOOT.md](./RESTART_AFTER_REBOOT.md) for re-establishing access.

---

## Credentials

Every demo account shares one password. These accounts exist only on the disposable
exhibition droplet and are destroyed with it.

> **Password for all accounts: one shared demo password, supplied out of band.**
>
> It is deliberately absent from this repository, which is public. The printed
> credential card in the operator package carries the value; here it is read from
> `SIAGAKITA_DEMO_PASSWORD` (or the git-ignored `env/demo.secrets.env`), which is
> also what `smoke_test.py` and `smoke_test_console.py` expect.

| # | Role | Email | Signs in on | Lands on |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Civilian | `warga.agus@siagakita.demo` | SiagaKita | Beranda, ready to trigger |
| 2 | Civilian | `warga.dewi@siagakita.demo` | SiagaKita | Spare trigger for the next run |
| 3 | Civilian | `warga.wati@siagakita.demo` | SiagaKita | Already owns the seeded live markers |
| 4 | Volunteer | `relawan.budi@siagakita.demo` | SiagaKita | Operasi, accepts a nearby mission |
| 5 | Volunteer | `relawan.sari@siagakita.demo` | SiagaKita | Already on a running mission |
| 6 | Volunteer | `relawan.rina@siagakita.demo` | SiagaKita | Pending verification, for the approval demo |
| 7 | Agency personnel | `petugas.pmi@siagakita.demo` | SiagaKita Responder | Mission board |
| 8 | Agency personnel | `petugas.damkar@siagakita.demo` | SiagaKita Responder | Spare unit |
| 9 | Agency operator | `agensi.medis@siagakita.demo` | Agency console | Dashboard Operasi |
| 10 | Agency operator | `agensi.damkar@siagakita.demo` | Agency console | Spare agency |
| 11 | Admin | `admin@siagakita.demo` | Admin console | KYC & Verifikasi Relawan |

The SiagaKita app holds one session at a time. Signing in as a volunteer ends the
civilian session, which is the intended single-session policy rather than a fault.

---

## Stage layout

| Device | What runs on it |
| :--- | :--- |
| iPad | Advertising content only |
| Android phone | SiagaKita and SiagaKita Responder, side by side |
| Laptop, tab 1 | Admin console, `http://localhost:8080/console/` |
| Laptop, tab 2 | Agency console, `http://127.0.0.1:8080/console/` |

The two console tabs use different hostnames on purpose: they are separate browser
origins, so the admin and agency sessions keep their own stored tokens. The tunnel
must be running (see [RESTART_AFTER_REBOOT.md](./RESTART_AFTER_REBOOT.md), step 2).

The two consoles have different jobs, which is worth saying out loud to visitors:

- **Agency console** is the live operations room: Dashboard Operasi, SOS Aktif,
  Dispatch Relawan, Laporan Masuk, Peta Operasional, Riwayat.
- **Admin console** is governance: KYC & Verifikasi Relawan, Manajemen Akun,
  Pendaftaran Akun Khusus, Master Data Gamifikasi, Statistik & Analitik.

---

## Main scenario, about four minutes

### 0. Pre-flight

1. Tunnel is up and both console URLs load.
2. Phone: SiagaKita signed in as `warga.agus`, SiagaKita Responder signed in as
   `petugas.pmi`, both apps open side by side.
3. Agency console on **Peta Operasional**. Admin console on **Statistik & Analitik**.
4. `warga.agus` has zero active SOS, so the trigger is free.

### 1. Show the live picture

- Agency console, **Peta Operasional**: the four seeded SOS markers are already on
  the map. Responder markers appear on it as soon as a unit starts streaming its
  position.
- Agency console, **Dashboard Operasi**: open incident counts and today's activity.

Narration: this is a live operations room; every marker is a real record in the
database, not a mock-up.

### 2. Trigger the emergency

- Phone, SiagaKita, **Beranda**: tap the SOS button **three times in quick
  succession**.

The three taps are deliberate, so a pocket press cannot call for help. The button
fills as it counts, then sends. The app then shows the active SOS screen, and the
reporter keeps streaming position.

### 3. The operations room reacts by itself

Nothing is refreshed by hand. The agency console plays its alarm and the badge next
to **SOS Aktif** increments, and the new marker appears on the map.

Narration: the server pushes the event over a WebSocket to every connected console;
there is no polling and no manual reload.

### 4. Agency acknowledges the emergency

- Agency console, **SOS Aktif**: the new incident sits at the top of the list.
- Press **TANGANI**.

The incident is now assigned to the agency, and the reporter is told a team is
coming.

### 5. The citizen is reassured

- Phone, SiagaKita: the warning changes and the app confirms
  "Tim penyelamat sedang dalam perjalanan ke lokasi Anda!".

Narration: the person in danger is not left guessing; status flows back to the same
phone that called for help.

### 6. The field unit moves

- Phone, SiagaKita Responder: the mission board lists the incident. Open it and
  press **Terima Tugas**, then **Tiba di Lokasi** when on scene.
- Agency console, **Peta Operasional**: the unit appears and its position moves.

Narration: the responder's GPS streams to the operations room continuously, so a
dispatcher can watch the approach without any radio traffic.

### 7. Close the incident

Either of these works, and using both shows the two ends of the system:

- Phone, SiagaKita Responder: **Selesai**, then confirm **Ya, Selesai**.
- Agency console, **SOS Aktif**: press **SELESAIKAN**.

The marker leaves the active map, the incident moves into **Riwayat**, and the admin
console's **Statistik & Analitik** numbers follow.

### 8. Reset for the next visitor

- If an incident is still open, close it from the agency console, or run the cancel
  statement in [README.md](./README.md), or
- trigger the next run from `warga.dewi` instead.
- The civilian app enforces a 60-second cooldown between SOS triggers, so give the
  phone a moment before repeating.

---

## Optional add-ons

Pick whichever suits the visitor's interest; each one is short.

| Add-on | Where | What to do |
| :--- | :--- | :--- |
| Approve a volunteer | Admin console, KYC & Verifikasi Relawan | `relawan.rina` is pending; approve it, then sign in as her on the phone to show the volunteer mission list opening up. |
| Volunteer accepts a mission | SiagaKita, Operasi tab, as `relawan.budi` | The nearby SOS list appears; accept one and watch the handover appear on the console. This signs the civilian out, which is itself worth explaining. |
| Citizen reports a non-emergency | SiagaKita, report screen | Creates a Jalur B report, which lands in the agency console's Laporan Masuk. |
| False alarm handling | Agency console, SOS Aktif | **Alarm Palsu** marks an incident as a false alarm, so it leaves the active list without pretending it was resolved. |
| Offline-first SOS | SiagaKita | Enable airplane mode, trigger an SOS, and see it held locally; restore the network and it syncs. Good for demonstrating weak-signal areas. |
| Gamification | Admin console, Master Data Gamifikasi | Badge definitions and volunteer achievements. |

---

## If something looks wrong

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| Login shows "Koneksi gagal. Pastikan server berjalan." | The console is open from an origin the browser does not treat as secure | Open `http://localhost:8080/console/` or `http://127.0.0.1:8080/console/` through the tunnel, never the bare droplet IP |
| "SOS sudah aktif" when triggering | That account already has an open incident | Close it from the agency console, or trigger from `warga.dewi` |
| The console never alerts, but the map works | The tunnel dropped or the WebSocket closed | Restart the tunnel and reload the tab |
| The map is blank or grey | No outbound internet, so OpenStreetMap tiles cannot load | Reconnect the laptop or the phone |
| A phone shows the login screen instead of the app | The session was ended by a sign-in on another device | Sign in again with the same account |
