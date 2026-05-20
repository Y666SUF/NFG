"""
Browser UI + WebSocket for Hangman; monitors a TikTok LIVE chat (default: y666.suf).

  py -m uvicorn server:app --host 0.0.0.0 --port 19876

Open http://127.0.0.1:19876/  (or set HANGMAN_WEB_PORT before run_web.bat). Stream must be LIVE for TikTok connection.
Static HTML/JS/CSS send no-cache headers unless HANGMAN_ALLOW_BROWSER_CACHE=1 (avoids stale UI after updates).
Each new round prints the answer to the server console; set HANGMAN_PRINT_ANSWER=0 to disable.
Optional AI theme labels (category only): set HANGMAN_OPENAI_API_KEY or HANGMAN_WORD_THEME_API_KEY (OpenAI); HANGMAN_WORD_THEME_AI=0 turns off. HANGMAN_WORD_THEME_AI_MODEL (default gpt-4o-mini), HANGMAN_WORD_THEME_AI_TIMEOUT (seconds, default 2.5). The model must return a concrete ``Domain · subtype`` line; vague replies are dropped and keyword heuristics from word_topic are used instead.
Pre-baked themes for the whole word bank: run ``py scripts/build_word_themes.py`` (uses dictionaryapi.dev glosses + the same keyword scorer); loads ``data/word_theme_map.json`` if present (override with ``HANGMAN_WORD_THEME_MAP_PATH``). Map wins over AI when a key exists.

Gift matching (substring or comma-separated IDs): HANGMAN_GALAXY_GIFT_MATCH / _IDS,
HANGMAN_CAP_GIFT_MATCH (default "cap") / HANGMAN_CAP_GIFT_IDS,
HANGMAN_ROSA_GIFT_MATCH (comma-separated name tokens, default ``rosa``) / HANGMAN_ROSA_GIFT_IDS — Rosa runs on streakable gifts mid-streak so hints are not skipped; diamond all-time credit still applies when the streak ends,
HANGMAN_RACING_DEBUT_GIFT_MATCH (default "racing debut") / HANGMAN_RACING_DEBUT_GIFT_IDS — 48h Galaxy steal shield (HANGMAN_RACING_DEBUT_SHIELD_HOURS),
HANGMAN_CAR_DRIFTING_GIFT_MATCH (default "car drifting") / HANGMAN_CAR_DRIFTING_GIFT_IDS — trim another viewer's shield by HANGMAN_CAR_DRIFTING_TRIM_HOURS (default 48).
HANGMAN_SPACE_CAT_GIFT_MATCH (default "space cat") / HANGMAN_SPACE_CAT_GIFT_IDS — then @username grants that player ~48h Racing Debut shield (not the sender). HANGMAN_SPACE_CAT_PENDING_SEC.
HANGMAN_LION_GIFT_MATCH (default "lion") / HANGMAN_LION_GIFT_IDS — starts 5 min all-time nuke countdown; send another Lion in time to cancel.
HANGMAN_MONEY_GUN_GIFT_MATCH (default "money gun") / HANGMAN_MONEY_GUN_GIFT_IDS — sender gets 5 rounds of no wrong-guess point loss.
Set ``HANGMAN_DEBUG_GIFTS=1`` to print one-line traces for every gift (name/id/streak/diamonds) and which branch ran.
Other gifts (not Galaxy / Car Drifting / Space Cat / Racing Debut / Cap / Rosa): all-time pts = ``diamond_count`` × ``repeat_count`` (if ``HANGMAN_GIFT_DIAMOND_USE_REPEAT``) × ``HANGMAN_GIFT_DIAMOND_RATIO`` (default **0.1**), floored to an integer. Cap at ``HANGMAN_GIFT_DIAMOND_POINTS_CAP``; disable with ``HANGMAN_GIFT_DIAMOND_POINTS=0``.
When a trim fully removes shield (0 left), HANGMAN_SHIELD_DROP_GRACE_SEC (default 300) — no Galaxy steals from that viewer; they can send Racing Debut to restore shield.
``live_likes`` (room total + top 3 likers) is rendered under Letters guessed in the web UI; pushes coalesce with ``HANGMAN_LIVE_LIKES_PUSH_SEC`` (default 0.22).
Like events use a slightly looser wall-time window than chat (``HANGMAN_LIKE_EVENT_BACKLOG_SEC``, default 900s) so TikTok ``create_time`` a little before connect is not dropped.
Per viewer, +1 **all-time** point (not session) per 10 likes this TikTok connection, at most 500 such points per **UTC day**
(``like_bonus_date`` / ``like_bonus_day``; see ``try_award_live_like_alltime_bonus``).
``live_likes_lifetime`` counts LIVE likes since the last Like MVP reset; every 50,000 unlocks a higher ``like_cosmetic_tier`` for stream name styling.
All-time top lifetime liker: once per calendar day at ``HANGMAN_LIKE_MVP_PAYOUT_HOUR`` / ``HANGMAN_LIKE_MVP_PAYOUT_MINUTE``
in ``HANGMAN_LIKE_MVP_PAYOUT_TZ`` (defaults: 0, 0, ``UTC``; on Windows install PyPI ``tzdata`` for other IANA names) the #1 by ``live_likes_lifetime`` earns ``HANGMAN_LIKE_MVP_POINTS``
(default 2000) **all-time** points, then everyone’s ``live_likes_lifetime`` is set to 0 (disable with ``HANGMAN_LIKE_MVP_RESET_LIFETIME=0``). The countdown is pure wall time (not tied to server uptime); ``data/like_mvp_clock.json`` stores
``last_awarded_slot_unix`` so restarts do not reset or double-pay the same slot (missed days: at most ``HANGMAN_LIKE_MVP_CATCHUP_MAX`` payouts per wake).
When Wordwich is installed alongside Hangman, the same payout also clears ``Wordwich/data/wordwich_alltime_likes.json`` (override path with ``HANGMAN_WORDWICH_LIKES_PATH``; disable with ``HANGMAN_WORDWICH_RESET_LIKES=0``).
Cap / Galaxy / Car Drifting pending windows: HANGMAN_CAP_PENDING_SEC, HANGMAN_GALAXY_PENDING_SEC, HANGMAN_CAR_DRIFTING_PENDING_SEC (seconds).
Late !word matching the previous answer after someone else solved: HANGMAN_LATE_WORD_GRACE_SEC (default 7).
Seconds after a solve before auto-next round: HANGMAN_AUTO_NEXT_DELAY_SEC (default 2.5; 0 = immediate).
Chat time filter: only process comments/gifts whose TikTok create_time is at or after session (and live connect)
plus HANGMAN_CHAT_ONLY_AFTER_SESSION_SEC (default 5). Set HANGMAN_CHAT_TIME_FILTER=0 to disable.

Host/broadcaster (``TIKTOK_HOST_USERNAME`` / streamer): ``!addpoints @handle POINTS`` or ``!addpts`` — adjust any viewer's **all-time** total (negative subtracts).
Overlay rules: ``!hangman`` in chat shows full-screen how-to on the stream (not a guess; no points lost).
Per-viewer cooldown ``HANGMAN_HELP_COOLDOWN_SEC`` (default 120); display time ``HANGMAN_HELP_POPUP_MS`` (default 90000).

Post how-to-play into the LIVE you are monitoring (any ``TIKTOK_LIVE_USERNAME``): viewers type ``!how``, ``!play``,
``!rules``, or ``!howtoplay`` (override list with ``HANGMAN_TIKTOK_GUIDE_COMMANDS``, comma-separated, each with leading !).
Requires TikTokLive authenticated chat: ``TIKTOK_CHAT_SESSION_ID`` + ``TIKTOK_CHAT_TT_TARGET_IDC`` (browser cookies for
the account that will speak — use a spare account, not your main password in logs), and
``WHITELIST_AUTHENTICATED_SESSION_ID_HOST=tiktok.eulerstream.com`` (see TikTokLive docs / safety warning).
Optional ``TIKTOK_PLAY_GUIDE_MESSAGE`` (use ``\\n`` for newlines; else a default short rules blurb). Throttle:
``HANGMAN_TIKTOK_GUIDE_COOLDOWN_SEC`` per viewer (default 45).

Spotify (optional, same model as Wordwich): now-playing uses Windows media session (Spotify desktop); queue uses Web API.
Set ``HANGMAN_SPOTIFY_CLIENT_ID``, ``HANGMAN_SPOTIFY_CLIENT_SECRET``, ``HANGMAN_SPOTIFY_REFRESH_TOKEN`` (or reuse ``WORDWICH_SPOTIFY_*``).
Run ``py hangman_spotify_oauth_once.py`` once. Spotify queue from TikTok chat: ``!queue`` / ``!song`` / ``!addsong`` — broadcaster (``TIKTOK_HOST_USERNAME`` / ``TIKTOK_LIVE_USERNAME``) or viewers you allow with ``!queueallow @handle``; revoke with ``!queuedeny`` / ``!queueremove``, list with ``!queuelist``. Persisted in ``data/spotify_queue_allowlist.json``. Local ``POST /api/hangman/spotify-queue`` unchanged. Requires ``winrt`` on Windows for now-playing.
"""
from __future__ import annotations

import asyncio
import json
import math
import os
import re
import threading
import time
from collections import deque
from contextlib import asynccontextmanager
from datetime import date, datetime, time as dt_time, timedelta, timezone
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

from fastapi import FastAPI, Header, HTTPException, Query, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles
from TikTokLive.client.client import TikTokLiveClient
from TikTokLive.events import (
    CommentEvent,
    ConnectEvent,
    DisconnectEvent,
    GiftEvent,
    LikeEvent,
)

from alltime_leaderboard import (
    add_points,
    canonical_alltime_key,
    display_name_for_key,
    record_live_likes_lifetime,
    reset_alltime_points_for_all_users,
    reset_all_live_likes_lifetime,
    resolve_user_key_from_handle,
    top_live_likes_lifetime_holder,
    top_players,
    transfer_alltime_points,
    try_award_live_like_alltime_bonus,
    try_wager_settle,
    user_glow_mascot_crown,
    user_has_glow,
    user_heart_color_hex,
    user_like_cosmetic_tier,
    user_name_badge,
    user_name_color_hex,
    word_streak_peak_for_key,
)
from racing_debut_shield import (
    default_shield_path,
    grant_shield,
    is_protected,
    is_shield_drop_grace_active,
    list_shield_drop_grace_expirations,
    shield_duration_sec,
    shield_drop_grace_until,
    shield_expiry_unix,
    start_shield_drop_grace,
    trim_shield_by_hours,
)
from chat_bridge import process_chat_message
from nfg_platform import (
    forward_tiktok_link_to_platform,
    is_nfg_crash_chat_noise,
    is_nfg_crash_spotify_noise,
    parse_link_command,
)
from hangman_game import HangmanSession, print_round_answer_to_console
from hangman_spotify_now_playing import spotify_now_playing_async
from hangman_spotify_playback import (
    queue_track_by_search,
    spotify_auth_probe,
    spotify_queue_list_snapshot,
)
from chat_bridge import spotify_queue_chat_lines
from spotify_commands import (
    hangman_spotify_admin_command,
    hangman_spotify_queue_match,
    hangman_spotify_usage_hint,
    legacy_spotify_hint,
)
from spotify_queue_allowlist_store import load_allowed_keys, save_allowed_keys
from win_sounds import win_sound_payload_for_user
from tiktok_comment_user import (
    comment_user_is_fan_club_member,
    effective_tiktok_user_key,
    extract_comment_author,
    extract_gift_sender,
    gift_user_is_fan_club_member,
    stable_user_key_and_name,
)
from text_normalize import normalize_chat_for_letter_parse, normalize_lookup_token
from tiktok_profile_image import fallback_avatar_svg, fetch_profile_avatar_bytes

DEFAULT_LIVE_USERNAME = "y666.suf"
STATIC_DIR = Path(__file__).resolve().parent / "static"
ALLTIME_PATH = Path(__file__).resolve().parent / "data" / "alltime_leaderboard.json"
LIKE_MVP_CLOCK_PATH = Path(__file__).resolve().parent / "data" / "like_mvp_clock.json"
SPOTIFY_QUEUE_ALLOWLIST_PATH = Path(__file__).resolve().parent / "data" / "spotify_queue_allowlist.json"
_HANGMAN_ROOT = Path(__file__).resolve().parent

try:
    from dotenv import load_dotenv

    load_dotenv(_HANGMAN_ROOT / ".env", override=False)
except ImportError:
    pass


def _wordwich_likes_json_path() -> Path | None:
    """Wordwich cumulative likes file; used to keep Like MVP period in sync with Hangman."""
    raw = (os.environ.get("HANGMAN_WORDWICH_LIKES_PATH") or "").strip()
    if raw:
        p = Path(raw).expanduser()
        return p.resolve() if p.is_absolute() else (_HANGMAN_ROOT / p).resolve()
    sibling = _HANGMAN_ROOT.parent / "Wordwich" / "data" / "wordwich_alltime_likes.json"
    return sibling.resolve() if sibling.is_file() else None


def _reset_wordwich_alltime_likes_json() -> int:
    """
    Set every user's ``likes`` to 0 in Wordwich's JSON when Hangman resets ``live_likes_lifetime``.

    Returns how many user rows were updated (including those already at 0).
    """
    if os.environ.get("HANGMAN_WORDWICH_RESET_LIKES", "1").strip().lower() in (
        "0",
        "false",
        "no",
        "off",
    ):
        return 0
    p = _wordwich_likes_json_path()
    if p is None or not p.is_file():
        return 0
    try:
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        print(f"[Like MVP] Wordwich likes file read failed: {e!s}", flush=True)
        return 0
    if not isinstance(data, dict):
        return 0
    users = data.get("users")
    if not isinstance(users, dict):
        return 0
    n = 0
    for _uk, row in users.items():
        if not isinstance(row, dict):
            continue
        row["likes"] = 0
        n += 1
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        tmp.replace(p)
    except OSError as e:
        print(f"[Like MVP] Wordwich likes file write failed: {e!s}", flush=True)
        try:
            tmp.unlink()
        except OSError:
            pass
        return 0
    return n
# Re-read index when file mtime changes; inject ?v= so OBS/browsers fetch fresh JS/CSS.
_cached_index_html: tuple[float, str] | None = None


def _index_html_for_response() -> str:
    global _cached_index_html
    path = STATIC_DIR / "index.html"
    mtime = path.stat().st_mtime
    if _cached_index_html is not None and _cached_index_html[0] == mtime:
        return _cached_index_html[1]
    text = path.read_text(encoding="utf-8")
    v = int(mtime)
    text = text.replace(
        "<title>NFG Hangman — TikTok Live</title>",
        f"<title>NFG Hangman — TikTok Live · ui-{v}</title>",
        1,
    )
    text = text.replace('href="/static/style.css"', f'href="/static/style.css?v={v}"', 1)
    text = text.replace('src="/static/user-characters.js"', f'src="/static/user-characters.js?v={v}"', 1)
    text = text.replace('src="/static/app.js"', f'src="/static/app.js?v={v}"', 1)
    _cached_index_html = (mtime, text)
    return text
SHIELD_PATH = default_shield_path()


def _record_alltime_delta(user_key: str, display_name: str, delta: int) -> None:
    add_points(user_key, display_name, delta, ALLTIME_PATH)


def _fmt_shield_remaining(exp_unix: float) -> str:
    left = max(0.0, exp_unix - time.time())
    h = int(left // 3600)
    m = int((left % 3600) // 60)
    if h >= 24:
        d = h // 24
        return f"{d} day(s) {h % 24}h left"
    return f"{h}h {m}m left"


def _alltime_payload() -> list[dict[str, Any]]:
    rows = top_players(12, ALLTIME_PATH)
    out: list[dict[str, Any]] = []
    for r in rows:
        item = dict(r)
        uk = str(item.get("user_key") or "")
        exp = shield_expiry_unix(uk, SHIELD_PATH) if uk else None
        item["shield_until"] = exp
        out.append(item)
    return out


def _shield_grace_windows_payload() -> list[dict[str, Any]]:
    """UI countdown: only users whose shield was fully removed and who are in the re-buy window."""
    out: list[dict[str, Any]] = []
    for uk, until in list_shield_drop_grace_expirations():
        if is_protected(uk, SHIELD_PATH):
            continue
        nb = user_name_badge(uk, ALLTIME_PATH) if uk else None
        row: dict[str, Any] = {
            "user_key": uk,
            "display_name": display_name_for_key(uk, ALLTIME_PATH),
            "grace_until": until,
        }
        if nb:
            row["name_badge"] = nb
        out.append(row)
    return out


def _snapshot_with_cosmetics() -> dict[str, Any]:
    assert session is not None
    state = session.snapshot()
    for p in state.get("players") or []:
        uk = str(p.get("user_key") or "")
        has_glow = bool(uk and user_has_glow(uk, ALLTIME_PATH))
        p["glow"] = has_glow
        nc = user_name_color_hex(uk, ALLTIME_PATH) if uk else None
        p["name_color"] = nc
        p["heart_color"] = user_heart_color_hex(uk, ALLTIME_PATH) if uk else None
        if has_glow and uk:
            p["glow_mascot_crown"] = user_glow_mascot_crown(uk, ALLTIME_PATH)
        else:
            p.pop("glow_mascot_crown", None)
        p["word_streak_peak"] = int(word_streak_peak_for_key(uk, ALLTIME_PATH)) if uk else 0
        nb = user_name_badge(uk, ALLTIME_PATH) if uk else None
        if nb:
            p["name_badge"] = nb
        if uk:
            p["like_cosmetic_tier"] = int(user_like_cosmetic_tier(uk, ALLTIME_PATH))
        else:
            p.pop("like_cosmetic_tier", None)
    wager = state.get("wager")
    if isinstance(wager, dict):
        ka = str(wager.get("key_a") or "")
        kb = str(wager.get("key_b") or "")
        nba = user_name_badge(ka, ALLTIME_PATH) if ka else None
        nbb = user_name_badge(kb, ALLTIME_PATH) if kb else None
        if nba:
            wager["name_badge_a"] = nba
        if nbb:
            wager["name_badge_b"] = nbb
    return state


def _inject_name_badges_into_payload(payload: dict[str, Any]) -> None:
    """Attach name_badge (star|heart|crown) and like_cosmetic_tier for popup dicts that include user_key(s)."""

    def badge(uk: str) -> str | None:
        if not uk:
            return None
        return user_name_badge(str(uk), ALLTIME_PATH)

    def like_tier(uk: str) -> int:
        if not uk:
            return 0
        return int(user_like_cosmetic_tier(str(uk), ALLTIME_PATH))

    def set_like_tier(target: dict[str, Any], uk_key: str) -> None:
        uk = str(target.get(uk_key) or "")
        t = like_tier(uk)
        if t > 0:
            target["like_cosmetic_tier"] = t
        else:
            target.pop("like_cosmetic_tier", None)

    rp = payload.get("round_popup")
    if isinstance(rp, dict):
        for m in rp.get("mvps") or []:
            if isinstance(m, dict):
                b = badge(str(m.get("user_key") or ""))
                if b:
                    m["name_badge"] = b
                set_like_tier(m, "user_key")
        sealed = rp.get("sealed_by")
        if isinstance(sealed, dict):
            b = badge(str(sealed.get("user_key") or ""))
            if b:
                sealed["name_badge"] = b
            set_like_tier(sealed, "user_key")
        ws = rp.get("wager_settlement")
        if isinstance(ws, dict):
            wb = badge(str(ws.get("winner_key") or ""))
            lb = badge(str(ws.get("loser_key") or ""))
            if wb:
                ws["winner_name_badge"] = wb
            if lb:
                ws["loser_name_badge"] = lb
            wuk = str(ws.get("winner_key") or "")
            luk = str(ws.get("loser_key") or "")
            wt, ltier = like_tier(wuk), like_tier(luk)
            if wt > 0:
                ws["winner_like_cosmetic_tier"] = wt
            else:
                ws.pop("winner_like_cosmetic_tier", None)
            if ltier > 0:
                ws["loser_like_cosmetic_tier"] = ltier
            else:
                ws.pop("loser_like_cosmetic_tier", None)

    hp = payload.get("hint_popup")
    if isinstance(hp, dict):
        b = badge(str(hp.get("from_user_key") or ""))
        if b:
            hp["from_name_badge"] = b
        set_like_tier(hp, "from_user_key")

    pp = payload.get("points_popup")
    if isinstance(pp, dict):
        b = badge(str(pp.get("user_key") or ""))
        if b:
            pp["name_badge"] = b
        set_like_tier(pp, "user_key")

    for key in ("galaxy_popup", "cap_popup", "shield_trim_popup"):
        box = payload.get(key)
        if not isinstance(box, dict):
            continue
        b1 = badge(str(box.get("from_user_key") or ""))
        if b1:
            box["from_name_badge"] = b1
        b2 = badge(str(box.get("victim_user_key") or ""))
        if b2:
            box["victim_name_badge"] = b2
        uk_f = str(box.get("from_user_key") or "")
        uk_v = str(box.get("victim_user_key") or "")
        tf, tv = like_tier(uk_f), like_tier(uk_v)
        if tf > 0:
            box["from_like_cosmetic_tier"] = tf
        else:
            box.pop("from_like_cosmetic_tier", None)
        if tv > 0:
            box["victim_like_cosmetic_tier"] = tv
        else:
            box.pop("victim_like_cosmetic_tier", None)

    fg = payload.get("fan_gate_popup")
    if isinstance(fg, dict):
        b = badge(str(fg.get("user_key") or ""))
        if b:
            fg["name_badge"] = b
        set_like_tier(fg, "user_key")

    hh = payload.get("hangman_help_popup")
    if isinstance(hh, dict):
        b = badge(str(hh.get("from_user_key") or ""))
        if b:
            hh["from_name_badge"] = b
        set_like_tier(hh, "from_user_key")

    wi = payload.get("wager_intro_popup")
    if isinstance(wi, dict):
        for side in ("a", "b"):
            d = wi.get(side)
            if isinstance(d, dict):
                b = badge(str(d.get("user_key") or ""))
                if b:
                    d["name_badge"] = b
                set_like_tier(d, "user_key")

    lmb = payload.get("like_mvp_banner")
    if isinstance(lmb, dict):
        b = badge(str(lmb.get("user_key") or ""))
        if b:
            lmb["name_badge"] = b
        set_like_tier(lmb, "user_key")


def _image_mime(raw: bytes) -> str:
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if len(raw) > 12 and raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp"
    return "image/jpeg"


MAX_LOG = 120
_auto_next_delay_task: asyncio.Task | None = None
clients: set[WebSocket] = set()
event_log: deque[str] = deque(maxlen=MAX_LOG)
session: HangmanSession | None = None
game_lock = asyncio.Lock()
tiktok_username: str = ""
host_username: str = ""
auto_next: bool = True
tiktok_status: str = "starting"
tiktok_task: asyncio.Task | None = None
_tiktok_reconnect_lock = asyncio.Lock()
_like_mvp_loop_task: asyncio.Task | None = None
_like_mvp_award_lock = asyncio.Lock()
_lion_nuke_task: asyncio.Task | None = None
_lion_nuke_lock = asyncio.Lock()
_lion_nuke_deadline_unix: float | None = None
_lion_nuke_started_by_key: str = ""
_lion_nuke_started_by_name: str = ""
_lion_lock_chat_notice_last: dict[str, float] = {}
_lion_lock_gift_notice_last: dict[str, float] = {}
tt_client: TikTokLiveClient | None = None
_streamer_avatar_cache: dict[str, bytes | None] = {}
_player_avatar_cache: dict[str, bytes | None] = {}
_spotify_queue_allowlist: set[str] = set()
_spotify_allowlist_lock = threading.Lock()
# After sending a Galaxy gift, sender may type @username to take that player's all-time points (value = monotonic expiry).
galaxy_pending: dict[str, float] = {}
# After sending a Cap gift, sender may type @username to sideline that player for the next word only.
cap_ignore_pending: dict[str, float] = {}
# After Car Drifting gift, sender may type @username to trim that player's Racing Debut shield window.
car_drifting_pending: dict[str, float] = {}
# After Space Cat gift, sender may type @username to grant that player a Racing Debut shield (~48h).
space_cat_pending: dict[str, float] = {}
# When True, only fan-club / Heart Me viewers can play (see tiktok_comment_user).
fan_only_mode: bool = False
# Throttle fan-gate overlay spam per user_key (seconds between prompts).
_fan_gate_last: dict[str, float] = {}
FAN_GATE_THROTTLE_SEC = 22.0
# Per viewer_key: last time they triggered !how / !play / !rules (TikTok LIVE chat guide).
_tiktok_guide_last: dict[str, float] = {}
# TikTok LIVE like totals for header (session-local; reset on TikTok connect).
_live_like_lock: asyncio.Lock | None = None
_live_room_like_total_api: int = 0
_live_like_by_user: dict[str, int] = {}
_live_like_display_name: dict[str, str] = {}
_last_live_likes_push_wall: float = 0.0
# Per viewer: how many "10-like" blocks from this TikTok connection were converted to all-time points (like bonus).
_live_like_bonus_tens_cursor: dict[str, int] = {}

# Wall-clock anchors: ignore TikTok comment/gift backlog from before this process + delay (see _tiktok_event_is_current_session).
_wall_session_started: float = 0.0
_wall_tiktok_connected: float | None = None


def _event_create_unix(event: Any) -> float | None:
    """TikTok server time for the message (unix seconds), or None if missing."""
    try:
        bm = getattr(event, "base_message", None)
        if bm is None:
            return None
        t = int(getattr(bm, "create_time", 0) or 0)
        if t <= 0:
            return None
        # Heuristic: sub-second unix is ~1.7e9; ms since epoch is ~1.7e12
        if t > 10_000_000_000:
            t = t // 1000
        return float(t)
    except Exception:
        return None


def _min_chat_event_create_unix() -> float:
    """Process only events with create_time >= this (drops replay / old chat on connect)."""
    lag = os.environ.get("HANGMAN_CHAT_ONLY_AFTER_SESSION_SEC", "5").strip()
    try:
        extra = max(0.0, float(lag))
    except ValueError:
        extra = 5.0
    anchor = _wall_session_started
    if _wall_tiktok_connected is not None:
        anchor = max(anchor, _wall_tiktok_connected)
    return anchor + extra


def _tiktok_event_is_current_session(event: Any) -> bool:
    """
    False for backlog scraped on connect: event must be stamped at/after session start + lag
    (and after live connect when known). Events without create_time are accepted only once
    wall-clock time has passed the same cutoff (avoids untimestamped replay).
    """
    if os.environ.get("HANGMAN_CHAT_TIME_FILTER", "1").strip().lower() in ("0", "false", "no"):
        return True
    cutoff = _min_chat_event_create_unix()
    t = _event_create_unix(event)
    if t is not None:
        return t >= cutoff
    return time.time() >= cutoff


def _tiktok_like_event_is_current_session(event: Any) -> bool:
    """
    Same intent as ``_tiktok_event_is_current_session`` but allows ``create_time`` up to
    ``HANGMAN_LIKE_EVENT_BACKLOG_SEC`` **before** the chat cutoff. TikTok often stamps likes
    slightly earlier than our connect anchor; the strict chat filter would drop them and the
    overlay would show zero likes even while the LIVE is active.
    """
    if os.environ.get("HANGMAN_CHAT_TIME_FILTER", "1").strip().lower() in ("0", "false", "no"):
        return True
    cutoff = _min_chat_event_create_unix()
    try:
        backlog = max(0.0, float(os.environ.get("HANGMAN_LIKE_EVENT_BACKLOG_SEC", "900").strip()))
    except ValueError:
        backlog = 900.0
    like_floor = cutoff - backlog
    t = _event_create_unix(event)
    if t is not None:
        return t >= like_floor
    return time.time() >= cutoff


def _galaxy_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_GALAXY_GIFT_MATCH", "galaxy").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_GALAXY_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def _parse_galaxy_target(text: str) -> str | None:
    """Single @username / handle, not a !command (min length 2)."""
    t = (text or "").strip()
    if not t or t.startswith("!"):
        return None
    if any(c.isspace() for c in t):
        return None
    raw = t.lstrip("@")
    if len(raw) < 2:
        return None
    return raw


def _is_stream_host(uid: str, user_key: str) -> bool:
    """Host/broadcaster bypasses fans-only gate (matches TIKTOK_HOST_USERNAME / streamer @)."""
    h = normalize_lookup_token(host_username or "")
    if not h:
        return False
    return normalize_lookup_token(uid) == h or normalize_lookup_token(user_key) == h


def _resolve_spotify_queue_target_key(raw: str) -> str | None:
    """Map @handle or display name to a user_key (all-time row or someone in this Hangman session)."""
    t = (raw or "").strip().lstrip("@")
    if len(t) < 2:
        return None
    k = resolve_user_key_from_handle(t, ALLTIME_PATH)
    if k:
        return k
    if session is None:
        return None
    nt = normalize_lookup_token(t)
    for uk, p in session.players.items():
        if normalize_lookup_token(p.display_name) == nt:
            return uk
        if normalize_lookup_token(uk) == nt:
            return uk
    return None


def _session_user_key(uid: str, nick: str) -> str:
    """Stable key aligned with ``alltime_leaderboard.json`` rows (handles id vs handle drift)."""
    base = effective_tiktok_user_key(uid, nick)
    return canonical_alltime_key(base, nick, ALLTIME_PATH)


def _fan_gate_should_emit(user_key: str) -> bool:
    now = time.monotonic()
    last = _fan_gate_last.get(user_key, 0.0)
    if now - last < FAN_GATE_THROTTLE_SEC:
        return False
    _fan_gate_last[user_key] = now
    return True


def _ws_host_authorized(websocket: WebSocket, body_key: str | None) -> bool:
    expected = os.environ.get("HANGMAN_HOST_KEY", "").strip()
    if expected:
        return (body_key or "").strip() == expected
    host = websocket.client.host if websocket.client else ""
    return host in ("127.0.0.1", "::1", "localhost")


def _rosa_gift_match(gift_name: str, gift_id: int) -> bool:
    """
    Match Rosa by gift name tokens (HANGMAN_ROSA_GIFT_MATCH, comma-separated allowed) or IDs.
    Token match avoids missing gifts whose display name doesn't contain a raw substring (e.g. punctuation).
    """
    raw_ids = os.environ.get("HANGMAN_ROSA_GIFT_IDS", "").strip()
    if raw_ids and gift_id:
        ids = {int(x.strip()) for x in raw_ids.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    needles = [
        p.strip().lower()
        for p in (os.environ.get("HANGMAN_ROSA_GIFT_MATCH", "rosa") or "").split(",")
        if p.strip()
    ]
    if not needles:
        return False
    g_norm = re.sub(r"[^a-z0-9]+", " ", (gift_name or "").lower()).strip()
    tokens = [t for t in g_norm.split() if t]
    for needle in needles:
        n_norm = re.sub(r"[^a-z0-9]+", " ", needle).strip()
        if not n_norm:
            continue
        if n_norm in tokens:
            return True
        if len(n_norm) >= 3 and any(t.startswith(n_norm) for t in tokens):
            return True
    return False


def _cap_gift_match(gift_name: str, gift_id: int) -> bool:
    """Match Cap by substring (default 'cap') or HANGMAN_CAP_GIFT_IDS (comma-separated)."""
    needle = os.environ.get("HANGMAN_CAP_GIFT_MATCH", "cap").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_CAP_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def _racing_debut_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_RACING_DEBUT_GIFT_MATCH", "racing debut").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_RACING_DEBUT_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def _car_drifting_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_CAR_DRIFTING_GIFT_MATCH", "car drifting").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_CAR_DRIFTING_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def _space_cat_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_SPACE_CAT_GIFT_MATCH", "space cat").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_SPACE_CAT_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def _lion_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_LION_GIFT_MATCH", "lion").strip().lower()
    if needle:
        # Exact normalized name match only (avoid triggering on other lion-themed gifts).
        n_norm = re.sub(r"[^a-z0-9]+", " ", needle).strip()
        g_norm = re.sub(r"[^a-z0-9]+", " ", (gift_name or "").lower()).strip()
        if n_norm and g_norm and n_norm == g_norm:
            return True
    raw = os.environ.get("HANGMAN_LION_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def _money_gun_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_MONEY_GUN_GIFT_MATCH", "money gun").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_MONEY_GUN_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def _lion_nuke_window_sec() -> float:
    try:
        v = float(os.environ.get("HANGMAN_LION_NUKE_WINDOW_SEC", "300").strip())
    except ValueError:
        v = 300.0
    return max(10.0, min(v, 3600.0))


def _lion_nuke_payload() -> dict[str, Any] | None:
    if _lion_nuke_deadline_unix is None:
        return None
    return {
        "active": True,
        "deadline_unix": float(_lion_nuke_deadline_unix),
        "started_by_user_key": _lion_nuke_started_by_key,
        "started_by_name": _lion_nuke_started_by_name,
    }


def _lion_nuke_active_now() -> bool:
    return _lion_nuke_deadline_unix is not None and _lion_nuke_deadline_unix > time.time()


def _lion_lock_notice_allowed(bucket: dict[str, float], key: str, cooldown_sec: float = 12.0) -> bool:
    now = time.monotonic()
    k = (key or "").strip() or "anon"
    last = bucket.get(k, 0.0)
    if now - last < cooldown_sec:
        return False
    bucket[k] = now
    if len(bucket) > 800:
        for dk in list(bucket.keys())[:200]:
            bucket.pop(dk, None)
    return True


def _fmt_mmss(total_sec: float) -> str:
    s = max(0, int(total_sec))
    m = s // 60
    r = s % 60
    return f"{m:02d}:{r:02d}"


async def _run_lion_nuke_timer(expected_deadline_unix: float) -> None:
    global _lion_nuke_task, _lion_nuke_deadline_unix, _lion_nuke_started_by_key, _lion_nuke_started_by_name
    try:
        await asyncio.sleep(max(0.0, expected_deadline_unix - time.time()))
    except asyncio.CancelledError:
        return

    log_lines: list[str] = []
    async with _lion_nuke_lock:
        if _lion_nuke_deadline_unix is None:
            _lion_nuke_task = None
            return
        if abs(float(_lion_nuke_deadline_unix) - float(expected_deadline_unix)) > 0.01:
            return
        starter = _lion_nuke_started_by_name or _lion_nuke_started_by_key or "unknown"
        reset_count = reset_alltime_points_for_all_users(ALLTIME_PATH)
        _lion_nuke_deadline_unix = None
        _lion_nuke_started_by_key = ""
        _lion_nuke_started_by_name = ""
        _lion_nuke_task = None
        log_lines.append(
            f"[Lion Nuke] Countdown ended — all-time points reset to 0 for {reset_count} viewer(s)."
        )
        log_lines.append(f"[Lion Nuke] Triggered by @{starter}; no counter-Lion arrived in time.")

    for line in log_lines:
        print(line, flush=True)
    await push_state(log_lines)


def _gift_diamond_points_cap() -> int:
    try:
        return max(0, int(os.environ.get("HANGMAN_GIFT_DIAMOND_POINTS_CAP", "5000000").strip()))
    except ValueError:
        return 5000000


def _gift_diamond_ratio() -> float:
    """All-time points per TikTok diamond (default 0.1 = 1 pt per 10 diamonds)."""
    try:
        return max(0.0, float(os.environ.get("HANGMAN_GIFT_DIAMOND_RATIO", "0.1").strip()))
    except ValueError:
        return 0.1


def _gift_diamond_alltime_points_enabled() -> bool:
    return os.environ.get("HANGMAN_GIFT_DIAMOND_POINTS", "1").strip().lower() not in ("0", "false", "no")


def _gift_diamond_alltime_points(event: GiftEvent) -> int:
    """
    Map TikTok gift diamonds → all-time points (``diamonds × HANGMAN_GIFT_DIAMOND_RATIO``, floored).
    Streak handler runs only on the final segment, so ``repeat_count`` should reflect the full combo when present.
    """
    if not _gift_diamond_alltime_points_enabled():
        return 0
    gift = event.gift
    try:
        per = int(getattr(gift, "diamond_count", 0) or 0)
    except (TypeError, ValueError):
        per = 0
    if per <= 0:
        return 0
    use_repeat = os.environ.get("HANGMAN_GIFT_DIAMOND_USE_REPEAT", "1").strip().lower() not in (
        "0",
        "false",
        "no",
    )
    mult = 1
    if use_repeat:
        try:
            rpt = int(getattr(event, "repeat_count", 0) or 0)
        except (TypeError, ValueError):
            rpt = 0
        mult = rpt if rpt > 0 else 1
    diamonds = int(per) * int(mult)
    ratio = _gift_diamond_ratio()
    pts = int(math.floor(float(diamonds) * ratio + 1e-12))
    pts = max(0, pts)
    cap = _gift_diamond_points_cap()
    if cap > 0 and pts > cap:
        return cap
    return pts


def _gift_debug_enabled() -> bool:
    return os.environ.get("HANGMAN_DEBUG_GIFTS", "").strip().lower() in ("1", "true", "yes", "on")


def _gift_debug(msg: str) -> None:
    if _gift_debug_enabled():
        print(f"[GiftDebug] {msg}", flush=True)


def _car_drifting_trim_hours() -> float:
    try:
        return max(0.0, float(os.environ.get("HANGMAN_CAR_DRIFTING_TRIM_HOURS", "48").strip()))
    except ValueError:
        return 48.0


def _resolve_cap_ignore_target(raw: str) -> str | None:
    """Resolve @handle to user_key: session players (key or display name), then all-time leaderboard."""
    if session is None:
        return None
    s = normalize_lookup_token(raw or "")
    if len(s) < 2:
        return None
    for key, p in session.players.items():
        if normalize_lookup_token(key) == s:
            return key
        dn = normalize_lookup_token(p.display_name or "")
        if dn and dn == s:
            return key
    return resolve_user_key_from_handle(raw, ALLTIME_PATH)


def _append_logs(lines: list[str]) -> None:
    for line in lines:
        if line.strip():
            event_log.append(line)


async def broadcast_json(payload: dict[str, Any]) -> None:
    dead: list[WebSocket] = []
    text = json.dumps(payload)
    for ws in clients:
        try:
            await ws.send_text(text)
        except Exception:
            dead.append(ws)
    for ws in dead:
        clients.discard(ws)


def _like_mvp_points() -> int:
    try:
        return max(1, int(os.environ.get("HANGMAN_LIKE_MVP_POINTS", "2000").strip()))
    except ValueError:
        return 2000


def _like_mvp_payout_tz() -> datetime.tzinfo:
    """
    IANA names use ``zoneinfo``; on Windows the ``tzdata`` PyPI package is required for most zones.
    ``UTC`` / ``GMT`` fall back to ``datetime.timezone.utc`` when no tz database is installed.
    """
    raw = (os.environ.get("HANGMAN_LIKE_MVP_PAYOUT_TZ", "UTC") or "UTC").strip()
    if raw.upper() in ("UTC", "GMT", "ETC/UTC"):
        try:
            return ZoneInfo("UTC")
        except Exception:
            return timezone.utc
    try:
        return ZoneInfo(raw)
    except Exception:
        print(
            f"[Like MVP] Unknown or unavailable timezone {raw!r} — using UTC. "
            f"On Windows, run: pip install tzdata",
            flush=True,
        )
        try:
            return ZoneInfo("UTC")
        except Exception:
            return timezone.utc


def _like_mvp_payout_hm() -> tuple[int, int]:
    try:
        h = int(os.environ.get("HANGMAN_LIKE_MVP_PAYOUT_HOUR", "0").strip())
    except ValueError:
        h = 0
    try:
        m = int(os.environ.get("HANGMAN_LIKE_MVP_PAYOUT_MINUTE", "0").strip())
    except ValueError:
        m = 0
    return (max(0, min(23, h)), max(0, min(59, m)))


def _like_mvp_catchup_max() -> int:
    try:
        return max(1, min(366, int(os.environ.get("HANGMAN_LIKE_MVP_CATCHUP_MAX", "8").strip())))
    except ValueError:
        return 8


def _like_mvp_slot_unix_for_local_date(d: date, tz: datetime.tzinfo, hour: int, minute: int) -> float:
    dt = datetime.combine(d, dt_time(hour, minute, 0, tzinfo=tz))
    return float(dt.timestamp())


def _like_mvp_floor_slot_unix(ts: float, tz: datetime.tzinfo, hour: int, minute: int) -> float:
    loc = datetime.fromtimestamp(ts, tz)
    return _like_mvp_slot_unix_for_local_date(loc.date(), tz, hour, minute)


def _like_mvp_next_slot_after(slot_unix: float, tz: datetime.tzinfo, hour: int, minute: int) -> float:
    loc = datetime.fromtimestamp(slot_unix, tz)
    nxt = loc.date() + timedelta(days=1)
    return _like_mvp_slot_unix_for_local_date(nxt, tz, hour, minute)


def _like_mvp_next_payout_unix(now: float | None = None) -> float:
    """Next daily payout instant strictly after ``now`` (wall clock in payout TZ)."""
    t = time.time() if now is None else float(now)
    tz = _like_mvp_payout_tz()
    h, m = _like_mvp_payout_hm()
    loc = datetime.fromtimestamp(t, tz)
    today_slot = _like_mvp_slot_unix_for_local_date(loc.date(), tz, h, m)
    if t < today_slot:
        return today_slot
    nxt_d = loc.date() + timedelta(days=1)
    return _like_mvp_slot_unix_for_local_date(nxt_d, tz, h, m)


def _like_mvp_read_clock_raw() -> dict[str, Any]:
    try:
        if LIKE_MVP_CLOCK_PATH.exists():
            raw = json.loads(LIKE_MVP_CLOCK_PATH.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                return raw
    except Exception:
        pass
    return {}


def _like_mvp_load_last_awarded_slot() -> float | None:
    raw = _like_mvp_read_clock_raw()
    v = raw.get("last_awarded_slot_unix")
    if v is None:
        return None
    try:
        x = float(v)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(x):
        return None
    return x


def _like_mvp_save_last_awarded_slot(last_slot: float) -> None:
    raw = _like_mvp_read_clock_raw()
    raw["last_awarded_slot_unix"] = float(last_slot)
    raw.pop("next_payout_unix", None)
    LIKE_MVP_CLOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    LIKE_MVP_CLOCK_PATH.write_text(json.dumps(raw, indent=2) + "\n", encoding="utf-8")


def _like_mvp_due_slots(last_awarded: float | None, now: float) -> list[float]:
    """Slot instants already passed (<= now) but not yet paid (exclusive of ``last_awarded``)."""
    tz = _like_mvp_payout_tz()
    h, m = _like_mvp_payout_hm()
    cap = _like_mvp_catchup_max()
    out: list[float] = []
    if last_awarded is None:
        s = _like_mvp_floor_slot_unix(now, tz, h, m)
        if s <= now:
            out.append(s)
        return out[:cap]
    s = _like_mvp_next_slot_after(last_awarded, tz, h, m)
    while s <= now and len(out) < cap:
        out.append(s)
        s = _like_mvp_next_slot_after(s, tz, h, m)
    return out


def _like_mvp_banner_payload() -> dict[str, Any]:
    nxt = _like_mvp_next_payout_unix()
    pts = _like_mvp_points()
    row = top_live_likes_lifetime_holder(ALLTIME_PATH)
    base: dict[str, Any] = {
        "payout_at_unix": nxt,
        "reward_points": pts,
    }
    if row:
        return {**base, **row}
    return {
        **base,
        "user_key": "",
        "name": "",
        "live_likes_lifetime": 0,
        "name_badge": None,
        "like_cosmetic_tier": 0,
    }


def _like_mvp_banner_payload_safe() -> dict[str, Any]:
    """Never raise — a broken Like-MVP clock must not block ``live_likes`` or the rest of the payload."""
    try:
        return _like_mvp_banner_payload()
    except Exception as e:
        print(f"[Like MVP] banner payload error (non-fatal): {e!s}", flush=True)
        return {
            "payout_at_unix": time.time() + 86400.0,
            "reward_points": _like_mvp_points(),
            "user_key": "",
            "name": "",
            "live_likes_lifetime": 0,
            "name_badge": None,
            "like_cosmetic_tier": 0,
        }


async def _like_mvp_maybe_award_and_push() -> None:
    """
    Pay out due Like-MVP slot(s) atomically: award slot, reset lifetime likes, advance clock.

    Important: for each due slot, ``last_awarded_slot_unix`` is written only *after*
    ``reset_all_live_likes_lifetime`` succeeds. This avoids duplicate awards after restarts and
    ensures old ``live_likes_lifetime`` totals cannot be reused across slots.
    """
    now = time.time()
    pts = _like_mvp_points()
    tz = _like_mvp_payout_tz()
    log_lines: list[str] = []
    async with _like_mvp_award_lock:
        last = _like_mvp_load_last_awarded_slot()
        due = _like_mvp_due_slots(last, now)
        if not due:
            return
        next_human = datetime.fromtimestamp(_like_mvp_next_payout_unix(now), tz).strftime("%Y-%m-%d %H:%M %Z")
        for slot_unix in due:
            leader = top_live_likes_lifetime_holder(ALLTIME_PATH)
            slot_label = datetime.fromtimestamp(slot_unix, tz).strftime("%Y-%m-%d %H:%M")
            awarded_this_slot = False
            if leader:
                uk = str(leader["user_key"])
                nm = str(leader.get("name") or uk).strip() or uk
                add_points(uk, nm, pts, ALLTIME_PATH)
                awarded_this_slot = True
                log_lines.append(
                    f"[Like MVP] @{nm} +{pts} all-time points (top lifetime LIVE likes) for slot {slot_label}. "
                    f"Next: {next_human}."
                )
                print(log_lines[-1], flush=True)
            else:
                log_lines.append(
                    f"[Like MVP] No lifetime likes on file yet — bonus skipped for slot {slot_label}. "
                    f"Next: {next_human}."
                )
                print(log_lines[-1], flush=True)
            # Reset like-lifetime totals immediately after each awarded slot.
            # This does not touch current live-session like counters.
            if awarded_this_slot:
                n_reset = reset_all_live_likes_lifetime(ALLTIME_PATH)
                line = (
                    f"[Like MVP] Reset lifetime LIVE like counts to 0 for {n_reset} viewer(s) "
                    f"(next contest starts fresh)."
                )
                log_lines.append(line)
                print(line, flush=True)
                w_n = _reset_wordwich_alltime_likes_json()
                if w_n > 0:
                    wline = (
                        f"[Like MVP] Reset Wordwich local like totals for {w_n} leaderboard row(s) "
                        "(same contest period as Hangman)."
                    )
                    log_lines.append(wline)
                    print(wline, flush=True)
            # Advance clock per slot so catch-up runs are crash-safe.
            _like_mvp_save_last_awarded_slot(float(slot_unix))
    if log_lines:
        await push_state(log_lines)


async def _like_mvp_loop() -> None:
    while True:
        try:
            await asyncio.sleep(8)
            await _like_mvp_maybe_award_and_push()
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"[Like MVP] scheduler error: {e!s}", flush=True)


def _cancel_auto_next_delay_task() -> None:
    global _auto_next_delay_task
    t = _auto_next_delay_task
    if t is not None and not t.done():
        t.cancel()
    _auto_next_delay_task = None


async def _run_delayed_auto_next(expected_round_id: int, delay_sec: float) -> None:
    try:
        await asyncio.sleep(delay_sec)
    except asyncio.CancelledError:
        return
    global session, auto_next
    async with game_lock:
        if session is None:
            return
        if _lion_nuke_active_now():
            return
        if session.round_id != expected_round_id:
            return
        if not auto_next:
            return
        session.random_new_word()
        next_lines = [f"Next word ({len(session.secret)} letters): {session.mask()}"]
    await push_state(next_lines)


async def push_state(
    log_lines: list[str] | None = None,
    round_popup: dict[str, Any] | None = None,
    hint_popup: dict[str, Any] | None = None,
    points_popup: dict[str, Any] | None = None,
    galaxy_popup: dict[str, Any] | None = None,
    cap_popup: dict[str, Any] | None = None,
    fan_gate_popup: dict[str, Any] | None = None,
    command_list_popup: dict[str, Any] | None = None,
    shield_trim_popup: dict[str, Any] | None = None,
    hangman_help_popup: dict[str, Any] | None = None,
    wager_intro_popup: dict[str, Any] | None = None,
) -> None:
    assert session is not None
    if log_lines:
        _append_logs(log_lines)
    payload: dict[str, Any] = {
        "type": "update",
        "logs": list(event_log),
        "state": _snapshot_with_cosmetics(),
        "alltime": _alltime_payload(),
        "shield_grace_windows": _shield_grace_windows_payload(),
        "tiktok": tiktok_username,
        "tiktok_status": tiktok_status,
        "fan_only_mode": fan_only_mode,
        "lion_nuke": _lion_nuke_payload(),
        "live_likes": await _live_likes_snapshot(),
        "like_mvp_banner": _like_mvp_banner_payload_safe(),
    }
    if round_popup is not None:
        payload["round_popup"] = round_popup
    if hint_popup is not None:
        payload["hint_popup"] = hint_popup
    if points_popup is not None:
        payload["points_popup"] = points_popup
    if galaxy_popup is not None:
        payload["galaxy_popup"] = galaxy_popup
    if cap_popup is not None:
        payload["cap_popup"] = cap_popup
    if fan_gate_popup is not None:
        payload["fan_gate_popup"] = fan_gate_popup
    if command_list_popup is not None:
        payload["command_list_popup"] = command_list_popup
    if shield_trim_popup is not None:
        payload["shield_trim_popup"] = shield_trim_popup
    if hangman_help_popup is not None:
        payload["hangman_help_popup"] = hangman_help_popup
    if wager_intro_popup is not None:
        payload["wager_intro_popup"] = wager_intro_popup
    _inject_name_badges_into_payload(payload)
    await broadcast_json(payload)


def _live_like_lock_get() -> asyncio.Lock:
    global _live_like_lock
    if _live_like_lock is None:
        _live_like_lock = asyncio.Lock()
    return _live_like_lock


def _reset_live_like_stats() -> None:
    global _live_room_like_total_api, _live_like_by_user, _live_like_display_name, _last_live_likes_push_wall
    global _live_like_bonus_tens_cursor
    _live_room_like_total_api = 0
    _live_like_by_user.clear()
    _live_like_display_name.clear()
    _last_live_likes_push_wall = 0.0
    _live_like_bonus_tens_cursor.clear()


async def _apply_like_event_for_stats(event: LikeEvent) -> None:
    ui = getattr(event, "user", None)
    uid, nick = stable_user_key_and_name(ui)
    key = _session_user_key(uid, nick)
    try:
        burst = int(getattr(event, "count", 0) or 0)
    except (TypeError, ValueError):
        burst = 0
    if burst < 1:
        burst = 1
    try:
        room_total = int(getattr(event, "total", 0) or 0)
    except (TypeError, ValueError):
        room_total = 0
    lock = _live_like_lock_get()
    async with lock:
        global _live_room_like_total_api
        if room_total > 0:
            _live_room_like_total_api = max(_live_room_like_total_api, room_total)
        _live_like_by_user[key] = int(_live_like_by_user.get(key, 0)) + burst
        _live_like_display_name[key] = (nick or "").strip() or key
        session_total = int(_live_like_by_user[key])
        tens_cursor = int(_live_like_bonus_tens_cursor.get(key, 0))
        new_cursor, like_pts = try_award_live_like_alltime_bonus(
            key,
            (nick or "").strip() or key,
            session_total,
            tens_cursor,
            ALLTIME_PATH,
        )
        if new_cursor != tens_cursor:
            _live_like_bonus_tens_cursor[key] = new_cursor
        if like_pts > 0:
            print(
                f"[Hangman] Like bonus +{like_pts} all-time for {key!r} ({session_total} likes this live; "
                f"max +500 from likes per UTC day, not session score).",
                flush=True,
            )
        if key and key != "anon":
            _lt_new, new_ltier, old_ltier = record_live_likes_lifetime(
                key, (nick or "").strip() or key, burst, ALLTIME_PATH
            )
            if new_ltier > old_ltier:
                print(
                    f"[Hangman] LIVE like cosmetic tier {new_ltier} for {key!r} "
                    f"({_lt_new:,} lifetime likes on stream).",
                    flush=True,
                )


async def _live_likes_snapshot() -> dict[str, Any]:
    lock = _live_like_lock_get()
    async with lock:
        api_t = int(_live_room_like_total_api)
        by_u = dict(_live_like_by_user)
        names = dict(_live_like_display_name)
    summed = sum(int(v) for v in by_u.values())
    total = max(api_t, summed) if api_t > 0 else summed
    ranked = sorted(by_u.items(), key=lambda x: (-int(x[1]), str(x[0])))[:3]
    top: list[dict[str, Any]] = []
    for uk, nlikes in ranked:
        nm = str(names.get(uk) or uk)
        row: dict[str, Any] = {"user_key": uk, "name": nm, "likes": int(nlikes)}
        nb = user_name_badge(str(uk), ALLTIME_PATH)
        if nb:
            row["name_badge"] = nb
        lt = user_like_cosmetic_tier(str(uk), ALLTIME_PATH)
        if lt > 0:
            row["like_cosmetic_tier"] = lt
        top.append(row)
    return {"total": int(total), "top": top}


async def _maybe_push_after_like_event() -> None:
    global _last_live_likes_push_wall
    try:
        min_gap = max(0.05, float(os.environ.get("HANGMAN_LIVE_LIKES_PUSH_SEC", "0.22").strip()))
    except ValueError:
        min_gap = 0.22
    now = time.monotonic()
    if now - _last_live_likes_push_wall < min_gap:
        return
    _last_live_likes_push_wall = now
    await push_state([])


def _tiktok_guide_triggers() -> frozenset[str]:
    raw = os.environ.get("HANGMAN_TIKTOK_GUIDE_COMMANDS", "!how,!play,!rules,!howtoplay")
    parts = [p.strip().lower() for p in raw.split(",") if p.strip()]
    if not parts:
        parts = ["!how", "!play", "!rules", "!howtoplay"]
    return frozenset(parts)


def _tiktok_chat_posting_configured() -> bool:
    sid = os.environ.get("TIKTOK_CHAT_SESSION_ID", "").strip()
    idc = os.environ.get("TIKTOK_CHAT_TT_TARGET_IDC", "").strip()
    return bool(sid and idc)


def _tiktok_guide_cooldown_sec() -> float:
    try:
        return max(5.0, float(os.environ.get("HANGMAN_TIKTOK_GUIDE_COOLDOWN_SEC", "45").strip()))
    except ValueError:
        return 45.0


def _split_tiktok_chat_chunks(text: str, max_len: int = 160) -> list[str]:
    text = " ".join((text or "").split())
    if not text:
        return []
    if len(text) <= max_len:
        return [text]
    chunks: list[str] = []
    rest = text
    while rest:
        if len(rest) <= max_len:
            chunks.append(rest)
            break
        cut = rest.rfind(" ", 0, max_len)
        if cut < max_len // 2:
            cut = max_len
        chunks.append(rest[:cut].rstrip())
        rest = rest[cut:].lstrip()
    return chunks


def _tiktok_play_guide_chunks() -> list[str]:
    custom = os.environ.get("TIKTOK_PLAY_GUIDE_MESSAGE", "").strip()
    if custom:
        body = custom.replace("\\n", "\n")
    else:
        body = (
            "How to play Hangman here: guess one letter (A–Z) in chat or use !guess T. "
            "Right letter +10 pts, wrong −10. Guess the full answer with !YOUR PHRASE or !word PHRASE. "
            "!points shows your all-time score. Type !help for more. Good luck!"
        )
    return _split_tiktok_chat_chunks(body)


async def _post_tiktok_play_guide_to_live() -> tuple[bool, str]:
    """
    Post rules text to the current LIVE room as TIKTOK_CHAT_SESSION_ID (via TikTokLive send_room_chat).
    Returns (ok, one line for game log / overlay).
    """
    global tt_client
    if tt_client is None:
        return False, "[Guide] TikTok client not ready yet."
    rid = tt_client.room_id
    if rid is None:
        return False, "[Guide] No room id yet — wait until the LIVE connection is up."
    if not _tiktok_chat_posting_configured():
        return (
            False,
            "[Guide] Set TIKTOK_CHAT_SESSION_ID, TIKTOK_CHAT_TT_TARGET_IDC, and "
            "WHITELIST_AUTHENTICATED_SESSION_ID_HOST=tiktok.eulerstream.com to post in LIVE chat.",
        )
    chunks = _tiktok_play_guide_chunks()
    if not chunks:
        return False, "[Guide] TIKTOK_PLAY_GUIDE_MESSAGE is empty."
    try:
        for i, chunk in enumerate(chunks):
            await tt_client.send_room_chat(chunk)
            if i < len(chunks) - 1:
                await asyncio.sleep(0.45)
    except Exception as e:
        return False, f"[Guide] TikTok chat post failed: {e!s}"
    return True, f"[Guide] Posted how-to-play ({len(chunks)} msg(s)) to TikTok LIVE chat."


async def _handle_spotify_queue_admin(text: str, nick: str, uid: str, user_key: str) -> bool:
    """Broadcaster-only: !hqueueallow / !hqueuedeny / !hqueueremove / !hqueuelist (Hangman-prefixed)."""
    raw = (text or "").strip()
    if not raw.startswith("!"):
        return False
    parts = raw.split(maxsplit=1)
    cmd = hangman_spotify_admin_command(raw)
    if not cmd:
        return False
    cmd = cmd.lower()
    if not _is_stream_host(uid, user_key):
        await push_state(["[Spotify] Only the broadcaster can manage the Hangman !hqueue allowlist."])
        return True
    arg = (parts[1] if len(parts) > 1 else "").strip()

    if cmd in ("!hqueuelist", "!hangmanqueuelist"):
        with _spotify_allowlist_lock:
            keys = sorted(_spotify_queue_allowlist)
        if not keys:
            await push_state(["[Spotify] No extra viewers can use !hqueue (besides the broadcaster)."])
            return True
        labels: list[str] = []
        for k in keys:
            lab = (display_name_for_key(k, ALLTIME_PATH) or "").strip() or k
            labels.append(lab)
            await push_state([f"[Spotify] Can use !hqueue / !hsong: {', '.join(labels)}"])
        return True

    if cmd in ("!hqueuedeny", "!hqueueremove", "!hangmanqueuedeny", "!hangmanqueueremove"):
        if not arg:
            await push_state(["[Spotify] Usage: !hqueuedeny @viewer (alias: !hqueueremove)"])
            return True
        target = _resolve_spotify_queue_target_key(arg)
        if not target:
            await push_state(
                [f'[Spotify] No viewer matched "{arg}" — try @handle or someone who chatted this stream.']
            )
            return True
        hh = normalize_lookup_token(host_username or "")
        if hh and normalize_lookup_token(target) == hh:
            await push_state(["[Spotify] The broadcaster does not need to be on this list."])
            return True
        with _spotify_allowlist_lock:
            was = target in _spotify_queue_allowlist
            if was:
                _spotify_queue_allowlist.discard(target)
                snap = set(_spotify_queue_allowlist)
            else:
                snap = None
        if not was:
            lab = (display_name_for_key(target, ALLTIME_PATH) or "").strip() or target
            await push_state([f"[Spotify] {lab} was not on the !queue list."])
            return True
        assert snap is not None
        await asyncio.to_thread(save_allowed_keys, SPOTIFY_QUEUE_ALLOWLIST_PATH, snap)
        lab = (display_name_for_key(target, ALLTIME_PATH) or "").strip() or target
        await push_state([f"[Spotify] Removed {lab} from !queue access."])
        return True

    if not arg:
        await push_state(["[Spotify] Usage: !hqueueallow @viewer"])
        return True
    target = _resolve_spotify_queue_target_key(arg)
    if not target:
        await push_state(
            [f'[Spotify] No viewer matched "{arg}" — they need an all-time row or to chat once this stream.']
        )
        return True
    hh = normalize_lookup_token(host_username or "")
    if hh and normalize_lookup_token(target) == hh:
        await push_state(["[Spotify] You're the broadcaster — you can already use !hqueue / !hsong."])
        return True
    with _spotify_allowlist_lock:
        already = target in _spotify_queue_allowlist
    if already:
        lab = (display_name_for_key(target, ALLTIME_PATH) or "").strip() or target
        await push_state([f"[Spotify] {lab} can already use !hqueue."])
        return True
    with _spotify_allowlist_lock:
        _spotify_queue_allowlist.add(target)
        snap = set(_spotify_queue_allowlist)
    await asyncio.to_thread(save_allowed_keys, SPOTIFY_QUEUE_ALLOWLIST_PATH, snap)
    lab = (display_name_for_key(target, ALLTIME_PATH) or "").strip() or target
    await push_state([f"[Spotify] {lab} can now use !hqueue / !hsong / !haddsong."])
    return True


async def _handle_spotify_queue_chat(text: str, nick: str, uid: str, user_key: str) -> bool:
    """!hqueue / !hsong / !haddsong — Hangman Spotify queue (does not use bare !song / !queue)."""
    raw = (text or "").strip()
    m = hangman_spotify_queue_match(raw)
    if not m:
        if raw.lower().startswith("!") and raw.lower().split(maxsplit=1)[0] in (
            "!song",
            "!queue",
            "!addsong",
        ):
            await push_state([legacy_spotify_hint()])
            return True
        return False
    arg = (m.group(1) or "").strip()
    with _spotify_allowlist_lock:
        allow_snap = set(_spotify_queue_allowlist)
    out = await asyncio.to_thread(
        spotify_queue_chat_lines,
        arg=arg,
        uid=uid,
        user_key=user_key,
        nick=nick,
        host_username=host_username,
        allowlist=allow_snap,
    )
    await push_state(out)
    if out and out[0].startswith("[Spotify] Queued:"):
        print(f"[Hangman] Spotify queued: {out[0]}", flush=True)
    return True


async def _handle_tiktok_play_guide_comment(text: str, user_key: str, nick: str) -> bool:
    """If text is a guide trigger, post to TikTok chat (when configured) and return True."""
    t = text.strip().lower()
    triggers = _tiktok_guide_triggers()
    if not triggers or t not in triggers:
        return False
    now = time.monotonic()
    key = (user_key or nick or "anon").strip() or "anon"
    cd = _tiktok_guide_cooldown_sec()
    last = _tiktok_guide_last.get(key, 0.0)
    if now - last < cd:
        left = int(math.ceil(cd - (now - last)))
        line = f"[Guide] @{nick or key}: wait {left}s before asking for the rules again."
        print(line, flush=True)
        await push_state([line])
        return True
    _tiktok_guide_last[key] = now
    ok, msg = await _post_tiktok_play_guide_to_live()
    print(msg, flush=True)
    await push_state([msg])
    return True


def setup_tiktok_client() -> TikTokLiveClient:
    assert session is not None
    client = TikTokLiveClient(unique_id=tiktok_username)
    sid = os.environ.get("TIKTOK_CHAT_SESSION_ID", "").strip()
    idc = os.environ.get("TIKTOK_CHAT_TT_TARGET_IDC", "").strip()
    if sid and idc:
        client.web.set_session(sid, idc)

    @client.on(ConnectEvent)
    async def _on_tt_connect(_: ConnectEvent) -> None:
        global tiktok_status, _wall_tiktok_connected
        tiktok_status = "connected"
        _wall_tiktok_connected = time.time()
        _reset_live_like_stats()
        await push_state([])

    @client.on(DisconnectEvent)
    async def _on_tt_disconnect(_: DisconnectEvent) -> None:
        global tiktok_status
        tiktok_status = "disconnected"
        _reset_live_like_stats()
        await push_state(["[System] TikTok feed disconnected — go live or check username."])

    @client.on(LikeEvent)
    async def _on_like(event: LikeEvent) -> None:
        """Track session like totals + top likers."""
        try:
            if not _tiktok_like_event_is_current_session(event):
                return
            await _apply_like_event_for_stats(event)
            await _maybe_push_after_like_event()
        except Exception as e:
            print(f"[Hangman] LikeEvent handler error (non-fatal): {e!s}", flush=True)

    @client.on(CommentEvent)
    async def on_comment(event: CommentEvent) -> None:
        if not _tiktok_event_is_current_session(event):
            return
        text = normalize_chat_for_letter_parse((event.comment or "").strip())
        uid, nick = extract_comment_author(event)
        user_key = _session_user_key(uid, nick)
        if is_nfg_crash_chat_noise(text) or is_nfg_crash_spotify_noise(text):
            return
        if parse_link_command(text):
            link_out = forward_tiktok_link_to_platform(
                user_id=uid,
                display_name=nick,
                message=text,
            )
            reply = str(link_out.get("tiktokChatReply") or "").strip()
            if reply:
                await push_state([f"[Link] {reply}"])
                if _tiktok_chat_posting_configured() and tt_client is not None:
                    for chunk in _split_tiktok_chat_chunks(reply):
                        try:
                            await tt_client.send_room_chat(chunk)
                        except Exception:
                            break
            return
        if _lion_nuke_active_now():
            if _lion_lock_notice_allowed(_lion_lock_chat_notice_last, user_key):
                left = max(0, int((_lion_nuke_deadline_unix or 0) - time.time()))
                await push_state(
                    [
                        f"[Lion Nuke] Gameplay paused ({left // 60}:{left % 60:02d} left). "
                        "No guesses, commands, or point usage until canceled or timer ends."
                    ]
                )
            return
        if await _handle_tiktok_play_guide_comment(text, user_key, nick):
            return
        if await _handle_spotify_queue_admin(text, nick, uid, user_key):
            return
        if await _handle_spotify_queue_chat(text, nick, uid, user_key):
            return
        if text.lower() == "!hangman":
            assert session is not None
            async with game_lock:
                h_lines, _, _, _, _, _, hpop, _ = process_chat_message(
                    session,
                    text=text,
                    uid=uid,
                    user_key=user_key,
                    nick=nick,
                    host_username=host_username,
                    auto_next=auto_next,
                    alltime_path=ALLTIME_PATH,
                )
            if h_lines or hpop:
                await push_state(h_lines, hangman_help_popup=hpop)
            return
        if fan_only_mode and not _is_stream_host(uid, user_key):
            if not comment_user_is_fan_club_member(event):
                if _fan_gate_should_emit(user_key):
                    await push_state(
                        [],
                        fan_gate_popup={
                            "name": nick,
                            "user_key": user_key,
                            "duration_ms": 7000,
                        },
                    )
                return
        galaxy_lines: list[str] = []
        cap_lines: list[str] = []
        car_drift_lines: list[str] = []
        space_cat_lines: list[str] = []
        galaxy_popup_payload: dict[str, Any] | None = None
        cap_popup_payload: dict[str, Any] | None = None
        car_drift_popup_payload: dict[str, Any] | None = None
        consume_chat = False
        now = time.monotonic()
        async with game_lock:
            for k in [x for x in galaxy_pending if galaxy_pending[x] <= now]:
                galaxy_pending.pop(k, None)
            for k in [x for x in cap_ignore_pending if cap_ignore_pending[x] <= now]:
                cap_ignore_pending.pop(k, None)
            for k in [x for x in car_drifting_pending if car_drifting_pending[x] <= now]:
                car_drifting_pending.pop(k, None)
            for k in [x for x in space_cat_pending if space_cat_pending[x] <= now]:
                space_cat_pending.pop(k, None)
            exp = galaxy_pending.get(user_key)
            if exp is not None and exp > now:
                target_raw = _parse_galaxy_target(text)
                if target_raw:
                    consume_chat = True
                    resolved = resolve_user_key_from_handle(target_raw, ALLTIME_PATH)
                    if resolved is None:
                        galaxy_lines.append(
                            f'[Galaxy] @{nick}: no all-time entry matched "{target_raw}". Try their @username.'
                        )
                    elif resolved == user_key:
                        galaxy_lines.append(
                            f"[Galaxy] @{nick}: you can't take all-time points from yourself."
                        )
                    elif is_protected(resolved, SHIELD_PATH):
                        exp = shield_expiry_unix(resolved, SHIELD_PATH)
                        vlab = display_name_for_key(resolved, ALLTIME_PATH)
                        galaxy_lines.append(
                            f"[Galaxy] @{nick}: {vlab} is protected from Galaxy steals (Racing Debut) "
                            f"— {_fmt_shield_remaining(exp) if exp else 'active'}."
                        )
                    elif is_shield_drop_grace_active(resolved):
                        vlab = display_name_for_key(resolved, ALLTIME_PATH)
                        until = shield_drop_grace_until(resolved)
                        left = max(0, int((until or 0) - time.time()))
                        galaxy_lines.append(
                            f"[Galaxy] @{nick}: {vlab} can re-buy with Racing Debut — Galaxy steals paused "
                            f"({left // 60}:{left % 60:02d} left)."
                        )
                    else:
                        ok, moved, victim_label = transfer_alltime_points(
                            resolved, user_key, nick, ALLTIME_PATH
                        )
                        if ok:
                            galaxy_pending.pop(user_key, None)
                            galaxy_lines.append(
                                f"[Galaxy] @{nick} took {moved} all-time pts from {victim_label} "
                                f"— new total added to @{nick}."
                            )
                            galaxy_popup_payload = {
                                "from_name": nick,
                                "from_user_key": user_key,
                                "victim_name": victim_label,
                                "victim_user_key": resolved,
                                "points": moved,
                                "duration_ms": 8500,
                            }
                            print(
                                f"[Hangman] Galaxy transfer: {moved} pts from {resolved!r} to {user_key!r}",
                                flush=True,
                            )
                        else:
                            if victim_label:
                                galaxy_lines.append(
                                    f"[Galaxy] @{nick}: {victim_label} has no all-time points to take."
                                )
                            else:
                                galaxy_lines.append("[Galaxy] That all-time entry was removed; try again.")

            if not consume_chat:
                cexp = cap_ignore_pending.get(user_key)
                if cexp is not None and cexp > now:
                    target_raw = _parse_galaxy_target(text)
                    if target_raw:
                        consume_chat = True
                        assert session is not None
                        resolved = _resolve_cap_ignore_target(target_raw)
                        if resolved is None:
                            cap_lines.append(
                                f'[Cap] @{nick}: nobody matched "{target_raw}". '
                                f"Use @username or a name from this session's leaderboard."
                            )
                        elif resolved == user_key:
                            cap_lines.append(
                                f"[Cap] @{nick}: pick someone else to sideline (not yourself)."
                            )
                        else:
                            session.queue_ignore_next_round(resolved)
                            cap_ignore_pending.pop(user_key, None)
                            vp = session.players.get(resolved)
                            vlab = (vp.display_name if vp else None) or resolved
                            cap_lines.append(
                                f"[Cap] @{nick} — {vlab} can't play the next word. Current word unchanged."
                            )
                            cap_popup_payload = {
                                "from_name": nick,
                                "from_user_key": user_key,
                                "victim_name": vlab,
                                "victim_user_key": resolved,
                                "duration_ms": 8500,
                            }
                            print(
                                f"[Hangman] Cap sideline queued for next word: victim={resolved!r} by {user_key!r}",
                                flush=True,
                            )

            if not consume_chat:
                drexp = car_drifting_pending.get(user_key)
                if drexp is not None and drexp > now:
                    target_raw = _parse_galaxy_target(text)
                    if target_raw:
                        consume_chat = True
                        resolved = resolve_user_key_from_handle(target_raw, ALLTIME_PATH)
                        trim_h = _car_drifting_trim_hours()
                        if resolved is None:
                            car_drift_lines.append(
                                f'[Car Drifting] @{nick}: no all-time entry matched "{target_raw}". Try their @username.'
                            )
                        elif resolved == user_key:
                            car_drift_lines.append(
                                f"[Car Drifting] @{nick}: pick another player (not yourself)."
                            )
                        else:
                            vlab = display_name_for_key(resolved, ALLTIME_PATH)
                            outcome, new_exp = trim_shield_by_hours(resolved, trim_h, SHIELD_PATH)
                            if outcome == "no_shield":
                                car_drift_lines.append(
                                    f"[Car Drifting] @{nick}: {vlab} has no active Racing Debut shield to trim."
                                )
                            elif outcome == "removed":
                                car_drifting_pending.pop(user_key, None)
                                grace_until = start_shield_drop_grace(resolved)
                                gsec = max(0, int(grace_until - time.time()))
                                car_drift_lines.append(
                                    f"[Car Drifting] @{nick}: removed {trim_h:g}h from {vlab}'s shield — "
                                    f"protection ended. Galaxy steals from them paused {gsec // 60}:{gsec % 60:02d} "
                                    f"so they can send Racing Debut."
                                )
                                car_drift_popup_payload = {
                                    "from_name": nick,
                                    "from_user_key": user_key,
                                    "victim_name": vlab,
                                    "victim_user_key": resolved,
                                    "hours_trimmed": trim_h,
                                    "outcome": "removed",
                                    "shield_until": None,
                                    "grace_until": grace_until,
                                    "detail": (
                                        f"{vlab} — shield gone. Nobody can Galaxy-steal for "
                                        f"{gsec // 60}:{gsec % 60:02d} — send Racing Debut to get protection again."
                                    ),
                                    "duration_ms": 8500,
                                }
                                print(
                                    f"[Hangman] Car Drifting: shield removed for {resolved!r} by {user_key!r}",
                                    flush=True,
                                )
                            else:
                                car_drifting_pending.pop(user_key, None)
                                new_exp_f = float(new_exp) if new_exp is not None else 0.0
                                left = _fmt_shield_remaining(new_exp_f)
                                detail_short = f"{vlab} still has Galaxy protection — ends in {left}."
                                car_drift_lines.append(
                                    f"[Car Drifting] @{nick}: removed {trim_h:g}h from {vlab}'s shield — "
                                    f"protection now ends in {left}."
                                )
                                car_drift_popup_payload = {
                                    "from_name": nick,
                                    "from_user_key": user_key,
                                    "victim_name": vlab,
                                    "victim_user_key": resolved,
                                    "hours_trimmed": trim_h,
                                    "outcome": "shortened",
                                    "shield_until": new_exp_f,
                                    "detail": detail_short,
                                    "duration_ms": 8500,
                                }
                                print(
                                    f"[Hangman] Car Drifting: shield shortened for {resolved!r} by {user_key!r}",
                                    flush=True,
                                )

            if not consume_chat:
                scex = space_cat_pending.get(user_key)
                if scex is not None and scex > now:
                    target_raw = _parse_galaxy_target(text)
                    if target_raw:
                        consume_chat = True
                        resolved = resolve_user_key_from_handle(target_raw, ALLTIME_PATH)
                        if resolved is None:
                            space_cat_lines.append(
                                f'[Space Cat] @{nick}: no all-time entry matched "{target_raw}". Try their @username.'
                            )
                        elif resolved == user_key:
                            space_cat_lines.append(
                                f"[Space Cat] @{nick}: this gift shields someone else — type @theirname (not yourself)."
                            )
                        else:
                            space_cat_pending.pop(user_key, None)
                            exp = grant_shield(resolved, SHIELD_PATH)
                            left = _fmt_shield_remaining(exp)
                            vlab = display_name_for_key(resolved, ALLTIME_PATH)
                            hrs = shield_duration_sec() / 3600.0
                            space_cat_lines.append(
                                f"[Space Cat] @{nick} — {vlab} now has ~{hrs:g}h Galaxy protection ({left})."
                            )
                            print(
                                f"[Hangman] Space Cat: shield granted to {resolved!r} by {user_key!r}",
                                flush=True,
                            )

        if galaxy_lines:
            await push_state(galaxy_lines, galaxy_popup=galaxy_popup_payload)
            if consume_chat:
                return

        if cap_lines:
            await push_state(cap_lines, cap_popup=cap_popup_payload)
            if consume_chat:
                return

        if car_drift_lines:
            await push_state(car_drift_lines, shield_trim_popup=car_drift_popup_payload)
            if consume_chat:
                return

        if space_cat_lines:
            await push_state(space_cat_lines)
            if consume_chat:
                return

        round_popup_out: dict[str, Any] | None = None
        async with game_lock:
            rid_before = session.round_id
            (
                lines,
                _,
                round_popup,
                points_popup,
                auto_next_delay_sec,
                cmd_list_popup,
                hangman_help_popup,
                wager_intro_popup,
            ) = process_chat_message(
                session,
                text=text,
                uid=uid,
                user_key=user_key,
                nick=nick,
                host_username=host_username,
                auto_next=auto_next,
                alltime_path=ALLTIME_PATH,
            )
            rid_after = session.round_id
            snap_round = session.round_id
            if rid_after != rid_before:
                _cancel_auto_next_delay_task()
            round_popup_out = dict(round_popup) if round_popup is not None else None
            if round_popup_out and round_popup_out.get("wager_settlement"):
                ws = round_popup_out["wager_settlement"]
                ok, settle_err, transferred = try_wager_settle(
                    str(ws.get("winner_key") or ""),
                    str(ws.get("loser_key") or ""),
                    int(ws.get("amount") or 0),
                    str(ws.get("winner_name") or ""),
                    ALLTIME_PATH,
                )
                round_popup_out["wager_alltime_settled"] = ok
                ws["settled_amount"] = int(transferred)
                if not ok and settle_err:
                    ws["settlement_error"] = settle_err
            if round_popup_out and round_popup_out.get("sealed_by"):
                suk = str(round_popup_out["sealed_by"].get("user_key") or "")
                if suk:
                    wsnd = win_sound_payload_for_user(suk, ALLTIME_PATH)
                    if wsnd:
                        round_popup_out["win_sound"] = wsnd
        if (
            lines
            or round_popup
            or points_popup
            or cmd_list_popup
            or hangman_help_popup
            or wager_intro_popup
        ):
            if lines and any("Session scores reset" in ln for ln in lines):
                print("[Hangman] Session scores reset (host chat).", flush=True)
            await push_state(
                lines,
                round_popup=round_popup_out,
                points_popup=points_popup,
                command_list_popup=cmd_list_popup,
                hangman_help_popup=hangman_help_popup,
                wager_intro_popup=wager_intro_popup,
            )
        if auto_next_delay_sec is not None and auto_next_delay_sec > 0:
            _cancel_auto_next_delay_task()
            global _auto_next_delay_task
            _auto_next_delay_task = asyncio.create_task(
                _run_delayed_auto_next(snap_round, float(auto_next_delay_sec))
            )

    @client.on(GiftEvent)
    async def on_gift(event: GiftEvent) -> None:
        global _lion_nuke_task, _lion_nuke_deadline_unix, _lion_nuke_started_by_key, _lion_nuke_started_by_name
        if not _tiktok_event_is_current_session(event):
            _gift_debug("skip: outside chat time window (backlog/replay)")
            return
        try:
            gid = int(event.gift.id or 0)
        except (TypeError, ValueError):
            gid = 0
        gname = event.gift.name or ""
        uid, nick = extract_gift_sender(event)
        sender_key = _session_user_key(uid, nick)
        # Streaking gifts: TikTok sends many events with streaking=True until repeat_end. Rosa hints
        # must run on the first tick; otherwise the handler never reaches the Rosa branch.
        streak_mid = bool(event.gift.streakable and event.streaking)
        try:
            repeat_end = int(getattr(event, "repeat_end", 0) or 0)
        except (TypeError, ValueError):
            repeat_end = 0
        try:
            repeat_count = int(getattr(event, "repeat_count", 0) or 0)
        except (TypeError, ValueError):
            repeat_count = 0
        try:
            dcount = int(getattr(event.gift, "diamond_count", 0) or 0)
        except (TypeError, ValueError):
            dcount = 0
        _gift_debug(
            f"in id={gid} name={gname!r} streakable={bool(event.gift.streakable)} "
            f"streaking={bool(event.streaking)} repeat_end={repeat_end} repeat_count={repeat_count} "
            f"diamonds={dcount} nick={nick!r} key={sender_key!r}"
        )
        if streak_mid and not _rosa_gift_match(gname, gid):
            _gift_debug("skip: mid-streak tick (not Rosa — wait for streak end for other gifts)")
            return
        if fan_only_mode and not _is_stream_host(uid, sender_key):
            if not gift_user_is_fan_club_member(event):
                if _fan_gate_should_emit(sender_key):
                    await push_state(
                        [],
                        fan_gate_popup={
                            "name": nick,
                            "user_key": sender_key,
                            "duration_ms": 7000,
                        },
                    )
                _gift_debug("skip: fans-only mode (not Heart Me / fan team on this payload)")
                return

        if _galaxy_gift_match(gname, gid):
            _gift_debug("branch: Galaxy — pending username target")
            ttl = float(os.environ.get("HANGMAN_GALAXY_PENDING_SEC", "1800"))
            async with game_lock:
                galaxy_pending[sender_key] = time.monotonic() + ttl
            await push_state(
                [
                    f"[Galaxy] @{nick} — type a player's @username (one word) to take their all-time points "
                    f"and add them to your total. Expires in {int(ttl // 60)} min."
                ]
            )
            return

        if _car_drifting_gift_match(gname, gid):
            _gift_debug("branch: Car Drifting — pending trim target")
            ttl = float(os.environ.get("HANGMAN_CAR_DRIFTING_PENDING_SEC", "1800"))
            trim_h = _car_drifting_trim_hours()
            async with game_lock:
                car_drifting_pending[sender_key] = time.monotonic() + ttl
            await push_state(
                [
                    f"[Car Drifting] @{nick} — type a player's @username (one word) to remove {trim_h:g} hours "
                    f"from their Racing Debut shield (Galaxy protection). Expires in {int(ttl // 60)} min."
                ]
            )
            return

        if _space_cat_gift_match(gname, gid):
            _gift_debug("branch: Space Cat — pending shield grant target")
            ttl = float(os.environ.get("HANGMAN_SPACE_CAT_PENDING_SEC", "1800"))
            hrs = shield_duration_sec() / 3600.0
            async with game_lock:
                space_cat_pending[sender_key] = time.monotonic() + ttl
            await push_state(
                [
                    f"[Space Cat] @{nick} — type a player's @username (one word) to give them ~{hrs:g}h "
                    f"Racing Debut shield (Galaxy protection), not yourself. Expires in {int(ttl // 60)} min."
                ]
            )
            return

        if _lion_gift_match(gname, gid):
            _gift_debug("branch: Lion — nuke start or counter-Lion")
            log_lines: list[str] = []
            async with _lion_nuke_lock:
                now_unix = time.time()
                if _lion_nuke_deadline_unix is not None and _lion_nuke_deadline_unix > now_unix:
                    left = _lion_nuke_deadline_unix - now_unix
                    started_by = _lion_nuke_started_by_name or _lion_nuke_started_by_key or "unknown"
                    t = _lion_nuke_task
                    if t is not None and not t.done():
                        t.cancel()
                    _lion_nuke_task = None
                    _lion_nuke_deadline_unix = None
                    _lion_nuke_started_by_key = ""
                    _lion_nuke_started_by_name = ""
                    log_lines.append(
                        f"[Lion Nuke] Counter-Lion from @{nick} stopped the reset with {_fmt_mmss(left)} left."
                    )
                    log_lines.append(f"[Lion Nuke] Safe — @{started_by}'s nuke was canceled.")
                else:
                    window_sec = _lion_nuke_window_sec()
                    deadline = now_unix + window_sec
                    _lion_nuke_deadline_unix = deadline
                    _lion_nuke_started_by_key = sender_key
                    _lion_nuke_started_by_name = nick
                    _lion_nuke_task = asyncio.create_task(_run_lion_nuke_timer(deadline))
                    log_lines.append(
                        f"[Lion Nuke] @{nick} triggered a full all-time reset in {_fmt_mmss(window_sec)}."
                    )
                    log_lines.append(
                        "[Lion Nuke] To avoid reset, someone must send another Lion before the timer hits 0."
                    )
            for line in log_lines:
                print(line, flush=True)
            await push_state(log_lines)
            return

        if _lion_nuke_active_now():
            _gift_debug("skip: Lion lockdown — gifts paused (non-Lion)")
            if _lion_lock_notice_allowed(_lion_lock_gift_notice_last, sender_key):
                left = max(0, int((_lion_nuke_deadline_unix or 0) - time.time()))
                await push_state(
                    [
                        f"[Lion Nuke] Gift effects paused ({left // 60}:{left % 60:02d} left). "
                        "Only another Lion can cancel the reset."
                    ]
                )
            return

        if _racing_debut_gift_match(gname, gid):
            _gift_debug("branch: Racing Debut — shield granted")
            hrs = shield_duration_sec() / 3600.0
            exp = grant_shield(sender_key, SHIELD_PATH)
            left = _fmt_shield_remaining(exp)
            await push_state(
                [
                    f"[Racing Debut] @{nick} — your all-time points are safe from Galaxy steals for "
                    f"{hrs:g}h ({left}). Send again later to extend."
                ]
            )
            return

        if _cap_gift_match(gname, gid):
            _gift_debug("branch: Cap — pending sideline target")
            ttl = float(os.environ.get("HANGMAN_CAP_PENDING_SEC", "1800"))
            async with game_lock:
                cap_ignore_pending[sender_key] = time.monotonic() + ttl
            await push_state(
                [
                    f"[Cap] @{nick} — type a player's @username (one word) to sideline them for the next word "
                    f"(they can still play this word). Expires in {int(ttl // 60)} min."
                ]
            )
            return

        if _money_gun_gift_match(gname, gid):
            _gift_debug("branch: Money Gun — wrong-guess shield rounds")
            async with game_lock:
                assert session is not None
                rounds = session.grant_money_gun_shield(sender_key, nick, rounds=5)
            await push_state(
                [
                    f"[Money Gun] @{nick} — no wrong-guess point loss for {rounds} rounds "
                    "(letters and full-word misses).",
                ]
            )
            return

        diamond_pts = _gift_diamond_alltime_points(event)
        gift_log: list[str] = []
        hint_popup_payload: dict[str, Any] | None = None

        if _rosa_gift_match(gname, gid):
            _gift_debug("branch: Rosa — hint attempt (one per word)")
            async with game_lock:
                assert session is not None
                hint_popup_payload = session.try_rosa_hint_popup()
            if hint_popup_payload:
                hint_popup_payload["from_name"] = nick
                hint_popup_payload["from_user_key"] = sender_key
                gift_log.append(f"[Rosa] @{nick} — hint unlocked for this round.")
            elif not streak_mid:
                gift_log.append(
                    f"[Rosa] @{nick} — no hint (already used this round, or the word is fully revealed)."
                )

        if diamond_pts > 0 and sender_key and sender_key != "anon" and not streak_mid:
            _gift_debug(f"branch: generic diamond → +{diamond_pts} all-time (ratio/cap applied)")
            add_points(sender_key, nick, diamond_pts, ALLTIME_PATH)
            gdisp = (gname or "gift").strip() or "gift"
            gift_log.append(
                f'[Gift] @{nick} +{diamond_pts} all-time from "{gdisp}" (TikTok diamond value).'
            )
            if diamond_pts >= 500:
                print(
                    f"[Hangman] Gift → all-time +{diamond_pts} for {sender_key!r} ({gdisp!r}).",
                    flush=True,
                )

        if gift_log or hint_popup_payload:
            await push_state(gift_log, hint_popup=hint_popup_payload)
        elif _gift_debug_enabled():
            if diamond_pts <= 0:
                _gift_debug(
                    f"tail: no push (diamond_pts=0 rosa={_rosa_gift_match(gname, gid)} "
                    f"streak_mid={streak_mid})"
                )
            else:
                _gift_debug(
                    f"tail: diamond_pts={diamond_pts} skipped add_points "
                    f"(streak_mid={streak_mid} — applied on streak end)"
                )

    return client


async def tiktok_runner() -> None:
    global tt_client, tiktok_status
    try:
        tiktok_status = "connecting"
        await push_state([])
        tt_client = setup_tiktok_client()
        await tt_client.connect()
    except asyncio.CancelledError:
        raise
    except Exception as e:
        tiktok_status = f"error: {e!s}"
        _append_logs([f"[System] TikTok: {e!s}"])
        await push_state([])
    finally:
        if tiktok_status == "connecting" or tiktok_status == "connected":
            tiktok_status = "stopped"
        c = tt_client
        if c is not None:
            try:
                await c.disconnect()
            except Exception:
                pass
            tt_client = None


async def _reconnect_tiktok_live(new_username: str) -> None:
    """Stop the current TikTok client task, switch usernames, and start a new connection."""
    global tiktok_task, tiktok_username, host_username
    async with _tiktok_reconnect_lock:
        t = tiktok_task
        if t is not None and not t.done():
            t.cancel()
            try:
                await t
            except asyncio.CancelledError:
                pass
        tiktok_username = new_username
        host_username = new_username
        print(f"[Hangman] Reconnecting TikTok LIVE: @{new_username} (from web).", flush=True)
        await push_state([f"[Host] Reconnecting TikTok LIVE: @{new_username}…"])
        tiktok_task = asyncio.create_task(tiktok_runner())


@asynccontextmanager
async def lifespan(app: FastAPI):
    global session, tiktok_task, tiktok_username, host_username, auto_next
    global _wall_session_started, _wall_tiktok_connected, _like_mvp_loop_task
    global _lion_nuke_task, _lion_nuke_deadline_unix, _lion_nuke_started_by_key, _lion_nuke_started_by_name
    global _spotify_queue_allowlist
    _wall_session_started = time.time()
    _wall_tiktok_connected = None
    session = HangmanSession(
        secret="A",
        max_wrong_per_player=int(os.environ.get("MAX_WRONG", "6")),
        on_score_delta=_record_alltime_delta,
        on_answer_changed=print_round_answer_to_console,
        alltime_path=ALLTIME_PATH,
    )
    session.random_new_word()
    event_log.clear()
    _lion_nuke_deadline_unix = None
    _lion_nuke_started_by_key = ""
    _lion_nuke_started_by_name = ""
    _lion_nuke_task = None
    tiktok_username = os.environ.get("TIKTOK_LIVE_USERNAME", DEFAULT_LIVE_USERNAME).strip().lstrip("@")
    host_username = os.environ.get("TIKTOK_HOST_USERNAME", tiktok_username).strip().lstrip("@")
    auto_next = os.environ.get("AUTO_NEXT", "1") not in ("0", "false", "False")
    _spotify_queue_allowlist = load_allowed_keys(SPOTIFY_QUEUE_ALLOWLIST_PATH)
    tiktok_task = asyncio.create_task(tiktok_runner())
    _like_mvp_loop_task = asyncio.create_task(_like_mvp_loop())
    yield
    _cancel_auto_next_delay_task()
    if _like_mvp_loop_task:
        _like_mvp_loop_task.cancel()
        try:
            await _like_mvp_loop_task
        except asyncio.CancelledError:
            pass
        _like_mvp_loop_task = None
    if _lion_nuke_task:
        _lion_nuke_task.cancel()
        try:
            await _lion_nuke_task
        except asyncio.CancelledError:
            pass
        _lion_nuke_task = None
    if tiktok_task:
        tiktok_task.cancel()
        try:
            await tiktok_task
        except asyncio.CancelledError:
            pass
    if tt_client:
        try:
            await tt_client.disconnect()
        except Exception:
            pass


app = FastAPI(lifespan=lifespan)


@app.middleware("http")
async def _no_cache_overlay_assets(request: Request, call_next):
    """
    Avoid stale index.html / JS/CSS in the browser after git pull (local overlay).
    Set HANGMAN_ALLOW_BROWSER_CACHE=1 to allow normal caching again.
    """
    response = await call_next(request)
    if os.environ.get("HANGMAN_ALLOW_BROWSER_CACHE", "").strip() == "1":
        return response
    path = request.url.path
    if path == "/" or path.startswith("/static/") or path == "/api/build-info":
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


@app.get("/api/hangman/now-playing")
async def api_hangman_now_playing() -> dict[str, Any]:
    """Spotify track from Windows media session (Spotify desktop on this PC)."""
    return await spotify_now_playing_async()


@app.get("/api/hangman/spotify-queue-list")
async def api_hangman_spotify_queue_list() -> dict[str, Any]:
    return await asyncio.to_thread(spotify_queue_list_snapshot)


@app.get("/api/hangman/spotify-auth-status")
async def api_hangman_spotify_auth_status() -> dict[str, Any]:
    return await asyncio.to_thread(spotify_auth_probe)


@app.post("/api/hangman/spotify-queue")
async def api_hangman_spotify_queue(body: dict[str, Any]) -> dict[str, Any]:
    q = str(body.get("q") or body.get("query") or "").strip()
    dn = str(body.get("display_name") or body.get("requested_by") or "api").strip() or "api"
    if not q:
        return {"ok": False, "error": "missing_q"}
    return await asyncio.to_thread(queue_track_by_search, q, dn)


@app.get("/api/build-info")
async def build_info(request: Request) -> dict[str, Any]:
    """Debug: proves which folder the running server loads and whether index.html matches current UI."""
    root = Path(__file__).resolve().parent
    idx = STATIC_DIR / "index.html"
    mt = idx.stat().st_mtime if idx.exists() else 0.0
    txt = idx.read_text(encoding="utf-8") if idx.exists() else ""
    low = txt.lower()
    return {
        "request_host": request.headers.get("host", ""),
        "project_dir": str(root),
        "static_dir": str(STATIC_DIR.resolve()),
        "index_html_mtime_unix": int(mt),
        "ui_build_token": int(mt),
        "index_contains_dobby": "dobby" in low,
        "index_contains_wrong_letters_live": "wrong letters" in low and "live" in low,
    }


@app.get("/")
async def root() -> Response:
    body = _index_html_for_response()
    ui_build = str(int((STATIC_DIR / "index.html").stat().st_mtime))
    return Response(
        content=body.encode("utf-8"),
        media_type="text/html; charset=utf-8",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
            "X-Hangman-UI-Build": ui_build,
        },
    )


@app.get("/api/streamer-avatar")
async def streamer_avatar() -> Response:
    uid = (tiktok_username or DEFAULT_LIVE_USERNAME).strip().lstrip("@")
    if uid not in _streamer_avatar_cache:
        _streamer_avatar_cache[uid] = await fetch_profile_avatar_bytes(uid)
    raw = _streamer_avatar_cache.get(uid)
    if raw:
        return Response(
            content=raw,
            media_type=_image_mime(raw),
            headers={"Cache-Control": "public, max-age=3600"},
        )
    return Response(
        content=fallback_avatar_svg(),
        media_type="image/svg+xml",
        headers={"Cache-Control": "public, max-age=300"},
    )


@app.get("/api/player-avatar")
async def player_avatar(key: str = Query(..., min_length=1, max_length=256)) -> Response:
    k = key.strip()
    if k not in _player_avatar_cache:
        _player_avatar_cache[k] = await fetch_profile_avatar_bytes(k)
    raw = _player_avatar_cache.get(k)
    if raw:
        return Response(
            content=raw,
            media_type=_image_mime(raw),
            headers={"Cache-Control": "public, max-age=1800"},
        )
    return Response(
        content=fallback_avatar_svg(),
        media_type="image/svg+xml",
        headers={"Cache-Control": "public, max-age=300"},
    )


@app.post("/api/host/reset-session")
async def host_reset_session(
    request: Request,
    x_host_key: str | None = Header(None, alias="X-Host-Key"),
) -> dict[str, bool]:
    """
    Zero session scores (not all-time). If HANGMAN_HOST_KEY is set, require matching X-Host-Key header.
    If unset, only requests from loopback (127.0.0.1 / ::1) are allowed.
    """
    expected = os.environ.get("HANGMAN_HOST_KEY", "").strip()
    if expected:
        if (x_host_key or "").strip() != expected:
            raise HTTPException(
                status_code=403,
                detail="Invalid or missing X-Host-Key (must match HANGMAN_HOST_KEY).",
            )
    else:
        host = request.client.host if request.client else ""
        if host not in ("127.0.0.1", "::1", "localhost"):
            raise HTTPException(
                status_code=403,
                detail="Use http://127.0.0.1:... from this PC, or set HANGMAN_HOST_KEY and pass X-Host-Key.",
            )
    assert session is not None
    async with game_lock:
        session.reset_session_scores()
    await push_state(["[Host] Session leaderboard reset from the web page."])
    print("[Hangman] Session scores reset (web).", flush=True)
    return {"ok": True}


@app.post("/api/host/tiktok-connect")
async def host_tiktok_connect(
    request: Request,
    x_host_key: str | None = Header(None, alias="X-Host-Key"),
) -> dict[str, str | bool]:
    """
    Reconnect the TikTok LIVE client to a different @username. Host commands (!word, !skip, etc.)
    use the same name as the room being watched. Same auth as /api/host/reset-session.
    """
    expected = os.environ.get("HANGMAN_HOST_KEY", "").strip()
    if expected:
        if (x_host_key or "").strip() != expected:
            raise HTTPException(
                status_code=403,
                detail="Invalid or missing X-Host-Key (must match HANGMAN_HOST_KEY).",
            )
    else:
        host = request.client.host if request.client else ""
        if host not in ("127.0.0.1", "::1", "localhost"):
            raise HTTPException(
                status_code=403,
                detail="Use http://127.0.0.1:... from this PC, or set HANGMAN_HOST_KEY and pass X-Host-Key.",
            )
    try:
        body = await request.json()
    except Exception:
        body = {}
    u = str(body.get("username") or "").strip().lstrip("@")
    if not u:
        raise HTTPException(status_code=400, detail="Enter a TikTok @username to connect to.")
    if len(u) > 200:
        raise HTTPException(status_code=400, detail="Username is too long.")
    await _reconnect_tiktok_live(u)
    return {"ok": True, "tiktok": tiktok_username, "tiktok_status": tiktok_status}


def _nfg_internal_ok(request: Request) -> bool:
    expected = (os.environ.get("NFG_INTERNAL_SECRET") or "nfg-dev-internal").strip()
    got = (request.headers.get("x-nfg-internal") or "").strip()
    return bool(expected) and got == expected


@app.get("/api/hangman/leaderboard")
async def hangman_public_leaderboard(limit: int = Query(12, ge=1, le=50)) -> dict[str, Any]:
    rows = _alltime_payload()
    return {"ok": True, "top": rows[: int(limit)]}


@app.get("/api/hangman/status")
async def hangman_public_status() -> dict[str, Any]:
    live = tiktok_status in ("connected", "connecting")
    return {
        "ok": True,
        "service": "nfg-hangman",
        "tiktok": tiktok_username,
        "tiktok_status": tiktok_status,
        "isLive": live,
        "has_session": session is not None,
    }


@app.get("/api/hangman/app/state")
async def hangman_app_state() -> dict[str, Any]:
    """Public snapshot for mobile companion (REST poll + platform proxy)."""
    try:
        if session is None:
            return {"ok": False, "error": "game_not_ready", "message": "Hangman session not started"}
        snap = _snapshot_with_cosmetics()
        return {
            "ok": True,
            "maskedWord": snap["mask"],
            "masked": snap["mask"],
            "slots": snap["slots"],
            "keyboard": snap["keyboard"],
            "length": snap["length"],
            "guessed_letters": snap.get("guessed_letters") or [],
            "word_theme": snap.get("word_theme") or "",
            "tiktok": tiktok_username,
            "tiktok_status": tiktok_status,
            "state": snap,
        }
    except Exception as exc:
        print(f"[hangman app state] error: {exc!r}")
        return {"ok": False, "error": "state_failed", "message": str(exc)[:240]}


@app.post("/api/hangman/app/guess")
async def hangman_app_guess(request: Request) -> dict[str, Any]:
    """Trusted guess from NFG platform (mobile app keyboard). Same rules as TikTok chat."""
    try:
        if not _nfg_internal_ok(request):
            raise HTTPException(status_code=403, detail="Forbidden")
        if session is None:
            raise HTTPException(status_code=503, detail="Game not ready")

        uid = (request.headers.get("x-nfg-user-id") or "").strip()
        nick = (request.headers.get("x-nfg-display-name") or uid).strip() or "App player"
        if not uid:
            raise HTTPException(status_code=400, detail="Missing X-NFG-User-Id")

        try:
            body = await request.json()
        except Exception:
            body = {}

        word = str(body.get("word") or "").strip()
        letter = str(body.get("letter") or "").strip().upper()

        if word and len(word) >= 2:
            guess_text = f"!{word}"
        elif letter and len(letter) == 1 and letter.isalpha():
            guess_text = letter
        else:
            raise HTTPException(status_code=400, detail="Send letter (A-Z) or word (2+ chars)")

        user_key = _session_user_key(uid, nick)
        snap_round = session.round_id
        lines: list[str] = []
        round_popup = None
        points_popup = None
        cmd_pop = None
        help_pop = None
        wager_pop = None
        auto_next_delay_sec = None
        async with game_lock:
            (
                lines,
                _completed,
                round_popup,
                points_popup,
                auto_next_delay_sec,
                cmd_pop,
                help_pop,
                wager_pop,
            ) = process_chat_message(
                session,
                text=guess_text,
                uid=uid,
                user_key=user_key,
                nick=nick,
                host_username=host_username,
                auto_next=auto_next,
                alltime_path=ALLTIME_PATH,
            )
            snap_round = session.round_id

        if lines or round_popup or points_popup or cmd_pop or help_pop or wager_pop:
            await push_state(
                lines,
                round_popup=round_popup,
                points_popup=points_popup,
                command_list_popup=cmd_pop,
                hangman_help_popup=help_pop,
                wager_intro_popup=wager_pop,
            )
        if auto_next_delay_sec is not None and auto_next_delay_sec > 0:
            global _auto_next_delay_task
            _cancel_auto_next_delay_task()
            _auto_next_delay_task = asyncio.create_task(
                _run_delayed_auto_next(snap_round, float(auto_next_delay_sec))
            )

        pl = session.players.get(user_key)
        eliminated = bool(pl and pl.eliminated_this_word)
        wrong = int(pl.incorrect_this_word) if pl else 0
        guessed = sorted(c.lower() for c in session.guessed_letters if c.isalpha())
        won = bool(session.is_solved())
        correct: bool | None = None
        if letter and len(letter) == 1 and letter.isalpha():
            joined = "\n".join(lines).lower()
            if "is correct" in joined:
                correct = True
            elif "is not in the word" in joined or "you are out" in joined:
                correct = False
            elif "already guessed" in joined:
                correct = None
        snap = session.snapshot()
        return {
            "ok": True,
            "lines": lines,
            "eliminated": eliminated,
            "wrongGuesses": wrong,
            "wrong": wrong,
            "maxWrong": session.max_wrong_per_player,
            "maskedWord": snap["mask"],
            "masked": snap["mask"],
            "slots": snap["slots"],
            "keyboard": snap["keyboard"],
            "length": snap["length"],
            "guessed": guessed,
            "won": won,
            "correct": correct,
        }
    except HTTPException:
        raise
    except Exception as exc:
        print(f"[hangman app guess] error: {exc!r}")
        return {"ok": False, "error": "guess_failed", "message": str(exc)[:240]}


@app.websocket("/ws")
async def ws_endpoint(websocket: WebSocket) -> None:
    global fan_only_mode
    await websocket.accept()
    clients.add(websocket)
    assert session is not None
    try:
        await websocket.send_json(
            {
                "type": "update",
                "logs": list(event_log),
                "state": _snapshot_with_cosmetics(),
                "alltime": _alltime_payload(),
                "shield_grace_windows": _shield_grace_windows_payload(),
                "tiktok": tiktok_username,
                "tiktok_status": tiktok_status,
                "fan_only_mode": fan_only_mode,
                "lion_nuke": _lion_nuke_payload(),
            }
        )
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if data.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
                continue
            if data.get("type") == "set_fan_only":
                if not _ws_host_authorized(websocket, data.get("host_key")):
                    await websocket.send_json({"type": "error", "detail": "Host authorization failed."})
                    continue
                fan_only_mode = bool(data.get("value"))
                await push_state(
                    [f"[Host] Fans-only (Heart Me) mode: {'ON' if fan_only_mode else 'OFF'}"]
                )
                continue
    except WebSocketDisconnect:
        pass
    finally:
        clients.discard(websocket)


app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="assets")
