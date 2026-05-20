"""Spotify Web API: search tracks and add to the host's playback queue.

Same behavior as Wordwich's integration. Env (Hangman preferred; Wordwich vars work too):

  HANGMAN_SPOTIFY_CLIENT_ID   or WORDWICH_SPOTIFY_CLIENT_ID
  HANGMAN_SPOTIFY_CLIENT_SECRET or WORDWICH_SPOTIFY_CLIENT_SECRET
  HANGMAN_SPOTIFY_REFRESH_TOKEN or WORDWICH_SPOTIFY_REFRESH_TOKEN

Run ``py hangman_spotify_oauth_once.py`` once for a Hangman-specific refresh token.
Spotify Premium is typically required for queue; desktop app should be active.
"""
from __future__ import annotations

import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from typing import Any

_TOKEN: str | None = None
_TOKEN_UNTIL: float = 0.0
_MAX_ACTIVE_QUEUES_PER_USER = 2
_LOCAL_QUEUE_REQUESTS: list[dict[str, str]] = []

# Spotify track ids are 22 chars (base62). Match open.spotify.com/.../track/{id} or spotify:track:{id}
_SPOTIFY_TRACK_ID = r"[0-9A-Za-z]{22}"
_RE_SPOTIFY_URI = re.compile(rf"(?i)\bspotify:track:({_SPOTIFY_TRACK_ID})\b")
_RE_OPEN_TRACK_URL = re.compile(
    rf"(?i)\bopen\.spotify\.com/(?:[\w-]+/)*track/({_SPOTIFY_TRACK_ID})\b"
)


def spotify_track_id_from_user_input(text: str) -> str | None:
    """Extract track id from a Spotify URI/URL embedded anywhere in ``text``, or None."""
    s = (text or "").strip()
    if s.startswith("<") and s.endswith(">"):
        s = s[1:-1].strip()
    if not s:
        return None
    m = _RE_SPOTIFY_URI.search(s)
    if m:
        return m.group(1)
    m = _RE_OPEN_TRACK_URL.search(s)
    if m:
        return m.group(1)
    return None


def _fetch_track_label_by_id(track_id: str) -> tuple[str, str]:
    """GET /v1/tracks/{id}. Return (Title — Artist, error)."""
    if not re.match(rf"^{_SPOTIFY_TRACK_ID}$", track_id):
        return "", "bad_track_id"
    tok, err = _access_token()
    if err or not tok:
        return "", err or "auth_failed"
    url = f"https://api.spotify.com/v1/tracks/{urllib.parse.quote(track_id, safe='')}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            t = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace") if e.fp else ""
        if e.code == 404:
            return "", "track_not_found"
        return "", f"track_{e.code}:{body[:200]}"
    except OSError as e:
        return "", str(e)
    if not isinstance(t, dict):
        return "", "bad_track_response"
    name = (t.get("name") or "?").strip()
    artists = ", ".join(
        (a.get("name") or "?").strip()
        for a in (t.get("artists") or [])
        if isinstance(a, dict)
    )
    label = f"{name} — {artists}" if artists else name
    return label, ""


def _invalidate_token_cache() -> None:
    global _TOKEN, _TOKEN_UNTIL
    _TOKEN = None
    _TOKEN_UNTIL = 0.0


def _cfg() -> tuple[str, str, str]:
    def pick(*keys: str) -> str:
        for k in keys:
            v = os.environ.get(k, "").strip()
            if v:
                return v
        return ""

    cid = pick("HANGMAN_SPOTIFY_CLIENT_ID", "WORDWICH_SPOTIFY_CLIENT_ID")
    secret = pick("HANGMAN_SPOTIFY_CLIENT_SECRET", "WORDWICH_SPOTIFY_CLIENT_SECRET")
    refresh = pick("HANGMAN_SPOTIFY_REFRESH_TOKEN", "WORDWICH_SPOTIFY_REFRESH_TOKEN")
    return cid, secret, refresh


def spotify_queue_configured() -> bool:
    cid, secret, refresh = _cfg()
    return bool(cid and secret and refresh)


def spotify_auth_probe() -> dict[str, Any]:
    """Lightweight check that refresh_token + client credentials obtain an access token."""
    if not spotify_queue_configured():
        return {
            "ok": False,
            "reason": "missing_env",
            "detail": "Set HANGMAN_SPOTIFY_* (or WORDWICH_SPOTIFY_*) CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN in .env",
        }
    tok, err = _access_token()
    if tok:
        return {"ok": True, "reason": "ok"}
    return {"ok": False, "reason": "token_refresh_failed", "detail": err}


def _access_token() -> tuple[str | None, str]:
    global _TOKEN, _TOKEN_UNTIL
    if _TOKEN and time.time() < _TOKEN_UNTIL:
        return _TOKEN, ""
    cid, secret, refresh = _cfg()
    if not (cid and secret and refresh):
        return None, "spotify_not_configured"
    body = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh,
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
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            data = json.loads(raw)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode(errors="replace") if e.fp else ""
        err_code = ""
        try:
            ej = json.loads(err_body)
            err_code = str(ej.get("error") or "")
        except json.JSONDecodeError:
            pass
        if e.code == 400 and err_code == "invalid_grant":
            return None, "invalid_refresh_token_run_oauth_again"
        if e.code in (400, 401) and err_code == "invalid_client":
            return None, "invalid_client_id_or_secret_check_dashboard"
        return None, f"token_http_{e.code}:{err_body[:280]}"
    except OSError as e:
        return None, str(e)
    tok = data.get("access_token")
    if not tok:
        return None, "token_no_access_token"
    _TOKEN = tok
    _TOKEN_UNTIL = time.time() + float(data.get("expires_in", 3600)) - 45.0
    return tok, ""


def search_first_track_uri(query: str) -> tuple[str | None, str, str]:
    """Return (spotify_uri, human_label, error)."""
    tok, err = _access_token()
    if err or not tok:
        return None, "", err or "auth_failed"
    q = urllib.parse.quote(query.strip(), safe="")
    url = f"https://api.spotify.com/v1/search?q={q}&type=track&limit=1"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace") if e.fp else ""
        return None, "", f"search_{e.code}:{body[:240]}"
    except OSError as e:
        return None, "", str(e)
    items = (payload.get("tracks") or {}).get("items") or []
    if not items:
        return None, "", "no_results"
    t = items[0]
    uri = t.get("uri") or ""
    if not uri.startswith("spotify:track:"):
        return None, "", "bad_uri"
    name = (t.get("name") or "?").strip()
    artists = ", ".join((a.get("name") or "?").strip() for a in (t.get("artists") or []))
    label = f"{name} — {artists}" if artists else name
    return uri, label, ""


def add_uri_to_queue(uri: str) -> str:
    """Return empty string on success, else error code/message."""
    tok, err = _access_token()
    if err or not tok:
        return err or "auth_failed"
    qs = urllib.parse.urlencode({"uri": uri})
    url = f"https://api.spotify.com/v1/me/player/queue?{qs}"
    req = urllib.request.Request(url, method="POST", headers={"Authorization": f"Bearer {tok}"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            if resp.status not in (200, 204):
                return f"queue_http_{resp.status}"
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace") if e.fp else ""
        if e.code == 401:
            return f"queue_401:{body[:200]}"
        if e.code == 403:
            return "queue_forbidden_premium_or_scope"
        if e.code == 404:
            return "no_active_device"
        return f"queue_{e.code}:{body[:240]}"
    except OSError as e:
        return str(e)
    return ""


def _track_line(t: Any, _depth: int = 0) -> str:
    """Build 'Title — Artist' from Track, Episode, or playlist-style {track: {...}}."""
    if _depth > 6 or not isinstance(t, dict):
        return ""
    inner = t.get("track")
    if isinstance(inner, dict) and inner is not t:
        line = _track_line(inner, _depth + 1)
        if line:
            return line
    name = (t.get("name") or "").strip()
    artists = t.get("artists")
    if not (isinstance(artists, list) and artists):
        album = t.get("album")
        if isinstance(album, dict):
            artists = album.get("artists")
    if isinstance(artists, list) and artists:
        an = ", ".join(
            (a.get("name") or "?").strip() for a in artists if isinstance(a, dict)
        )
        if name and an:
            return f"{name} — {an}"
        if an and not name:
            return an
        if name:
            return name
    show = t.get("show")
    if isinstance(show, dict) and (show.get("name") or "").strip():
        sn = (show.get("name") or "").strip()
        return f"{name} — {sn}" if name else sn
    if name:
        return name
    uri = (t.get("uri") or "").strip()
    if uri.startswith("spotify:track:") or uri.startswith("spotify:episode:"):
        return uri
    return ""


def _http_body_suggests_missing_scope(body: str) -> bool:
    b = (body or "").lower()
    return "permission" in b or "insufficient" in b or "scope" in b or "forbidden" in b


def _track_uri(t: Any, _depth: int = 0) -> str:
    if _depth > 6 or not isinstance(t, dict):
        return ""
    inner = t.get("track")
    if isinstance(inner, dict) and inner is not t:
        u = _track_uri(inner, _depth + 1)
        if u:
            return u
    uri = str(t.get("uri") or "").strip()
    if uri.startswith("spotify:track:") or uri.startswith("spotify:episode:"):
        return uri
    return ""


def _fetch_raw_queue() -> dict[str, Any]:
    if not spotify_queue_configured():
        return {"ok": False, "error": "spotify_not_configured", "upcoming": []}

    url = "https://api.spotify.com/v1/me/player/queue"
    payload: dict[str, Any] | None = None
    for attempt in range(2):
        tok, err = _access_token()
        if err or not tok:
            return {"ok": False, "error": err or "auth_failed", "upcoming": []}
        req = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {tok}",
                "Accept": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
                payload = json.loads(raw)
                break
        except urllib.error.HTTPError as e:
            body = e.read().decode(errors="replace") if e.fp else ""
            if e.code in (401, 403) and _http_body_suggests_missing_scope(body):
                return {
                    "ok": False,
                    "error": "queue_list_needs_scope",
                    "upcoming": [],
                    "hint": "Run py hangman_spotify_oauth_once.py — approve user-read-playback-state",
                    "detail": body[:220],
                }
            if e.code == 401 and attempt == 0:
                _invalidate_token_cache()
                continue
            if e.code == 401:
                return {"ok": False, "error": "queue_list_401", "upcoming": [], "detail": body[:120]}
            if e.code == 403:
                return {
                    "ok": False,
                    "error": "queue_list_needs_scope",
                    "upcoming": [],
                    "hint": "Allow user-read-playback-state — run hangman_spotify_oauth_once.py again",
                    "detail": body[:200],
                }
            if e.code == 404:
                return {"ok": False, "error": "no_active_device", "upcoming": []}
            return {"ok": False, "error": f"queue_list_{e.code}", "upcoming": [], "detail": body[:200]}
        except OSError as e:
            return {"ok": False, "error": str(e), "upcoming": []}

    if payload is None:
        return {"ok": False, "error": "queue_list_failed", "upcoming": []}
    raw_queue = payload.get("queue")
    if not isinstance(raw_queue, list):
        raw_queue = []
    return {"ok": True, "raw_queue": raw_queue}


def _sync_local_requests(raw_queue: list[Any]) -> None:
    global _LOCAL_QUEUE_REQUESTS
    uri_counts: dict[str, int] = {}
    for item in raw_queue:
        uri = _track_uri(item)
        if uri:
            uri_counts[uri] = uri_counts.get(uri, 0) + 1
    kept: list[dict[str, str]] = []
    for rec in _LOCAL_QUEUE_REQUESTS:
        uri = rec.get("uri", "")
        if uri_counts.get(uri, 0) > 0:
            kept.append(rec)
            uri_counts[uri] -= 1
    _LOCAL_QUEUE_REQUESTS = kept[-250:]


def _decorate_upcoming_with_requesters(raw_queue: list[Any], upcoming: list[str]) -> list[str]:
    buckets: dict[str, list[str]] = defaultdict(list)
    for rec in _LOCAL_QUEUE_REQUESTS:
        uri = rec.get("uri", "")
        rb = rec.get("requested_by", "").strip()
        if uri and rb:
            buckets[uri].append(rb)
    out: list[str] = []
    idx = 0
    for item in raw_queue:
        if idx >= len(upcoming):
            break
        if not isinstance(item, dict):
            continue
        line = upcoming[idx]
        idx += 1
        uri = _track_uri(item)
        who = buckets.get(uri) or []
        if who:
            out.append(f"{line} (queued by {who.pop(0)})")
        else:
            out.append(line)
    return out


def _active_queued_count_for_user(raw_queue: list[Any], requested_by: str) -> int:
    _sync_local_requests(raw_queue)
    key = (requested_by or "").strip().lower()
    if not key:
        return 0
    return sum(1 for rec in _LOCAL_QUEUE_REQUESTS if rec.get("requested_by_key") == key)


def spotify_queue_list_snapshot() -> dict[str, Any]:
    got = _fetch_raw_queue()
    if not got.get("ok"):
        return got
    raw_queue = got.get("raw_queue") or []
    if not isinstance(raw_queue, list):
        raw_queue = []
    _sync_local_requests(raw_queue)

    upcoming: list[str] = []
    for item in raw_queue:
        if isinstance(item, dict):
            line = _track_line(item)
            if line:
                upcoming.append(line)
    upcoming = _decorate_upcoming_with_requesters(raw_queue, upcoming)
    upcoming = upcoming[:25]
    src_n = len(raw_queue)
    empty_hint = ""
    if src_n == 0:
        empty_hint = (
            "Spotify Web API often returns an empty queue on Free; use Premium, "
            "or ensure the desktop app is the active player and re-open OAuth scopes."
        )
    elif src_n > 0 and not upcoming:
        empty_hint = "API returned queue items but no display names — check Spotify response format."
    return {
        "ok": True,
        "upcoming": upcoming,
        "error": "",
        "source_count": src_n,
        "hint": empty_hint,
    }


def queue_track_by_search(query: str, requested_by: str) -> dict[str, Any]:
    """Queue by text search or by Spotify track URL / ``spotify:track:`` URI in ``query``."""
    requested_by_clean = (requested_by or "").strip() or "Anonymous"
    if not query.strip():
        return {"ok": False, "error": "empty_query", "requested_by": requested_by_clean}
    if not spotify_queue_configured():
        return {"ok": False, "error": "spotify_not_configured", "requested_by": requested_by_clean}

    got = _fetch_raw_queue()
    if got.get("ok"):
        raw_queue = got.get("raw_queue") or []
        if not isinstance(raw_queue, list):
            raw_queue = []
        active_for_user = _active_queued_count_for_user(raw_queue, requested_by_clean)
        if active_for_user >= _MAX_ACTIVE_QUEUES_PER_USER:
            return {
                "ok": False,
                "error": "queue_limit_reached",
                "requested_by": requested_by_clean,
                "limit": _MAX_ACTIVE_QUEUES_PER_USER,
                "hint": f"Each user can only queue {_MAX_ACTIVE_QUEUES_PER_USER} songs at once.",
            }
    track_id = spotify_track_id_from_user_input(query)
    if track_id:
        uri = f"spotify:track:{track_id}"
        label, err = _fetch_track_label_by_id(track_id)
        if err:
            return {"ok": False, "error": err, "requested_by": requested_by_clean}
    else:
        uri, label, err = search_first_track_uri(query)
        if err:
            return {"ok": False, "error": err, "requested_by": requested_by_clean}
    qerr = add_uri_to_queue(uri)
    if qerr:
        return {"ok": False, "error": qerr, "track": label, "requested_by": requested_by_clean}
    _LOCAL_QUEUE_REQUESTS.append(
        {
            "uri": uri,
            "requested_by": requested_by_clean,
            "requested_by_key": requested_by_clean.lower(),
        }
    )
    _LOCAL_QUEUE_REQUESTS[:] = _LOCAL_QUEUE_REQUESTS[-250:]
    return {"ok": True, "track": label, "requested_by": requested_by_clean}
