"""
TikTok LIVE handlers for the CLI hangman runner: same gift / shield / Lion / like rules as server.py.

Overlay-only payloads (!hangman, !command, etc.) are echoed as console text where useful.
"""
from __future__ import annotations

import asyncio
import math
import os
import time
from collections.abc import Callable
from typing import Any

from TikTokLive.client.client import TikTokLiveClient
from TikTokLive.events import CommentEvent, ConnectEvent, DisconnectEvent, GiftEvent, LikeEvent

from alltime_leaderboard import (
    add_points,
    canonical_alltime_key,
    default_storage_path,
    display_name_for_key,
    record_live_likes_lifetime,
    resolve_user_key_from_handle,
    reset_alltime_points_for_all_users,
    transfer_alltime_points,
    try_award_live_like_alltime_bonus,
    try_wager_settle,
)
from chat_bridge import hangman_help_payload_text, process_chat_message
from hangman_game import HangmanSession
from racing_debut_shield import (
    default_shield_path,
    grant_shield,
    is_protected,
    is_shield_drop_grace_active,
    shield_drop_grace_until,
    shield_duration_sec,
    shield_expiry_unix,
    start_shield_drop_grace,
    trim_shield_by_hours,
)
from text_normalize import normalize_chat_for_letter_parse, normalize_lookup_token
from tiktok_comment_user import (
    comment_user_is_fan_club_member,
    effective_tiktok_user_key,
    extract_comment_author,
    extract_gift_sender,
    gift_user_is_fan_club_member,
    stable_user_key_and_name,
)
from tiktok_gifts_shared import (
    cap_gift_match,
    car_drifting_gift_match,
    car_drifting_trim_hours,
    fmt_mmss,
    fmt_shield_remaining,
    galaxy_gift_match,
    gift_debug,
    gift_debug_enabled,
    gift_diamond_alltime_points,
    lion_gift_match,
    lion_nuke_window_sec,
    money_gun_gift_match,
    parse_galaxy_target,
    racing_debut_gift_match,
    rosa_gift_match,
    space_cat_gift_match,
    tiktok_event_is_current_session,
    tiktok_like_event_is_current_session,
)

_cli_wall_session_started: float = 0.0
_cli_wall_tiktok_connected: float | None = None

_cli_game_lock: asyncio.Lock | None = None

galaxy_pending: dict[str, float] = {}
cap_ignore_pending: dict[str, float] = {}
car_drifting_pending: dict[str, float] = {}
space_cat_pending: dict[str, float] = {}

_lion_nuke_task: asyncio.Task | None = None
_lion_nuke_lock = asyncio.Lock()
_lion_nuke_deadline_unix: float | None = None
_lion_nuke_started_by_key: str = ""
_lion_nuke_started_by_name: str = ""

_lion_lock_chat_notice_last: dict[str, float] = {}
_lion_lock_gift_notice_last: dict[str, float] = {}

_fan_gate_last: dict[str, float] = {}
FAN_GATE_THROTTLE_SEC = 22.0

_tiktok_guide_last: dict[str, float] = {}

_live_room_like_total_api: int = 0
_live_like_by_user: dict[str, int] = {}
_live_like_display_name: dict[str, str] = {}
_live_like_bonus_tens_cursor: dict[str, int] = {}
_live_like_lock: asyncio.Lock | None = None

_cli_auto_next_delay_task: asyncio.Task | None = None


def _game_lock() -> asyncio.Lock:
    global _cli_game_lock
    if _cli_game_lock is None:
        _cli_game_lock = asyncio.Lock()
    return _cli_game_lock


def _live_like_lock_get() -> asyncio.Lock:
    global _live_like_lock
    if _live_like_lock is None:
        _live_like_lock = asyncio.Lock()
    return _live_like_lock


def _reset_live_like_stats() -> None:
    global _live_room_like_total_api, _live_like_by_user, _live_like_display_name
    global _live_like_bonus_tens_cursor
    _live_room_like_total_api = 0
    _live_like_by_user.clear()
    _live_like_display_name.clear()
    _live_like_bonus_tens_cursor.clear()


def _fan_only_enabled() -> bool:
    return os.environ.get("HANGMAN_FAN_ONLY", "").strip().lower() in ("1", "true", "yes", "on")


def _is_stream_host(uid: str, user_key: str, host_username: str) -> bool:
    h = normalize_lookup_token(host_username or "")
    if not h:
        return False
    return normalize_lookup_token(uid) == h or normalize_lookup_token(user_key) == h


def _fan_gate_should_emit(user_key: str) -> bool:
    now = time.monotonic()
    last = _fan_gate_last.get(user_key, 0.0)
    if now - last < FAN_GATE_THROTTLE_SEC:
        return False
    _fan_gate_last[user_key] = now
    return True


def _session_user_key(uid: str, nick: str) -> str:
    base = effective_tiktok_user_key(uid, nick)
    return canonical_alltime_key(base, nick, default_storage_path())


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


def _resolve_cap_ignore_target(session: HangmanSession, raw: str) -> str | None:
    if session is None:
        return None
    s = normalize_lookup_token(raw or "")
    if len(s) < 2:
        return None
    path = default_storage_path()
    for key, p in session.players.items():
        if normalize_lookup_token(key) == s:
            return key
        dn = normalize_lookup_token(p.display_name or "")
        if dn and dn == s:
            return key
    return resolve_user_key_from_handle(raw, path)


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
    custom = os.environ.get("HANGMAN_PLAY_GUIDE_MESSAGE", "").strip()
    if custom:
        body = custom.replace("\\n", "\n")
    else:
        body = (
            "How to play Hangman here: guess one letter (A–Z) in chat or use !guess T. "
            "Right letter +10 pts, wrong −10. Guess the full answer with !YOUR PHRASE or !word PHRASE. "
            "!points shows your all-time score. Type !help for more. Good luck!"
        )
    return _split_tiktok_chat_chunks(body)


async def _post_tiktok_play_guide_to_live(client: TikTokLiveClient) -> tuple[bool, str]:
    rid = client.room_id
    if rid is None:
        return False, "[Guide] No room id yet — wait until the LIVE connection is up."
    if not _tiktok_chat_posting_configured():
        return (
            False,
            "[Guide] Set TIKTOK_CHAT_SESSION_ID + TIKTOK_CHAT_TT_TARGET_IDC to post in LIVE chat.",
        )
    chunks = _tiktok_play_guide_chunks()
    if not chunks:
        return False, "[Guide] TIKTOK_PLAY_GUIDE_MESSAGE is empty."
    try:
        for i, chunk in enumerate(chunks):
            await client.send_room_chat(chunk)
            if i < len(chunks) - 1:
                await asyncio.sleep(0.45)
    except Exception as e:
        return False, f"[Guide] TikTok chat post failed: {e!s}"
    return True, f"[Guide] Posted how-to-play ({len(chunks)} msg(s)) to TikTok LIVE chat."


async def _handle_tiktok_play_guide_comment(
    client: TikTokLiveClient,
    text: str,
    user_key: str,
    nick: str,
    log: Callable[[str], None],
) -> bool:
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
        log(f"[Guide] @{nick or key}: wait {left}s before asking for the rules again.")
        return True
    _tiktok_guide_last[key] = now
    ok, msg = await _post_tiktok_play_guide_to_live(client)
    log(msg)
    return True


async def _cli_run_lion_nuke_timer(expected_deadline_unix: float, log: Callable[[str], None]) -> None:
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
        reset_count = reset_alltime_points_for_all_users(default_storage_path())
        _lion_nuke_deadline_unix = None
        _lion_nuke_started_by_key = ""
        _lion_nuke_started_by_name = ""
        _lion_nuke_task = None
        log_lines.append(
            f"[Lion Nuke] Countdown ended — all-time points reset to 0 for {reset_count} viewer(s)."
        )
        log_lines.append(f"[Lion Nuke] Triggered by @{starter}; no counter-Lion arrived in time.")

    for line in log_lines:
        log(line)


def _cancel_cli_auto_next_delay_task() -> None:
    global _cli_auto_next_delay_task
    t = _cli_auto_next_delay_task
    if t is not None and not t.done():
        t.cancel()
    _cli_auto_next_delay_task = None


async def _run_cli_delayed_auto_next(
    session: HangmanSession,
    expected_round_id: int,
    delay_sec: float,
    auto_next: bool,
    log: Callable[[str], None],
) -> None:
    try:
        await asyncio.sleep(delay_sec)
    except asyncio.CancelledError:
        return
    async with _game_lock():
        if _lion_nuke_active_now():
            return
        if session.round_id != expected_round_id:
            return
        if not auto_next:
            return
        session.random_new_word()
        log(f"Next word ({len(session.secret)} letters): {session.mask()}")


def _log_wager_intro(wi: dict[str, Any] | None, log: Callable[[str], None]) -> None:
    if not wi:
        return
    try:
        a = wi.get("a") or {}
        b = wi.get("b") or {}
        amt = int(wi.get("amount") or 0)
        na = str(a.get("name") or a.get("user_key") or "?")
        nb = str(b.get("name") or b.get("user_key") or "?")
        log(f"[Wager] Duel active: {na} vs {nb} · {amt} all-time pts at stake.")
    except Exception:
        log("[Wager] Duel started (see chat lines above).")


async def shutdown_cli_hangman() -> None:
    """Cancel Lion nuke and delayed auto-next tasks (call before disconnecting the client)."""
    global _lion_nuke_task
    _cancel_cli_auto_next_delay_task()
    if _lion_nuke_task:
        _lion_nuke_task.cancel()
        try:
            await _lion_nuke_task
        except asyncio.CancelledError:
            pass
        _lion_nuke_task = None


def register_cli_hangman_tiktok_handlers(
    client: TikTokLiveClient,
    session: HangmanSession,
    *,
    host_username: str,
    auto_next: bool,
    log: Callable[[str], None] = print,
) -> None:
    """Register Connect / Disconnect / Like / Gift / Comment on ``client`` (CLI parity with server gifts)."""
    global _cli_wall_session_started, _cli_wall_tiktok_connected
    global _lion_nuke_task, _lion_nuke_deadline_unix, _lion_nuke_started_by_key, _lion_nuke_started_by_name

    _cli_wall_session_started = time.time()
    _cli_wall_tiktok_connected = None
    _lion_nuke_deadline_unix = None
    _lion_nuke_started_by_key = ""
    _lion_nuke_started_by_name = ""
    if _lion_nuke_task:
        _lion_nuke_task.cancel()
        _lion_nuke_task = None

    @client.on(ConnectEvent)
    async def _on_connect(_: ConnectEvent) -> None:
        global _cli_wall_tiktok_connected
        _cli_wall_tiktok_connected = time.time()
        _reset_live_like_stats()
        log("[TikTok] Connected — live feed active.")

    @client.on(DisconnectEvent)
    async def _on_disconnect(_: DisconnectEvent) -> None:
        _reset_live_like_stats()
        log("[System] TikTok feed disconnected — go live or check username.")

    @client.on(LikeEvent)
    async def _on_like(event: LikeEvent) -> None:
        try:
            if not tiktok_like_event_is_current_session(
                event,
                wall_session_started=_cli_wall_session_started,
                wall_tiktok_connected=_cli_wall_tiktok_connected,
            ):
                return
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
            path = default_storage_path()
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
                    path,
                )
                if new_cursor != tens_cursor:
                    _live_like_bonus_tens_cursor[key] = new_cursor
                if like_pts > 0:
                    log(
                        f"[Hangman] Like bonus +{like_pts} all-time for {key!r} ({session_total} likes this live; "
                        f"max +500 from likes per UTC day, not session score)."
                    )
                if key and key != "anon":
                    _lt_new, new_ltier, old_ltier = record_live_likes_lifetime(
                        key, (nick or "").strip() or key, burst, path
                    )
                    if new_ltier > old_ltier:
                        log(
                            f"[Hangman] LIVE like cosmetic tier {new_ltier} for {key!r} "
                            f"({_lt_new:,} lifetime likes on stream)."
                        )
        except Exception as e:
            log(f"[Hangman] LikeEvent handler error (non-fatal): {e!s}")

    @client.on(CommentEvent)
    async def on_comment(event: CommentEvent) -> None:
        if not tiktok_event_is_current_session(
            event,
            wall_session_started=_cli_wall_session_started,
            wall_tiktok_connected=_cli_wall_tiktok_connected,
        ):
            return
        text = normalize_chat_for_letter_parse((event.comment or "").strip())
        uid, nick = extract_comment_author(event)
        user_key = _session_user_key(uid, nick)
        path = default_storage_path()
        shield_path = default_shield_path()

        if _lion_nuke_active_now():
            if _lion_lock_notice_allowed(_lion_lock_chat_notice_last, user_key):
                left = max(0, int((_lion_nuke_deadline_unix or 0) - time.time()))
                log(
                    f"[Lion Nuke] Gameplay paused ({left // 60}:{left % 60:02d} left). "
                    "No guesses, commands, or point usage until canceled or timer ends."
                )
            return

        if await _handle_tiktok_play_guide_comment(client, text, user_key, nick, log):
            return

        if _fan_only_enabled() and not _is_stream_host(uid, user_key, host_username):
            if not comment_user_is_fan_club_member(event):
                if _fan_gate_should_emit(user_key):
                    log(f"[Fans-only] @{nick}: Heart Me / fan team required to chat or use gifts.")
                return

        galaxy_lines: list[str] = []
        cap_lines: list[str] = []
        car_drift_lines: list[str] = []
        space_cat_lines: list[str] = []
        consume_chat = False
        now = time.monotonic()

        async with _game_lock():
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
                target_raw = parse_galaxy_target(text)
                if target_raw:
                    consume_chat = True
                    resolved = resolve_user_key_from_handle(target_raw, path)
                    if resolved is None:
                        galaxy_lines.append(
                            f'[Galaxy] @{nick}: no all-time entry matched "{target_raw}". Try their @username.'
                        )
                    elif resolved == user_key:
                        galaxy_lines.append(
                            f"[Galaxy] @{nick}: you can't take all-time points from yourself."
                        )
                    elif is_protected(resolved, shield_path):
                        exp_sh = shield_expiry_unix(resolved, shield_path)
                        vlab = display_name_for_key(resolved, path)
                        galaxy_lines.append(
                            f"[Galaxy] @{nick}: {vlab} is protected from Galaxy steals (Racing Debut) "
                            f"— {fmt_shield_remaining(exp_sh) if exp_sh else 'active'}."
                        )
                    elif is_shield_drop_grace_active(resolved):
                        vlab = display_name_for_key(resolved, path)
                        until = shield_drop_grace_until(resolved)
                        left = max(0, int((until or 0) - time.time()))
                        galaxy_lines.append(
                            f"[Galaxy] @{nick}: {vlab} can re-buy with Racing Debut — Galaxy steals paused "
                            f"({left // 60}:{left % 60:02d} left)."
                        )
                    else:
                        ok, moved, victim_label = transfer_alltime_points(resolved, user_key, nick, path)
                        if ok:
                            galaxy_pending.pop(user_key, None)
                            galaxy_lines.append(
                                f"[Galaxy] @{nick} took {moved} all-time pts from {victim_label} "
                                f"— new total added to @{nick}."
                            )
                            log(f"[Hangman] Galaxy transfer: {moved} pts from {resolved!r} to {user_key!r}")
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
                    target_raw = parse_galaxy_target(text)
                    if target_raw:
                        consume_chat = True
                        resolved = _resolve_cap_ignore_target(session, target_raw)
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
                            log(f"[Hangman] Cap sideline queued for next word: victim={resolved!r} by {user_key!r}")

            if not consume_chat:
                drexp = car_drifting_pending.get(user_key)
                if drexp is not None and drexp > now:
                    target_raw = parse_galaxy_target(text)
                    if target_raw:
                        consume_chat = True
                        resolved = resolve_user_key_from_handle(target_raw, path)
                        trim_h = car_drifting_trim_hours()
                        if resolved is None:
                            car_drift_lines.append(
                                f'[Car Drifting] @{nick}: no all-time entry matched "{target_raw}". Try their @username.'
                            )
                        elif resolved == user_key:
                            car_drift_lines.append(
                                f"[Car Drifting] @{nick}: pick another player (not yourself)."
                            )
                        else:
                            vlab = display_name_for_key(resolved, path)
                            outcome, new_exp = trim_shield_by_hours(resolved, trim_h, shield_path)
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
                                log(f"[Hangman] Car Drifting: shield removed for {resolved!r} by {user_key!r}")
                            else:
                                car_drifting_pending.pop(user_key, None)
                                new_exp_f = float(new_exp) if new_exp is not None else 0.0
                                left = fmt_shield_remaining(new_exp_f)
                                car_drift_lines.append(
                                    f"[Car Drifting] @{nick}: removed {trim_h:g}h from {vlab}'s shield — "
                                    f"protection now ends in {left}."
                                )
                                log(f"[Hangman] Car Drifting: shield shortened for {resolved!r} by {user_key!r}")

            if not consume_chat:
                scex = space_cat_pending.get(user_key)
                if scex is not None and scex > now:
                    target_raw = parse_galaxy_target(text)
                    if target_raw:
                        consume_chat = True
                        resolved = resolve_user_key_from_handle(target_raw, path)
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
                            exp = grant_shield(resolved, shield_path)
                            left = fmt_shield_remaining(exp)
                            vlab = display_name_for_key(resolved, path)
                            hrs = shield_duration_sec() / 3600.0
                            space_cat_lines.append(
                                f"[Space Cat] @{nick} — {vlab} now has ~{hrs:g}h Galaxy protection ({left})."
                            )
                            log(f"[Hangman] Space Cat: shield granted to {resolved!r} by {user_key!r}")

        for block in (galaxy_lines, cap_lines, car_drift_lines, space_cat_lines):
            for line in block:
                log(line)
            if block and consume_chat:
                return

        round_popup_out: dict[str, Any] | None = None
        async with _game_lock():
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
                alltime_path=path,
            )
            rid_after = session.round_id
            snap_round = session.round_id
            if rid_after != rid_before:
                _cancel_cli_auto_next_delay_task()

            round_popup_out = dict(round_popup) if round_popup is not None else None
            if round_popup_out and round_popup_out.get("wager_settlement"):
                ws = round_popup_out["wager_settlement"]
                ok, settle_err, transferred = try_wager_settle(
                    str(ws.get("winner_key") or ""),
                    str(ws.get("loser_key") or ""),
                    int(ws.get("amount") or 0),
                    str(ws.get("winner_name") or ""),
                    path,
                )
                round_popup_out["wager_alltime_settled"] = ok
                ws["settled_amount"] = int(transferred)
                if not ok and settle_err:
                    ws["settlement_error"] = settle_err
                elif ok:
                    log(f"[Wager] All-time settlement: {transferred} pts transferred to winner.")

        for line in lines:
            log(line)
        if hangman_help_popup:
            log("[!hangman] " + hangman_help_payload_text())
        if cmd_list_popup:
            log("[!command] Colour list shown on overlay in desktop mode; see !help for command names.")
        if points_popup:
            log(f"[Points popup] {points_popup!r}")
        _log_wager_intro(wager_intro_popup, log)

        if auto_next_delay_sec is not None and auto_next_delay_sec > 0:
            _cancel_cli_auto_next_delay_task()
            global _cli_auto_next_delay_task
            _cli_auto_next_delay_task = asyncio.create_task(
                _run_cli_delayed_auto_next(
                    session, snap_round, float(auto_next_delay_sec), auto_next, log
                )
            )

    @client.on(GiftEvent)
    async def on_gift(event: GiftEvent) -> None:
        global _lion_nuke_task, _lion_nuke_deadline_unix, _lion_nuke_started_by_key, _lion_nuke_started_by_name

        if not tiktok_event_is_current_session(
            event,
            wall_session_started=_cli_wall_session_started,
            wall_tiktok_connected=_cli_wall_tiktok_connected,
        ):
            gift_debug("skip: outside chat time window (backlog/replay)")
            return

        try:
            gid = int(event.gift.id or 0)
        except (TypeError, ValueError):
            gid = 0
        gname = event.gift.name or ""
        uid, nick = extract_gift_sender(event)
        sender_key = _session_user_key(uid, nick)
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
        gift_debug(
            f"in id={gid} name={gname!r} streakable={bool(event.gift.streakable)} "
            f"streaking={bool(event.streaking)} repeat_end={repeat_end} repeat_count={repeat_count} "
            f"diamonds={dcount} nick={nick!r} key={sender_key!r}"
        )
        if streak_mid and not rosa_gift_match(gname, gid):
            gift_debug("skip: mid-streak tick (not Rosa — wait for streak end for other gifts)")
            return

        if _fan_only_enabled() and not _is_stream_host(uid, sender_key, host_username):
            if not gift_user_is_fan_club_member(event):
                if _fan_gate_should_emit(sender_key):
                    log(f"[Fans-only] @{nick}: Heart Me / fan team required to chat or use gifts.")
                gift_debug("skip: fans-only mode (not Heart Me / fan team on this payload)")
                return

        path = default_storage_path()
        shield_path = default_shield_path()

        if galaxy_gift_match(gname, gid):
            gift_debug("branch: Galaxy — pending username target")
            ttl = float(os.environ.get("HANGMAN_GALAXY_PENDING_SEC", "1800"))
            async with _game_lock():
                galaxy_pending[sender_key] = time.monotonic() + ttl
            log(
                f"[Galaxy] @{nick} — type a player's @username (one word) to take their all-time points "
                f"and add them to your total. Expires in {int(ttl // 60)} min."
            )
            return

        if car_drifting_gift_match(gname, gid):
            gift_debug("branch: Car Drifting — pending trim target")
            ttl = float(os.environ.get("HANGMAN_CAR_DRIFTING_PENDING_SEC", "1800"))
            trim_h = car_drifting_trim_hours()
            async with _game_lock():
                car_drifting_pending[sender_key] = time.monotonic() + ttl
            log(
                f"[Car Drifting] @{nick} — type a player's @username (one word) to remove {trim_h:g} hours "
                f"from their Racing Debut shield (Galaxy protection). Expires in {int(ttl // 60)} min."
            )
            return

        if space_cat_gift_match(gname, gid):
            gift_debug("branch: Space Cat — pending shield grant target")
            ttl = float(os.environ.get("HANGMAN_SPACE_CAT_PENDING_SEC", "1800"))
            hrs = shield_duration_sec() / 3600.0
            async with _game_lock():
                space_cat_pending[sender_key] = time.monotonic() + ttl
            log(
                f"[Space Cat] @{nick} — type a player's @username (one word) to give them ~{hrs:g}h "
                f"Racing Debut shield (Galaxy protection), not yourself. Expires in {int(ttl // 60)} min."
            )
            return

        if lion_gift_match(gname, gid):
            gift_debug("branch: Lion — nuke start or counter-Lion")
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
                        f"[Lion Nuke] Counter-Lion from @{nick} stopped the reset with {fmt_mmss(left)} left."
                    )
                    log_lines.append(f"[Lion Nuke] Safe — @{started_by}'s nuke was canceled.")
                else:
                    window_sec = lion_nuke_window_sec()
                    deadline = now_unix + window_sec
                    _lion_nuke_deadline_unix = deadline
                    _lion_nuke_started_by_key = sender_key
                    _lion_nuke_started_by_name = nick
                    _lion_nuke_task = asyncio.create_task(_cli_run_lion_nuke_timer(deadline, log))
                    log_lines.append(
                        f"[Lion Nuke] @{nick} triggered a full all-time reset in {fmt_mmss(window_sec)}."
                    )
                    log_lines.append(
                        "[Lion Nuke] To avoid reset, someone must send another Lion before the timer hits 0."
                    )
            for line in log_lines:
                log(line)
            return

        if _lion_nuke_active_now():
            gift_debug("skip: Lion lockdown — gifts paused (non-Lion)")
            if _lion_lock_notice_allowed(_lion_lock_gift_notice_last, sender_key):
                left = max(0, int((_lion_nuke_deadline_unix or 0) - time.time()))
                log(
                    f"[Lion Nuke] Gift effects paused ({left // 60}:{left % 60:02d} left). "
                    "Only another Lion can cancel the reset."
                )
            return

        if racing_debut_gift_match(gname, gid):
            gift_debug("branch: Racing Debut — shield granted")
            hrs = shield_duration_sec() / 3600.0
            exp = grant_shield(sender_key, shield_path)
            left = fmt_shield_remaining(exp)
            log(
                f"[Racing Debut] @{nick} — your all-time points are safe from Galaxy steals for "
                f"{hrs:g}h ({left}). Send again later to extend."
            )
            return

        if cap_gift_match(gname, gid):
            gift_debug("branch: Cap — pending sideline target")
            ttl = float(os.environ.get("HANGMAN_CAP_PENDING_SEC", "1800"))
            async with _game_lock():
                cap_ignore_pending[sender_key] = time.monotonic() + ttl
            log(
                f"[Cap] @{nick} — type a player's @username (one word) to sideline them for the next word "
                f"(they can still play this word). Expires in {int(ttl // 60)} min."
            )
            return

        if money_gun_gift_match(gname, gid):
            gift_debug("branch: Money Gun — wrong-guess shield rounds")
            async with _game_lock():
                rounds = session.grant_money_gun_shield(sender_key, nick, rounds=5)
            log(
                f"[Money Gun] @{nick} — no wrong-guess point loss for {rounds} rounds "
                "(letters and full-word misses)."
            )
            return

        diamond_pts = gift_diamond_alltime_points(event)
        gift_log: list[str] = []

        if rosa_gift_match(gname, gid):
            gift_debug("branch: Rosa — hint attempt (one per word)")
            async with _game_lock():
                hint_popup_payload = session.try_rosa_hint_popup()
            if hint_popup_payload:
                hint = str(hint_popup_payload.get("hint") or "")
                gift_log.append(f"[Rosa] @{nick} — hint: {hint}")
            elif not streak_mid:
                gift_log.append(
                    f"[Rosa] @{nick} — no hint (already used this round, or the word is fully revealed)."
                )

        if diamond_pts > 0 and sender_key and sender_key != "anon" and not streak_mid:
            gift_debug(f"branch: generic diamond → +{diamond_pts} all-time (ratio/cap applied)")
            add_points(sender_key, nick, diamond_pts, path)
            gdisp = (gname or "gift").strip() or "gift"
            gift_log.append(
                f'[Gift] @{nick} +{diamond_pts} all-time from "{gdisp}" (TikTok diamond value).'
            )
            if diamond_pts >= 500:
                log(f"[Hangman] Gift → all-time +{diamond_pts} for {sender_key!r} ({gdisp!r}).")

        for line in gift_log:
            log(line)
        if gift_debug_enabled() and not gift_log:
            if diamond_pts <= 0:
                gift_debug(
                    f"tail: no log (diamond_pts=0 rosa={rosa_gift_match(gname, gid)} streak_mid={streak_mid})"
                )
            else:
                gift_debug(
                    f"tail: diamond_pts={diamond_pts} skipped add_points (streak_mid={streak_mid})"
                )
