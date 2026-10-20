"""Verify the served web console in a real browser.

Logs in through the console UI, then triggers a live SOS over the API and asserts
that the browser's own WebSocket receives `INCOMING_EMERGENCY`. This mirrors the
exhibition flow: a phone triggers, the browser console must alert.

The console can only be driven from an origin the browser treats as a secure
context, because its JWT is stored through `flutter_secure_storage`, whose web
implementation throws `UnsupportedError` when `window.isSecureContext` is false.
Run this against an SSH tunnel origin (`http://localhost:8080/console/`) or a
browser launched with `--unsafely-treat-insecure-origin-as-secure`.

Usage:
    python3 scripts/demo/smoke_test_console.py http://localhost:8080/console/ \
        --api-base http://localhost:8080/api/v1

Requires Playwright (`pip install playwright`) and a Chrome or Brave binary.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

from playwright.sync_api import sync_playwright

PASSWORD = "Siaga#Demo2026"
CHROME_CANDIDATES = (
    "/usr/bin/google-chrome-stable",
    "/usr/bin/brave",
    "/usr/bin/chromium",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
)

ROOT_EMAIL = "admin@siagakita.demo"
TRIGGER_EMAIL = "warga.agus@siagakita.demo"
VOLUNTEER_EMAIL = "relawan.budi@siagakita.demo"
AGENCY_EMAIL = "agensi.medis@siagakita.demo"


def find_chrome(explicit: str | None) -> str:
    """Return a usable browser binary, preferring an explicit override."""
    if explicit:
        if not os.path.exists(explicit):
            sys.exit(f"browser binary not found: {explicit}")
        return explicit
    override = os.environ.get("CHROME_PATH")
    if override and os.path.exists(override):
        return override
    for candidate in CHROME_CANDIDATES:
        if os.path.exists(candidate):
            return candidate
    sys.exit("no Chrome or Brave binary found; pass --chrome or set CHROME_PATH")


class Api:
    """Minimal API client used to drive the demo from outside the browser."""

    def __init__(self, base: str) -> None:
        self.base = base.rstrip("/")
        self.results: list[bool] = []

    def call(self, method: str, path: str, payload=None, token: str | None = None):
        headers = {"Accept-Language": "id", "Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        data = json.dumps(payload).encode() if payload is not None else None
        request = urllib.request.Request(
            self.base + path, data=data, headers=headers, method=method
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                raw, status = response.read(), response.status
        except urllib.error.HTTPError as exc:
            raw, status = exc.read(), exc.code
        try:
            return status, json.loads(raw or b"{}")
        except json.JSONDecodeError:
            return status, {"_raw": raw[:300].decode("utf-8", "replace")}

    def login(self, email: str, endpoint: str = "login") -> str:
        status, body = self.call(
            "POST", f"/auth/{endpoint}", {"email": email, "password": PASSWORD}
        )
        if status != 200:
            raise SystemExit(f"login {email} -> HTTP {status} {body}")
        return body["data"]["access_token"]


def check(results: list[bool], ok: bool, label: str, detail: str = "") -> None:
    results.append(bool(ok))
    suffix = f" -> {detail}" if detail else ""
    print(f"{'PASS' if ok else 'FAIL'}  {label}{suffix}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "url", help="console page URL, e.g. http://localhost:8080/console/"
    )
    parser.add_argument(
        "--api-base",
        default=None,
        help="API base URL derived from the page URL when omitted",
    )
    parser.add_argument("--chrome", default=None, help="browser binary to drive")
    parser.add_argument(
        "--timeout",
        type=int,
        default=30,
        help="seconds to wait for the emergency frame",
    )
    args = parser.parse_args()

    api = Api(args.api_base or args.url.split("/console/")[0] + "/api/v1")
    results = api.results

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=find_chrome(args.chrome), args=["--no-sandbox"]
        )
        page = browser.new_page(viewport={"width": 1600, "height": 1000})

        frames: list[str] = []
        sockets: list[str] = []
        page_errors: list[str] = []
        auth_calls: list[tuple[str, int]] = []

        page.on(
            "websocket",
            lambda ws: (
                sockets.append(ws.url),
                ws.on("framereceived", lambda payload: frames.append(str(payload))),
            ),
        )
        page.on("pageerror", lambda error: page_errors.append(str(error)))
        page.on(
            "response",
            lambda response: (
                auth_calls.append((response.url.split("/api/v1")[-1], response.status))
                if "/auth/" in response.url
                else None
            ),
        )

        page.goto(args.url, wait_until="load", timeout=60_000)
        page.wait_for_timeout(9_000)

        check(
            results,
            page.evaluate("window.isSecureContext") is True,
            "page origin is a secure context",
            args.url,
        )
        check(
            results,
            page.evaluate("typeof (window.crypto && window.crypto.subtle)") == "object",
            "crypto.subtle is available to flutter_secure_storage_web",
        )

        # Flutter only builds its accessibility tree once the placeholder is
        # activated, and only real key events reach the canvas-rendered fields.
        page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
        page.wait_for_timeout(2_500)

        inputs = page.locator("flt-semantics input")
        count = inputs.count()
        check(
            results, count >= 2, "login form exposes two text fields", f"found {count}"
        )

        def type_into(field, text: str) -> bool:
            """Type into a field, retrying because the first keystroke can be lost."""
            for attempt in range(4):
                field.click()
                page.keyboard.press("Control+a")
                page.keyboard.press("Delete")
                field.press_sequentially(text, delay=40)
                page.wait_for_timeout(500)
                if field.input_value() == text:
                    return True
                print(f"      retype {attempt + 1}: field held {field.input_value()!r}")
            return False

        if count >= 2:
            ok_email = type_into(inputs.nth(0), ROOT_EMAIL)
            ok_pass = type_into(inputs.nth(1), PASSWORD)
            check(results, ok_email and ok_pass, "credentials entered into the form")
            page.keyboard.press("Enter")
            page.wait_for_timeout(10_000)

        check(
            results,
            any(status == 200 for _, status in auth_calls),
            "console login succeeded over HTTP",
            str(auth_calls),
        )
        check(
            results,
            len(sockets) >= 1,
            "browser opened a WebSocket to the backend",
            sockets[0].split("?")[0] if sockets else "none",
        )

        token = api.login(TRIGGER_EMAIL)
        status, body = api.call(
            "POST",
            "/incidents/trigger",
            {
                "latitude": -6.9025,
                "longitude": 107.6188,
                "address_detail": "Browser console verification",
                "incident_type": "medical",
            },
            token=token,
        )
        data = body.get("data") or {}
        incident_id = data.get("incident_id")
        check(
            results,
            status in (200, 201) and data.get("status") == "broadcasting",
            "civilian SOS triggered",
            f"HTTP {status} incident={incident_id}",
        )

        deadline = time.time() + args.timeout
        received = False
        while time.time() < deadline and not received:
            received = any("INCOMING_EMERGENCY" in frame for frame in list(frames))
            if not received:
                page.wait_for_timeout(1_000)
        check(
            results,
            received,
            "browser console received INCOMING_EMERGENCY over WebSocket",
            f"{len(frames)} frame(s) received",
        )

        check(
            results,
            not page_errors,
            "no uncaught page errors",
            "; ".join(page_errors[:2]),
        )

        # Free the trigger account for the exhibition: accept, handle, resolve.
        if incident_id:
            volunteer = api.login(VOLUNTEER_EMAIL)
            agency = api.login(AGENCY_EMAIL, "console/login")
            for label, path, tok, payload in (
                (
                    "volunteer accept",
                    f"/incidents/{incident_id}/accept",
                    volunteer,
                    {"latitude": -6.9025, "longitude": 107.6188},
                ),
                (
                    "agency handle",
                    f"/incidents/{incident_id}/agency-handle",
                    agency,
                    {},
                ),
                (
                    "agency resolve",
                    f"/incidents/{incident_id}/agency-resolve",
                    agency,
                    {},
                ),
            ):
                state, _ = api.call("POST", path, payload, token=tok)
                print(f"      cleanup: {label} -> HTTP {state}")

        browser.close()

    print("-" * 68)
    if all(results):
        print("RESULT: ALL BROWSER CHECKS PASSED")
        return 0
    print(f"RESULT: FAILED ({results.count(False)})")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
