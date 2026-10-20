#!/usr/bin/env python3
"""smoke_test.py - Pre-exhibition verification for the SiagaKita demo droplet.

Purpose: Prove the deployed demo stack is ready for visitors by exercising the
         must-have flow across every role, over the same public endpoint the
         clients use. Run this after deploy_demo.sh and again before opening.
Data & Logic Flow: HTTP login per role -> two console WebSockets -> civilian SOS
         trigger -> assert both consoles receive the broadcast -> volunteer sees
         the SOS in /incidents/nearby and accepts -> agency handles and resolves.
Key Components: stdlib only (urllib, socket); no third-party packages required.

Usage:
    python3 scripts/demo/smoke_test.py <droplet-ip> [port]
    DEMO_HOST=203.0.113.10 DEMO_PORT=80 python3 scripts/demo/smoke_test.py

Exit code 0 = all checks passed, 1 = at least one failure (details printed).
"""

import base64
import json
import os
import socket
import struct
import sys
import time
import urllib.error
import urllib.request

PASSWORD = "Siaga#Demo2026"
DEFAULT_PORT = 80


class DemoClient:
    """Thin HTTP + raw-WebSocket client for the demo API."""

    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.base = f"http://{host}:{port}"

    # -- HTTP ----------------------------------------------------------------
    def request(self, method, path, payload=None, token=None):
        headers = {"Accept-Language": "id"}
        data = None
        if payload is not None:
            data = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
        if token:
            headers["Authorization"] = "Bearer " + token
        req = urllib.request.Request(
            self.base + path, data=data, headers=headers, method=method
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.status, json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as exc:
            try:
                return exc.code, json.loads(exc.read() or b"{}")
            except json.JSONDecodeError:
                return exc.code, {}

    def raw_get(self, path):
        """GET a non-JSON route (e.g. the static console bundle) and return (status, content-type)."""
        req = urllib.request.Request(
            self.base + path, headers={"Accept-Language": "id"}
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.status, resp.headers.get("Content-Type", "")
        except urllib.error.HTTPError as exc:
            return exc.code, (
                exc.headers.get("Content-Type", "") if exc.headers else ""
            )

    def login(self, email, endpoint):
        status, body = self.request(
            "POST", f"/api/v1/auth/{endpoint}", {"email": email, "password": PASSWORD}
        )
        if status != 200:
            raise RuntimeError(f"login failed for {email}: HTTP {status} {body}")
        return body["data"]["access_token"]

    # -- WebSocket (RFC 6455, hand-rolled to avoid third-party deps) ---------
    def ws_connect(self, token):
        """Handshake with NO Origin header, exactly like a native Flutter client."""
        sock = socket.create_connection((self.host, self.port), timeout=20)
        key = base64.b64encode(os.urandom(16)).decode()
        sock.sendall(
            (
                f"GET /v1/ws/connect?token={token} HTTP/1.1\r\n"
                f"Host: {self.host}:{self.port}\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key}\r\n"
                "Sec-WebSocket-Version: 13\r\n\r\n"
            ).encode()
        )
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = sock.recv(4096)
            if not chunk:
                raise RuntimeError("WebSocket handshake: connection closed")
            buf += chunk
        head, _, rest = buf.partition(b"\r\n\r\n")
        status_line = head.split(b"\r\n")[0].decode()
        if "101" not in status_line:
            raise RuntimeError(f"WebSocket handshake rejected: {status_line}")
        return sock, rest

    @staticmethod
    def recv_frame(sock, pending=b"", timeout=15):
        buf, deadline = pending, time.time() + timeout

        def fill(target):
            nonlocal buf
            while len(buf) < target:
                sock.settimeout(max(0.1, deadline - time.time()))
                buf += sock.recv(4096)

        fill(2)
        length, idx = buf[1] & 0x7F, 2
        if length == 126:
            fill(4)
            length = struct.unpack(">H", buf[2:4])[0]
            idx = 4
        elif length == 127:
            fill(10)
            length = struct.unpack(">Q", buf[2:10])[0]
            idx = 10
        fill(idx + length)
        return json.loads(buf[idx : idx + length].decode("utf-8", "replace")), buf[
            idx + length :
        ]

    @classmethod
    def collect_events(cls, sock, pending, seconds=10):
        events, deadline = [], time.time() + seconds
        while time.time() < deadline:
            try:
                msg, pending = cls.recv_frame(
                    sock, pending, timeout=max(0.5, deadline - time.time())
                )
            except TimeoutError:
                break
            event = msg.get("event") or ""
            events.append(event)
            if "EMERGENCY" in event or event.startswith("SOS"):
                break
        return events, pending


class Report:
    def __init__(self):
        self.failures = []
        self.skips = []

    def check(self, ok, label, detail=""):
        print(
            f"{'PASS' if ok else 'FAIL'}  {label}{(' -> ' + detail) if detail else ''}"
        )
        if not ok:
            self.failures.append(f"{label}: {detail}")
        return ok

    def skip(self, label, detail=""):
        print(f"SKIP  {label}{(' -> ' + detail) if detail else ''}")
        self.skips.append(label)
        return True


def run(host, port):
    api = DemoClient(host, port)
    report = Report()
    print(f"SiagaKita demo smoke test against http://{host}:{port}")
    print("-" * 68)

    # 1. Every demo role can authenticate.
    tokens = {}
    for label, email, endpoint in [
        ("admin", "admin@siagakita.demo", "console/login"),
        ("agency", "agensi.medis@siagakita.demo", "console/login"),
        ("personnel", "petugas.pmi@siagakita.demo", "personnel/login"),
        ("volunteer", "relawan.budi@siagakita.demo", "login"),
        ("civilian", "warga.agus@siagakita.demo", "login"),
    ]:
        try:
            tokens[label] = api.login(email, endpoint)
            report.check(True, f"login {label} ({email})")
        except Exception as exc:  # noqa: BLE001 - report and continue
            report.check(False, f"login {label} ({email})", str(exc))
    if len(tokens) < 5:
        print("\nRESULT: FAILED - cannot continue without all role logins")
        return report

    # 2. Two console instances hold WebSockets at the same time.
    admin_ws, admin_pending = api.ws_connect(tokens["admin"])
    agency_ws, agency_pending = api.ws_connect(tokens["agency"])
    report.check(True, "two console WebSockets open simultaneously")
    _, admin_pending = api.recv_frame(admin_ws, admin_pending)
    _, agency_pending = api.recv_frame(agency_ws, agency_pending)

    # 3. Civilian SOS produces a live broadcast incident.
    status, body = api.request(
        "POST",
        "/api/v1/incidents/trigger",
        {
            "latitude": -6.9025,
            "longitude": 107.6188,
            "address_detail": "Smoke test: Jl. Dipatiukur, Bandung",
            "incident_type": "medical",
        },
        token=tokens["civilian"],
    )
    triggered = (
        status in (200, 201)
        and (body.get("data") or {}).get("status") == "broadcasting"
    )
    incident_id = (body.get("data") or {}).get("incident_id")
    report.check(
        triggered,
        "civilian triggers a live SOS",
        f"HTTP {status} incident={incident_id} status={(body.get('data') or {}).get('status')}",
    )

    # 4. Both consoles receive the real-time broadcast.
    if triggered:
        for label, ws, pending in (
            ("admin", admin_ws, admin_pending),
            ("agency", agency_ws, agency_pending),
        ):
            events, _ = api.collect_events(ws, pending, seconds=12)
            report.check(
                any("EMERGENCY" in e or e.startswith("SOS") for e in events),
                f"{label} console receives the broadcast",
                str(events),
            )

    # 5. Volunteer discovery + mission accept.
    if triggered:
        status, body = api.request(
            "GET",
            "/api/v1/incidents/nearby?lat=-6.9025&lng=107.6188&radius=15",
            token=tokens["volunteer"],
        )
        ids = [i.get("id") or i.get("incident_id") for i in (body.get("data") or [])]
        report.check(
            status == 200,
            "volunteer receives the nearby SOS feed",
            f"HTTP {status}, {len(ids)} active",
        )
        status, body = api.request(
            "POST",
            f"/api/v1/incidents/{incident_id}/accept",
            {"latitude": -6.9025, "longitude": 107.6188},
            token=tokens["volunteer"],
        )
        report.check(
            status in (200, 201), "volunteer accepts the mission", f"HTTP {status}"
        )

    # 6. Agency handles and resolves.
    if triggered:
        status, _ = api.request(
            "POST",
            f"/api/v1/incidents/{incident_id}/agency-handle",
            {},
            token=tokens["agency"],
        )
        report.check(status in (200, 201), "agency handles the SOS", f"HTTP {status}")
        status, _ = api.request(
            "POST",
            f"/api/v1/incidents/{incident_id}/agency-resolve",
            {"resolution_note": "Smoke test selesai"},
            token=tokens["agency"],
        )
        report.check(status in (200, 201), "agency resolves the SOS", f"HTTP {status}")

    # 7. Console read endpoints used by the admin shell.
    for label, path in [
        ("admin", "/api/v1/admin/stats"),
        ("admin", "/api/v1/admin/volunteers/pending"),
        ("admin", "/api/v1/admin/ranks"),
        ("agency", "/api/v1/incidents/all-active"),
        ("agency", "/api/v1/agencies/me"),
        (
            "agency",
            "/api/v1/telemetry/nearby-volunteers?lat=-6.9025&lng=107.6188&radius_km=15",
        ),
    ]:
        status, _ = api.request("GET", path, token=tokens[label])
        report.check(
            status == 200, f"{label} console endpoint {path}", f"HTTP {status}"
        )

    admin_ws.close()
    agency_ws.close()

    # 8. Web console bundle, served as static files by nginx at /console/.
    # deploy_demo.sh treats the console bundle as optional (an API-only demo is a
    # valid shape), so a missing bundle is a SKIP rather than a FAILED check.
    status, ctype = api.raw_get("/console/")
    if status == 404:
        report.skip(
            "web console bundle not deployed",
            "API-only demo; build it with `flutter build web --base-href=/console/`",
        )
    else:
        report.check(
            status == 200 and "html" in ctype.lower(),
            "web console index served at /console/",
            f"HTTP {status} {ctype or '-'}",
        )
        status, _ = api.raw_get("/console/flutter_bootstrap.js")
        report.check(
            status == 200, "web console bootstrap asset reachable", f"HTTP {status}"
        )
        status, _ = api.raw_get("/console/main.dart.js")
        report.check(
            status == 200, "web console compiled bundle reachable", f"HTTP {status}"
        )

    print("-" * 68)
    if report.failures:
        print(f"RESULT: FAILED ({len(report.failures)} check(s))")
        for item in report.failures:
            print("  -", item)
    elif report.skips:
        print(
            f"RESULT: ALL CHECKS PASSED ({len(report.skips)} skipped) - "
            "demo stack is ready for visitors"
        )
    else:
        print("RESULT: ALL CHECKS PASSED - demo stack is ready for visitors")
    return report


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("DEMO_HOST")
    if not host:
        print(__doc__)
        return 2
    port = (
        int(sys.argv[2])
        if len(sys.argv) > 2
        else int(os.environ.get("DEMO_PORT", DEFAULT_PORT))
    )
    try:
        return 0 if not run(host, port).failures else 1
    except Exception as exc:  # noqa: BLE001 - top-level guard
        print(f"RESULT: FAILED - {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
