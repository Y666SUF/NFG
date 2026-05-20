"""
One-time Spotify OAuth to obtain HANGMAN_SPOTIFY_REFRESH_TOKEN.

1. Create an app at https://developer.spotify.com/dashboard
2. Edit Settings → Redirect URIs → add exactly:
     http://127.0.0.1:8888/callback
3. Set environment variables:
     HANGMAN_SPOTIFY_CLIENT_ID
     HANGMAN_SPOTIFY_CLIENT_SECRET
4. Run:  py hangman_spotify_oauth_once.py
5. Log in, approve; refresh token is merged into .env in this folder.

Scopes: user-modify-playback-state user-read-playback-state
"""
from __future__ import annotations

from pathlib import Path

import http.server
import json
import os
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

REDIRECT_URI = "http://127.0.0.1:8888/callback"
PORT = 8888
SCOPE = "user-modify-playback-state user-read-playback-state"

_holder: dict[str, str | None] = {"code": None, "error": None}


class _CallbackHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)
        if "code" in qs and qs["code"]:
            _holder["code"] = qs["code"][0]
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write("OK - you can close this tab and return to the terminal.".encode("utf-8"))
        elif "error" in qs:
            _holder["error"] = qs.get("error", ["unknown"])[0]
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Authorization was denied or failed.")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        return


def main() -> None:
    try:
        from dotenv import load_dotenv

        load_dotenv(Path(__file__).resolve().parent / ".env", override=True)
    except ImportError:
        pass
    cid = os.environ.get("HANGMAN_SPOTIFY_CLIENT_ID", "").strip()
    secret = os.environ.get("HANGMAN_SPOTIFY_CLIENT_SECRET", "").strip()
    if not cid or not secret:
        print("Set HANGMAN_SPOTIFY_CLIENT_ID and HANGMAN_SPOTIFY_CLIENT_SECRET first.", file=sys.stderr)
        sys.exit(1)

    params = urllib.parse.urlencode(
        {
            "client_id": cid,
            "response_type": "code",
            "redirect_uri": REDIRECT_URI,
            "scope": SCOPE,
        }
    )
    auth_url = f"https://accounts.spotify.com/authorize?{params}"

    server = http.server.HTTPServer(("127.0.0.1", PORT), _CallbackHandler)
    th = threading.Thread(target=server.handle_request, daemon=True)
    th.start()

    print("Opening browser for Spotify login…")
    webbrowser.open(auth_url)
    print("\nIf nothing opened, visit:\n", auth_url, "\n")

    for _ in range(240):
        if _holder["code"] or _holder["error"]:
            break
        threading.Event().wait(0.5)

    try:
        server.server_close()
    except OSError:
        pass

    if _holder["error"]:
        print("OAuth error:", _holder["error"], file=sys.stderr)
        sys.exit(1)
    code = _holder["code"]
    if not code:
        print("Timed out waiting for callback.", file=sys.stderr)
        sys.exit(1)

    body = urllib.parse.urlencode(
        {
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": REDIRECT_URI,
            "client_id": cid,
            "client_secret": secret,
        }
    ).encode()
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=body,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        err = e.read().decode(errors="replace") if e.fp else ""
        print("Token exchange failed:", e.code, err[:500], file=sys.stderr)
        sys.exit(1)

    rt = data.get("refresh_token")
    if not rt:
        print("No refresh_token in response:", data, file=sys.stderr)
        sys.exit(1)

    root = Path(__file__).resolve().parent
    _merge_refresh_token_into_dotenv(root, rt)
    print("\nWrote HANGMAN_SPOTIFY_REFRESH_TOKEN to .env in this folder.")
    print("Restart Hangman (run_web / desktop) to load it.\n")
    print("(Copy for backup:)\n")
    print(f"HANGMAN_SPOTIFY_REFRESH_TOKEN={rt}\n")


def _merge_refresh_token_into_dotenv(root: Path, refresh_token: str) -> None:
    env_path = root / ".env"
    key = "HANGMAN_SPOTIFY_REFRESH_TOKEN"
    new_line = f"{key}={refresh_token}"
    if env_path.exists():
        lines = env_path.read_text(encoding="utf-8").splitlines()
        out: list[str] = []
        seen = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith(f"{key}="):
                out.append(new_line)
                seen = True
            else:
                out.append(line)
        if not seen:
            out.append(new_line)
        env_path.write_text("\n".join(out) + "\n", encoding="utf-8")
    else:
        env_path.write_text(f"{new_line}\n", encoding="utf-8")


if __name__ == "__main__":
    main()
