"""Shared TikTok chat → hangman logic for CLI and web server."""
from __future__ import annotations

import math
import os
import time
from pathlib import Path
from typing import Any, Optional

from text_normalize import normalize_chat_for_letter_parse, normalize_lookup_token
from hangman_game import (
    WHOLE_WORD_POINTS_MAX,
    WHOLE_WORD_POINTS_MIN,
    HangmanSession,
    parse_host_command,
    parse_letter_from_message,
)
from alltime_leaderboard import NAME_BADGE_COST, WIN_BANNER_COST
from heart_icons import HEART_COLOR_COST, hearts_list_popup_payload
from name_colors import NAME_COLOR_COMMANDS, NAME_COLOR_COST, command_list_popup_payload
from racing_debut_shield import is_shield_drop_grace_active, shield_drop_grace_until

from hangman_spotify_playback import queue_track_by_search
from nfg_platform import is_nfg_crash_chat_noise, is_nfg_crash_spotify_noise
from spotify_queue_allowlist_store import load_allowed_keys

_SPOTIFY_QUEUE_ALLOWLIST_PATH = Path(__file__).resolve().parent / "data" / "spotify_queue_allowlist.json"


def spotify_queue_chat_lines(
    *,
    arg: str,
    uid: str,
    user_key: str,
    nick: str,
    host_username: str,
    allowlist: set[str] | None = None,
) -> list[str]:
    """
    Shared Spotify queue-from-chat (same rules as server.py). ``allowlist`` is the
    in-memory set from the web server when given; otherwise the JSON file is read.
    """
    h = normalize_lookup_token(host_username or "")
    host_ok = False
    if h:
        host_ok = normalize_lookup_token(uid) == h or normalize_lookup_token(user_key) == h
    if not host_ok:
        keys = allowlist if allowlist is not None else load_allowed_keys(_SPOTIFY_QUEUE_ALLOWLIST_PATH)
        if user_key not in keys:
            return ["[Spotify] Only the broadcaster (or allowlisted viewers) can queue songs from chat."]
    dn = (nick or "").strip() or "Anonymous"
    if not (arg or "").strip():
        return [
            f"[Spotify] @{dn}: use !queue search text or paste an open.spotify.com/track/… or spotify:track:… link"
        ]
    sq = queue_track_by_search((arg or "").strip(), dn)
    if sq.get("ok"):
        tr = sq.get("track") or "?"
        return [f"[Spotify] Queued: {tr} (by {dn})"]
    err = str(sq.get("error") or "unknown")
    hint = str(sq.get("hint") or "").strip()
    msg = f"[Spotify] @{dn}: {err}"
    if hint:
        msg += f" — {hint}"
    return [msg]


# First token after ! must be one of these to be a command — otherwise !foo means full-phrase guess "foo".
BANG_RESERVED_COMMANDS: frozenset[str] = frozenset(
    {
        "board",
        "leaderboard",
        "help",
        "points",
        "guess",
        "word",
        "buy",
        "command",
        "hearts",
        "how",
        "play",
        "rules",
        "howtoplay",
        "end",
        "p1",
        "p2",
        "setword",
        "set",
        "random",
        "skip",
        "resetsession",
        "resetscores",
        "hangman",
        "mascot",
        "wager",
        "wageraccept",
        "winsounds",
        "setwinsound",
        "addpoints",
        "addpts",
        "shop",
        "prices",
        "queue",
        "song",
        "addsong",
        "queueallow",
        "queuedeny",
        "queueremove",
        "queuelist",
    }
) | NAME_COLOR_COMMANDS

# Commands used by parallel chat games; Hangman should fully ignore these.
BANG_INTEROP_IGNORED_COMMANDS: frozenset[str] = frozenset({"play", "end", "p1", "p2"})

# target_user_key -> (challenger_key, challenger_name, amount, expiry_monotonic)
_pending_wager_by_target: dict[str, tuple[str, str, int, float]] = {}


def _wager_pending_ttl_sec() -> float:
    try:
        return max(30.0, float(os.environ.get("HANGMAN_WAGER_PENDING_SEC", "120").strip()))
    except ValueError:
        return 120.0


def _prune_expired_wager_challenges() -> None:
    now = time.monotonic()
    dead = [k for k, t in _pending_wager_by_target.items() if t[3] <= now]
    for k in dead:
        del _pending_wager_by_target[k]


def _shield_grace_rebuy_window_block_msg(user_key: str, nick: str) -> Optional[str]:
    """
    After Car Drifting fully removes someone's Racing Debut shield, they enter a short re-buy window
    (HANGMAN_SHIELD_DROP_GRACE_SEC, default 5 min): Galaxy steals are paused; chat shop spends and wagers are too.
    They restore protection by sending the Racing Debut gift (handled in server.py), not via !buy.
    """
    if not user_key or not is_shield_drop_grace_active(user_key):
        return None
    exp = shield_drop_grace_until(user_key)
    left = max(0, int((exp or 0) - time.time()))
    m, s = left // 60, left % 60
    return (
        f"@{nick}: Shield re-buy window ({m}:{s:02d} left) — send the Racing Debut gift to restore protection. "
        f"!buy and !wager are paused until then."
    )

# !command overlay list: per user_key, wall-clock throttle (process-local).
_command_list_last: dict[str, float] = {}
COMMAND_LIST_COOLDOWN_SEC = 60.0

_hearts_list_last: dict[str, float] = {}
HEARTS_LIST_COOLDOWN_SEC = 45.0

_hangman_help_last: dict[str, float] = {}

_points_last: dict[str, float] = {}


def _points_cooldown_sec() -> float:
    try:
        return max(5.0, float(os.environ.get("HANGMAN_POINTS_COOLDOWN_SEC", "60").strip()))
    except ValueError:
        return 60.0


def _points_cooldown_left(user_key: str) -> float:
    if not user_key:
        return 0.0
    now = time.monotonic()
    last = _points_last.get(user_key, 0.0)
    return max(0.0, _points_cooldown_sec() - (now - last))


def _register_points_use(user_key: str) -> None:
    if user_key:
        _points_last[user_key] = time.monotonic()


def _hangman_help_cooldown_sec() -> float:
    try:
        return max(30.0, float(os.environ.get("HANGMAN_HELP_COOLDOWN_SEC", "120").strip()))
    except ValueError:
        return 120.0


def _hangman_help_popup_duration_ms() -> int:
    try:
        return max(15_000, int(float(os.environ.get("HANGMAN_HELP_POPUP_MS", "90000").strip())))
    except ValueError:
        return 90_000


def _hangman_help_cooldown_left(user_key: str) -> float:
    if not user_key:
        return 0.0
    now = time.monotonic()
    last = _hangman_help_last.get(user_key, 0.0)
    return max(0.0, _hangman_help_cooldown_sec() - (now - last))


def _register_hangman_help_use(user_key: str) -> None:
    if user_key:
        _hangman_help_last[user_key] = time.monotonic()


def hangman_help_payload_text() -> str:
    """Short rules blurb for the !hangman overlay (one block)."""
    return (
        f"UK words & phrases — type a letter, or !guess L, or the whole answer as !YOUR PHRASE / !word PHRASE. "
        f"Full-phrase win: {WHOLE_WORD_POINTS_MIN}–{WHOLE_WORD_POINTS_MAX} pts (more hidden letters = more pts). "
        f"+10 per correct letter, +50 if you seal the word; wrong letter −10; wrong phrase −10 × letters in your guess. "
        f"Too many wrongs = out for this round only. Session scores vs all-time (!points). "
        f"Shop: !buy glow, !buy prefix …, !hearts, !winsounds, name colours (!command). "
        f"With glow: !mascot crown | !mascot heart (free — crown vs purchased heart icon). "
        f"Liking the LIVE: +1 all-time pt per 10 likes from you this stream (max +500 from likes per UTC day; not session score). "
        f"Lifetime likes on stream unlock stronger name glow each 50k. "
        f"Host: !setword · !random · !skip · !resetsession · !addpoints @user POINTS (all-time). Type !shop for buy prices."
    )


def hangman_help_popup_payload(nick: str, user_key: str) -> dict[str, Any]:
    """Full-screen overlay copy (stream-safe; no secrets)."""
    return {
        "duration_ms": _hangman_help_popup_duration_ms(),
        "from_name": nick,
        "from_user_key": user_key,
        "paragraphs": [hangman_help_payload_text()],
    }


def _command_list_cooldown_left(user_key: str) -> float:
    if not user_key:
        return 0.0
    now = time.monotonic()
    last = _command_list_last.get(user_key, 0.0)
    return max(0.0, COMMAND_LIST_COOLDOWN_SEC - (now - last))


def _register_command_list_use(user_key: str) -> None:
    if user_key:
        _command_list_last[user_key] = time.monotonic()


def _hearts_list_cooldown_left(user_key: str) -> float:
    if not user_key:
        return 0.0
    now = time.monotonic()
    last = _hearts_list_last.get(user_key, 0.0)
    return max(0.0, HEARTS_LIST_COOLDOWN_SEC - (now - last))


def _register_hearts_list_use(user_key: str) -> None:
    if user_key:
        _hearts_list_last[user_key] = time.monotonic()


_winsounds_list_last: dict[str, float] = {}
WINSOUNDS_LIST_COOLDOWN_SEC = 55.0


def _winsounds_list_cooldown_left(user_key: str) -> float:
    if not user_key:
        return 0.0
    now = time.monotonic()
    last = _winsounds_list_last.get(user_key, 0.0)
    return max(0.0, WINSOUNDS_LIST_COOLDOWN_SEC - (now - last))


def _register_winsounds_list_use(user_key: str) -> None:
    if user_key:
        _winsounds_list_last[user_key] = time.monotonic()


def _auto_next_delay_sec() -> float:
    """Seconds to wait after a solve before auto-advancing (0 = immediate)."""
    try:
        return max(0.0, float(os.environ.get("HANGMAN_AUTO_NEXT_DELAY_SEC", "2.5").strip()))
    except ValueError:
        return 2.5


def _maybe_autonext_after_solve(
    session: HangmanSession,
    auto_next: bool,
    completed: bool,
    lines: list[str],
    round_popup: Optional[dict[str, Any]],
    points_popup: Optional[dict[str, Any]],
    wager_intro_popup: Optional[dict[str, Any]] = None,
) -> tuple[
    list[str],
    bool,
    Optional[dict[str, Any]],
    Optional[dict[str, Any]],
    Optional[float],
    Optional[dict[str, Any]],
    Optional[dict[str, Any]],
    Optional[dict[str, Any]],
]:
    advance = completed or bool(round_popup and round_popup.get("wager_draw"))
    if not (advance and auto_next):
        return lines, False, round_popup, points_popup, None, None, None, wager_intro_popup
    delay = _auto_next_delay_sec()
    if delay > 0:
        return lines, False, round_popup, points_popup, delay, None, None, wager_intro_popup
    session.random_new_word()
    lines.append(f"Next word ({len(session.secret)} letters): {session.mask()}")
    return lines, True, round_popup, points_popup, None, None, None, wager_intro_popup


def broadcaster_check(unique_id: str, broadcaster: str) -> bool:
    return unique_id.strip().lower() == broadcaster.strip().lower()


def process_chat_message(
    session: HangmanSession,
    *,
    text: str,
    uid: str,
    user_key: str,
    nick: str,
    host_username: str,
    auto_next: bool,
    alltime_path: Optional[Path] = None,
) -> tuple[
    list[str],
    bool,
    Optional[dict[str, Any]],
    Optional[dict[str, Any]],
    Optional[float],
    Optional[dict[str, Any]],
    Optional[dict[str, Any]],
    Optional[dict[str, Any]],
]:
    """
    Returns (log_lines, started_new_word_after_solve, round_popup, points_popup,
    auto_next_delay_sec_or_none, command_list_popup_or_none, hangman_help_popup_or_none,
    wager_intro_popup_or_none).
    """
    lines: list[str] = []
    _prune_expired_wager_challenges()

    text = normalize_chat_for_letter_parse(text or "")

    if is_nfg_crash_chat_noise(text) or is_nfg_crash_spotify_noise(text):
        return [], False, None, None, None, None, None, None

    parsed = parse_host_command(text)
    if parsed:
        cmd, arg = parsed
        arg = (arg or "").strip()

        if cmd in BANG_INTEROP_IGNORED_COMMANDS:
            return [], False, None, None, None, None, None, None

        if cmd in ("board", "leaderboard", "help"):
            if cmd in ("board", "leaderboard"):
                lines.append(session.leaderboard_line())
            else:
                lines.append(
                    "UK words & phrases — one letter (e.g. A) or !guess T, "
                    f"or full answer: !YOUR PHRASE (e.g. !football or !word FISH AND CHIPS; "
                    f"{WHOLE_WORD_POINTS_MIN}–{WHOLE_WORD_POINTS_MAX} pts when more letters hidden). "
                    "!hangman = full-screen how to play on the stream overlay (no points cost; cooldown). "
                    "Wrong letter: -10; wrong full phrase: -10 × letters in your guess; letter correct: +10; "
                    "round MVP: +50. Shop prices: !shop. Host: !setword PHRASE | !random | !skip | !resetsession | "
                    "!addpoints @handle POINTS (all-time). "
                    f"!points = all-time total ({int(_points_cooldown_sec())}s cooldown per user; paused during !wager rounds); !buy glow = 5000 all-time pts; "
                    f"!buy prefix star|heart|crown = {NAME_BADGE_COST} pts each new badge, switch owned free; "
                    f"!buy pink heart = {HEART_COLOR_COST} pts each new heart colour, switch owned free; "
                    f"with glow: !mascot crown | !mascot heart (free, crown vs heart icon); "
                    f"!winsounds = win jingle shop (!buy winsound <id>, !setwinsound <id>); "
                    f"name colours ({NAME_COLOR_COST} pts each new, switch owned free): !blue !green …; "
                    f"!command = colour list on stream ("
                    f"{int(COMMAND_LIST_COOLDOWN_SEC)}s cooldown). "
                    "All-time wager: !wager USERNAME POINTS (both need balance), they reply !wageraccept; "
                    "wrong guesses don't change all-time for the two duelists (session score still does). "
                    "Liking this LIVE: +1 all-time pt (not session) per 10 likes from you this stream, max +500 from likes per UTC day; "
                    "lifetime LIVE likes unlock name cosmetics every 50k."
                )
            return lines, False, None, None, None, None, None, None

        if cmd == "buy":
            gmsg = _shield_grace_rebuy_window_block_msg(user_key, nick)
            if gmsg:
                lines.append(gmsg)
                return lines, False, None, None, None, None, None, None
            sub = (arg or "").strip().lower()
            if not alltime_path:
                lines.append("[Shop] Shop not available here.")
                return lines, False, None, None, None, None, None, None
            parts = sub.split()
            if len(parts) >= 2 and parts[0] == "prefix":
                from alltime_leaderboard import try_buy_name_badge

                _ok, chat = try_buy_name_badge(user_key, nick, parts[1], alltime_path)
                lines.append(chat)
                return lines, False, None, None, None, None, None, None
            if len(parts) >= 2 and parts[-1] == "heart":
                from heart_icons import HEART_COLOR_COMMAND_TO_HEX
                from alltime_leaderboard import try_buy_heart_color

                color_cmd = parts[0]
                if color_cmd not in HEART_COLOR_COMMAND_TO_HEX:
                    lines.append(
                        f'[Shop] Unknown heart colour "{color_cmd}" — type !hearts for the list (!buy pink heart).'
                    )
                    return lines, False, None, None, None, None, None, None
                _ok, chat = try_buy_heart_color(user_key, nick, color_cmd, alltime_path)
                lines.append(chat)
                return lines, False, None, None, None, None, None, None
            if len(parts) >= 2 and parts[0] == "heart":
                from heart_icons import HEART_COLOR_COMMAND_TO_HEX
                from alltime_leaderboard import try_buy_heart_color

                color_cmd = parts[1]
                if color_cmd not in HEART_COLOR_COMMAND_TO_HEX:
                    lines.append(
                        f'[Shop] Unknown heart colour "{color_cmd}" — type !hearts for the list.'
                    )
                    return lines, False, None, None, None, None, None, None
                _ok, chat = try_buy_heart_color(user_key, nick, color_cmd, alltime_path)
                lines.append(chat)
                return lines, False, None, None, None, None, None, None
            if sub == "glow":
                from alltime_leaderboard import try_buy_glow

                _ok, chat = try_buy_glow(user_key, nick, alltime_path)
                lines.append(chat)
                return lines, False, None, None, None, None, None, None
            if len(parts) >= 2 and parts[0] == "winsound":
                from win_sounds import try_buy_win_sound

                _ok, chat = try_buy_win_sound(user_key, nick, parts[1], alltime_path)
                lines.append(chat)
                return lines, False, None, None, None, None, None, None
            if len(parts) >= 2 and parts[0] == "win":
                from win_sounds import try_buy_win_sound

                _ok, chat = try_buy_win_sound(user_key, nick, parts[1], alltime_path)
                lines.append(chat)
                return lines, False, None, None, None, None, None, None
            lines.append(
                "[Shop] Usage: !buy glow (5000 pts) · "
                f"!buy prefix star|heart|crown ({NAME_BADGE_COST} pts first time each; switch owned free) · "
                f"!buy pink heart or !buy heart pink ({HEART_COLOR_COST} pts first time each) — type !hearts · "
                "!mascot crown | !mascot heart (glow + heart: free) · "
                "!buy winsound <id> (see !winsounds)."
            )
            return lines, False, None, None, None, None, None, None

        if cmd == "command":
            if not alltime_path:
                lines.append("[Shop] !command is not available here.")
                return lines, False, None, None, None, None, None, None
            left = _command_list_cooldown_left(user_key)
            if left > 0:
                w = max(1, int(math.ceil(left)))
                lines.append(f"@{nick}: Command list on cooldown — try again in {w}s.")
                return lines, False, None, None, None, None, None, None
            _register_command_list_use(user_key)
            pop = command_list_popup_payload(nick, user_key)
            lines.append(
                f"@{nick}: Showing colour commands on stream (!command cooldown {int(COMMAND_LIST_COOLDOWN_SEC)}s)."
            )
            return lines, False, None, None, None, pop, None, None

        if cmd == "hangman":
            left = _hangman_help_cooldown_left(user_key)
            if left > 0:
                w = max(1, int(math.ceil(left)))
                lines.append(f"@{nick}: How to play is on cooldown — try again in {w}s.")
                return lines, False, None, None, None, None, None, None
            _register_hangman_help_use(user_key)
            hpop = hangman_help_popup_payload(nick, user_key)
            sec = int(_hangman_help_cooldown_sec())
            lines.append(
                f"@{nick}: Showing full-screen how to play on stream (!hangman cooldown {sec}s)."
            )
            return lines, False, None, None, None, None, hpop, None

        if cmd == "hearts":
            if not alltime_path:
                lines.append("[Shop] !hearts is not available here.")
                return lines, False, None, None, None, None, None, None
            left = _hearts_list_cooldown_left(user_key)
            if left > 0:
                w = max(1, int(math.ceil(left)))
                lines.append(f"@{nick}: Heart list on cooldown — try again in {w}s.")
                return lines, False, None, None, None, None, None, None
            _register_hearts_list_use(user_key)
            pop = hearts_list_popup_payload(nick, user_key)
            lines.append(
                f"@{nick}: Showing heart colours on stream (!hearts cooldown {int(HEARTS_LIST_COOLDOWN_SEC)}s)."
            )
            return lines, False, None, None, None, pop, None, None

        if cmd == "mascot":
            if not alltime_path:
                lines.append("[Shop] !mascot is not available here.")
                return lines, False, None, None, None, None, None, None
            sub = (arg or "").strip().lower()
            if sub not in ("crown", "heart"):
                lines.append(
                    "[Shop] !mascot crown — glow crown mascot · !mascot heart — your purchased heart "
                    "(needs !buy glow + a heart colour; no charge)."
                )
                return lines, False, None, None, None, None, None, None
            from alltime_leaderboard import try_set_glow_mascot_pref

            _ok, chat = try_set_glow_mascot_pref(user_key, nick, sub == "crown", alltime_path)
            lines.append(chat)
            return lines, False, None, None, None, None, None, None

        if cmd == "winsounds":
            if not alltime_path:
                lines.append("[Shop] !winsounds is not available here.")
                return lines, False, None, None, None, None, None, None
            left = _winsounds_list_cooldown_left(user_key)
            if left > 0:
                w = max(1, int(math.ceil(left)))
                lines.append(f"@{nick}: Win sound list on cooldown — try again in {w}s.")
                return lines, False, None, None, None, None, None, None
            _register_winsounds_list_use(user_key)
            from win_sounds import winsounds_list_popup_payload

            pop = winsounds_list_popup_payload(nick, user_key, alltime_path)
            lines.append(
                f"@{nick}: Showing win sound shop on stream (!winsounds cooldown {int(WINSOUNDS_LIST_COOLDOWN_SEC)}s)."
            )
            return lines, False, None, None, None, pop, None, None

        if cmd == "setwinsound":
            if not alltime_path:
                lines.append("[Shop] !setwinsound is not available here.")
                return lines, False, None, None, None, None, None, None
            from win_sounds import try_set_win_sound

            sid = (arg or "").strip().lower()
            if not sid:
                lines.append("[Shop] Usage: !setwinsound <id> — type !winsounds for ids (e.g. classic, airhorn).")
                return lines, False, None, None, None, None, None, None
            _ok, chat = try_set_win_sound(user_key, nick, sid, alltime_path)
            lines.append(chat)
            return lines, False, None, None, None, None, None, None

        if cmd in NAME_COLOR_COMMANDS:
            gmsg = _shield_grace_rebuy_window_block_msg(user_key, nick)
            if gmsg:
                lines.append(gmsg)
                return lines, False, None, None, None, None, None, None
            if not alltime_path:
                lines.append("[Colour] Shop not available here.")
                return lines, False, None, None, None, None, None, None
            from alltime_leaderboard import try_buy_name_color

            _ok, chat = try_buy_name_color(user_key, nick, cmd, alltime_path)
            lines.append(chat)
            return lines, False, None, None, None, None, None, None

        if cmd in ("how", "play", "rules", "howtoplay"):
            lines.append(
                "[Guide] Posting rules into TikTok LIVE chat is handled by the Hangman web server (server.py): "
                "set TIKTOK_CHAT_SESSION_ID, TIKTOK_CHAT_TT_TARGET_IDC, and "
                "WHITELIST_AUTHENTICATED_SESSION_ID_HOST=tiktok.eulerstream.com — then type !how in LIVE."
            )
            return lines, False, None, None, None, None, None, None

        if cmd == "points":
            if not alltime_path:
                lines.append("[Points] !points is not available here.")
                return lines, False, None, None, None, None, None, None
            if session.wager is not None:
                lines.append(
                    f"@{nick}: !points is paused during the active head-to-head wager — try again after this round."
                )
                return lines, False, None, None, None, None, None, None
            left = _points_cooldown_left(user_key)
            if left > 0:
                w = max(1, int(math.ceil(left)))
                lines.append(f"@{nick}: !points is on cooldown — try again in {w}s.")
                return lines, False, None, None, None, None, None, None
            from alltime_leaderboard import display_name_for_key, user_alltime_total

            _register_points_use(user_key)
            dn = (display_name_for_key(user_key, alltime_path) or "").strip()
            name = dn or (nick or "").strip() or "Player"
            pts = user_alltime_total(user_key, alltime_path)
            popup: dict[str, Any] = {
                "name": name,
                "score": int(pts),
                "user_key": user_key,
                "duration_ms": 1800,
                "kicker": "All-time",
            }
            lines.append(f"@{name}: {pts} all-time pts.")
            return lines, False, None, popup, None, None, None, None

        if cmd in ("shop", "prices"):
            from alltime_leaderboard import GLOW_COST, NAME_BADGE_COST
            from heart_icons import HEART_COLOR_COST
            from name_colors import NAME_COLOR_COST
            from win_sounds import WIN_SOUNDS

            lines.append(
                "[Shop] All-time point prices (first unlock only; switching among things you already own is free):"
            )
            lines.append(f"  - Glow (glowing name + crown): {GLOW_COST} pts — !buy glow")
            lines.append(
                f"  - Name badge (star / heart / crown, first time each): {NAME_BADGE_COST} pts — "
                "!buy prefix star|heart|crown"
            )
            lines.append(
                f"  - Heart icon colour (first time per colour): {HEART_COLOR_COST} pts — "
                "!buy <colour> heart — list: !hearts"
            )
            lines.append(
                f"  - Stream name colour (first time per colour): {NAME_COLOR_COST} pts — "
                "!red !blue … — list: !command"
            )
            for sid in sorted(WIN_SOUNDS.keys()):
                meta = WIN_SOUNDS[sid]
                cost = int(meta.get("cost") or 0)
                if cost <= 0:
                    continue
                label = str(meta.get("name") or sid)
                lines.append(f"  - Win sound \"{label}\" ({sid}): {cost} pts — !buy winsound {sid}")
            lines.append("  - Win sound \"Classic bell\" (classic): free — !setwinsound classic")
            lines.append("Type !winsounds for the overlay picker.")
            return lines, False, None, None, None, None, None, None

        if cmd in ("queue", "song", "addsong"):
            lines.extend(
                spotify_queue_chat_lines(
                    arg=arg,
                    uid=uid,
                    user_key=user_key,
                    nick=nick,
                    host_username=host_username,
                )
            )
            return lines, False, None, None, None, None, None, None

        if cmd == "wager":
            gmsg = _shield_grace_rebuy_window_block_msg(user_key, nick)
            if gmsg:
                lines.append(gmsg)
                return lines, False, None, None, None, None, None, None
            if not alltime_path:
                lines.append("[Wager] All-time points not available here.")
                return lines, False, None, None, None, None, None, None
            if session.wager:
                lines.append(f"@{nick}: a head-to-head wager is already in progress.")
                return lines, False, None, None, None, None, None, None
            from alltime_leaderboard import display_name_for_key, resolve_user_key_from_handle, user_alltime_total

            parts = (arg or "").split()
            if len(parts) < 2:
                lines.append(
                    "[Wager] Usage: !wager USERNAME POINTS — both need that many all-time pts."
                )
                return lines, False, None, None, None, None, None, None
            try:
                amount = int(parts[-1])
            except ValueError:
                lines.append("[Wager] Points must be a whole number (e.g. !wager theirname 500).")
                return lines, False, None, None, None, None, None, None
            if amount <= 0:
                lines.append("[Wager] Amount must be positive.")
                return lines, False, None, None, None, None, None, None
            target_raw = " ".join(parts[:-1]).strip()
            tkey = resolve_user_key_from_handle(target_raw, alltime_path)
            if tkey is None:
                lines.append(f'[Wager] No all-time entry matched "{target_raw}". Try their @username.')
                return lines, False, None, None, None, None, None, None
            if tkey == user_key:
                lines.append("[Wager] You can't wager yourself.")
                return lines, False, None, None, None, None, None, None
            cpts = user_alltime_total(user_key, alltime_path)
            tpts = user_alltime_total(tkey, alltime_path)
            if cpts < amount or tpts < amount:
                lines.append(
                    f"[Wager] Both players need at least {amount} all-time pts (you: {cpts}, them: {tpts})."
                )
                return lines, False, None, None, None, None, None, None
            tname = display_name_for_key(tkey, alltime_path) or target_raw
            exp = time.monotonic() + _wager_pending_ttl_sec()
            _pending_wager_by_target[tkey] = (user_key, nick, amount, exp)
            ttl = int(_wager_pending_ttl_sec())
            lines.append(
                f"@{nick}: challenged @{tname} to a {amount} all-time pt wager! "
                f"They type !wageraccept within {ttl}s."
            )
            return lines, False, None, None, None, None, None, None

        if cmd == "wageraccept":
            gmsg = _shield_grace_rebuy_window_block_msg(user_key, nick)
            if gmsg:
                lines.append(gmsg)
                return lines, False, None, None, None, None, None, None
            if not alltime_path:
                lines.append("[Wager] All-time points not available here.")
                return lines, False, None, None, None, None, None, None
            from alltime_leaderboard import display_name_for_key, user_alltime_total

            rec = _pending_wager_by_target.pop(user_key, None)
            if rec is None:
                lines.append(f"@{nick}: no pending wager for you (or it expired).")
                return lines, False, None, None, None, None, None, None
            ch_key, ch_name, amount, exp = rec
            if time.monotonic() > exp:
                lines.append(f"@{nick}: that wager challenge expired.")
                return lines, False, None, None, None, None, None, None
            if session.wager:
                _pending_wager_by_target[user_key] = (ch_key, ch_name, amount, exp)
                lines.append("[Wager] A wager round is already active — finish it first.")
                return lines, False, None, None, None, None, None, None
            if user_alltime_total(ch_key, alltime_path) < amount or user_alltime_total(user_key, alltime_path) < amount:
                lines.append("[Wager] One of you no longer has enough all-time pts to cover this.")
                return lines, False, None, None, None, None, None, None
            maybe_round_log, w = session.begin_wager_with_clean_word_if_needed()
            if maybe_round_log:
                lines.append(maybe_round_log)
            session.activate_wager(ch_key, ch_name, user_key, nick, amount)
            ch_disp = display_name_for_key(ch_key, alltime_path) or ch_name
            lines.append(
                f"[Wager] {ch_disp} vs {nick} · {amount} all-time pts — {len(w)} letters: {session.mask()}"
            )
            intro: dict[str, Any] = {
                "duration_ms": 4500,
                "amount": amount,
                "a": {"user_key": ch_key, "name": ch_disp},
                "b": {"user_key": user_key, "name": nick},
            }
            return lines, False, None, None, None, None, None, intro

        if cmd == "guess":
            g = (arg or "").strip().upper()
            if len(g) == 1 and "A" <= g <= "Z":
                msg, completed, round_popup = session.process_guess(user_key, nick, g)
                if msg:
                    lines.extend(msg.split("\n"))
                return _maybe_autonext_after_solve(session, auto_next, completed, lines, round_popup, None, None)
            lines.append("Guess one letter: !guess T or just type T")
            return lines, False, None, None, None, None, None, None

        if cmd == "word":
            if not arg:
                lines.append(
                    f"Guess the full answer: !YOUR PHRASE (e.g. !football) or !word YOUR PHRASE "
                    f"(e.g. !word FISH AND CHIPS). Points: {WHOLE_WORD_POINTS_MIN}–{WHOLE_WORD_POINTS_MAX} "
                    f"— higher when more letters are still hidden."
                )
                return lines, False, None, None, None, None, None, None
            msg, completed, round_popup = session.process_full_word_guess(user_key, nick, arg)
            if msg:
                lines.extend(msg.split("\n"))
            return _maybe_autonext_after_solve(session, auto_next, completed, lines, round_popup, None, None)

        if cmd in ("addpoints", "addpts"):
            if not broadcaster_check(uid, host_username):
                return [], False, None, None, None, None, None, None
            if not alltime_path:
                lines.append("[HOST] All-time leaderboard path not configured.")
                return lines, False, None, None, None, None, None, None
            from alltime_leaderboard import add_points, display_name_for_key, resolve_user_key_from_handle

            parts = arg.split()
            if len(parts) < 2:
                lines.append(
                    "[HOST] Usage: !addpoints @USERNAME POINTS — adds to that viewer's **all-time** total "
                    "(use a negative number to subtract). Match by @handle or name in the leaderboard file."
                )
                return lines, False, None, None, None, None, None, None
            target_raw = parts[0].lstrip("@")
            try:
                delta = int(parts[1])
            except ValueError:
                lines.append("[HOST] POINTS must be a whole number, e.g. !addpoints theirname 500")
                return lines, False, None, None, None, None, None, None
            if delta == 0:
                lines.append("[HOST] POINTS cannot be 0.")
                return lines, False, None, None, None, None, None, None
            tkey = resolve_user_key_from_handle(target_raw, alltime_path)
            if not tkey:
                lines.append(
                    f"[HOST] No all-time row matched {target_raw!r} — viewer may need to chat once first, "
                    f"or try their exact @TikTok handle."
                )
                return lines, False, None, None, None, None, None, None
            dn = (display_name_for_key(tkey, alltime_path) or "").strip() or target_raw
            add_points(tkey, dn, delta, alltime_path)
            sign = "+" if delta > 0 else ""
            lines.append(f"[HOST] All-time for @{dn}: {sign}{delta} pts.")
            return lines, False, None, None, None, None, None, None

        if cmd in ("resetalltime", "resetleaderboard", "resetall"):
            if not broadcaster_check(uid, host_username):
                return [], False, None, None, None, None, None, None
            from alltime_leaderboard import reset_alltime_points_for_all_users

            n = reset_alltime_points_for_all_users(alltime_path)
            lines.append(
                f"[HOST] All-time leaderboard reset — {n} viewer(s) set to 0 pts (cosmetics kept)."
            )
            return lines, False, None, None, None, None, None, None

        if cmd in ("setword", "set", "random", "skip", "resetsession", "resetscores"):
            if not broadcaster_check(uid, host_username):
                return [], False, None, None, None, None, None, None
            try:
                if cmd in ("resetsession", "resetscores"):
                    session.reset_session_scores()
                    lines.append("[HOST] Session scores reset to 0 for everyone (this stream only).")
                elif cmd in ("setword", "set"):
                    if not arg:
                        lines.append("[HOST] Usage: !setword YOUR PHRASE (alias: !set)")
                    else:
                        lines.append(session.end_word_unsolved())
                        session.new_word(arg)
                        lines.append(f"[HOST] New word ({len(session.secret)} letters): {session.mask()}")
                elif cmd == "random":
                    lines.append(session.end_word_unsolved())
                    w = session.random_new_word()
                    lines.append(f"[HOST] Random word ({len(w)} letters): {session.mask()}")
                elif cmd == "skip":
                    lines.append(session.end_word_unsolved())
                    if auto_next:
                        session.random_new_word()
                        lines.append(f"Next word: {session.mask()}")
            except ValueError as e:
                lines.append(f"[HOST] Error: {e}")
            return lines, False, None, None, None, None, None, None

        if cmd not in BANG_RESERVED_COMMANDS:
            phrase = text.strip()[1:].strip()
            if phrase:
                msg, completed, round_popup = session.process_full_word_guess(user_key, nick, phrase)
                if msg:
                    lines.extend(msg.split("\n"))
                return _maybe_autonext_after_solve(session, auto_next, completed, lines, round_popup, None, None)

    letter = parse_letter_from_message(text)
    if not letter:
        return [], False, None, None, None, None, None, None

    msg, completed, round_popup = session.process_guess(user_key, nick, letter)
    if msg:
        lines.extend(msg.split("\n"))
    return _maybe_autonext_after_solve(session, auto_next, completed, lines, round_popup, None, None)
