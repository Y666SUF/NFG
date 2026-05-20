"""
NFG Hangman — desktop shell: runs the same FastAPI + WebSocket server and shows the
overlay in a native window (Edge WebView2 on Windows), not a separate browser.

  py -3 desktop.py

Requires: pip install -r requirements.txt (includes pywebview).
Windows: WebView2 runtime (usually already on Windows 10/11).

Browser / OBS URL mode is unchanged — use run_web.bat when you want http://... only.

The window loads the same ``index.html`` as the browser. ``?desktop=1`` is appended for desktop-only UI (e.g. zoom).
Set TikTok posting env vars on this PC before starting (see ``run_desktop.bat`` REM comments).
In the desktop window, use **Ctrl+Plus / Ctrl+Minus / Ctrl+0** to zoom the page (or pinch on a trackpad if supported).
"""
from __future__ import annotations

import os
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path


def _port() -> int:
    raw = os.environ.get("HANGMAN_WEB_PORT", "").strip()
    if raw.isdigit():
        p = int(raw)
        if 1 <= p <= 65535:
            return p
    return 19876


def _bind_host() -> str:
    h = os.environ.get("HANGMAN_DESKTOP_BIND", "127.0.0.1").strip()
    return h if h else "127.0.0.1"


def _wait_http_ready(url: str, timeout_sec: float = 90.0) -> None:
    deadline = time.monotonic() + timeout_sec
    last_err: BaseException | None = None
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2.0) as r:
                if getattr(r, "status", 200) == 200:
                    return
        except (urllib.error.URLError, OSError, TimeoutError) as e:
            last_err = e
            time.sleep(0.2)
    msg = f"Server did not respond in time: {url}"
    if last_err is not None:
        msg += f" ({last_err!r})"
    raise RuntimeError(msg)


def _uvicorn_thread(host: str, port: int) -> None:
    import uvicorn

    uvicorn.run(
        "server:app",
        host=host,
        port=port,
        log_level="info",
        access_log=True,
        reload=False,
        workers=1,
    )


def main() -> None:
    root = Path(__file__).resolve().parent
    os.chdir(root)

    try:
        import webview
    except ImportError as e:
        raise SystemExit(
            "pywebview is not installed. From this folder run:\n"
            "  py -3 -m pip install -r requirements.txt\n"
            "Then try again."
        ) from e

    host = _bind_host()
    port = _port()
    base = f"http://127.0.0.1:{port}" if host in ("0.0.0.0", "::") else f"http://{host}:{port}"

    t = threading.Thread(target=_uvicorn_thread, args=(host, port), daemon=True)
    t.start()
    _wait_http_ready(f"{base}/api/build-info")

    print(
        "\n[Hangman desktop] UI matches the browser overlay. "
        "Zoom: Ctrl+Plus / Ctrl+Minus / Ctrl+0 (reset); pinch-zoom may also work. "
        "TikTok LIVE chat posting: set cookie env vars (see run_desktop.bat REM lines) if you use !how / !play.\n",
        flush=True,
    )

    webview.create_window(
        "NFG Hangman — TikTok Live",
        f"{base}/?desktop=1",
        width=1400,
        height=880,
        min_size=(960, 600),
        zoomable=True,
    )
    webview.start()


if __name__ == "__main__":
    main()
