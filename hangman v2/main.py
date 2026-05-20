"""
TikTok LIVE Hangman: chat guesses letters; per-player wrong counts and scoring.

Run (stream must be LIVE):
  py main.py --username YOUR_TIKTOK_USERNAME

Gifts, shields, Lion nuke, and likes follow the same rules as the desktop overlay (server.py).
Set HANGMAN_FAN_ONLY=1 to require Heart Me / fan team for chat and gifts (matches overlay toggle).

Offline test:
  py main.py --offline
"""
from __future__ import annotations

import argparse
import asyncio
import os
import sys
from TikTokLive.client.client import TikTokLiveClient

from alltime_leaderboard import (
    add_points,
    default_storage_path,
    display_name_for_key,
    resolve_user_key_from_handle,
)
from chat_bridge import BANG_RESERVED_COMMANDS, spotify_queue_chat_lines
from cli_tiktok_hangman import register_cli_hangman_tiktok_handlers, shutdown_cli_hangman
from hangman_game import (
    HangmanSession,
    parse_host_command,
    parse_letter_from_message,
    print_round_answer_to_console,
)
def _record_alltime_delta(user_key: str, display_name: str, delta: int) -> None:
    add_points(user_key, display_name, delta, default_storage_path())


def log(msg: str) -> None:
    print(msg, flush=True)


def build_client_and_game(
    username: str,
    host_username: str,
    max_wrong: int,
    auto_next: bool,
) -> tuple[TikTokLiveClient, HangmanSession]:
    session = HangmanSession(
        secret="A",
        max_wrong_per_player=max_wrong,
        on_event=log,
        on_score_delta=_record_alltime_delta,
        on_answer_changed=print_round_answer_to_console,
    )
    session.random_new_word()

    client = TikTokLiveClient(unique_id=username)
    sid = os.environ.get("TIKTOK_CHAT_SESSION_ID", "").strip()
    idc = os.environ.get("TIKTOK_CHAT_TT_TARGET_IDC", "").strip()
    if sid and idc:
        client.web.set_session(sid, idc)

    register_cli_hangman_tiktok_handlers(
        client,
        session,
        host_username=host_username,
        auto_next=auto_next,
        log=log,
    )

    return client, session


async def run_live(username: str, host_username: str, max_wrong: int, auto_next: bool) -> None:
    client, session = build_client_and_game(username, host_username, max_wrong, auto_next)
    log(f"Connecting to @{username} (host commands: @{host_username})…")
    log(f"Word: {session.mask()}  |  Host: !help")
    try:
        await client.connect()
    except KeyboardInterrupt:
        log("Stopped.")
    finally:
        await shutdown_cli_hangman()
        await client.disconnect()


def run_offline(max_wrong: int) -> None:
    session = HangmanSession(
        secret="PYTHON",
        max_wrong_per_player=max_wrong,
        on_event=log,
        on_score_delta=_record_alltime_delta,
        on_answer_changed=print_round_answer_to_console,
    )
    session.new_word("PYTHON")
    log("Offline mode — type letters to guess, !board for scores, !quit to exit.")
    log(f"Word: {session.mask()}")

    async def stdin_loop() -> None:
        loop = asyncio.get_event_loop()
        while True:
            line = await loop.run_in_executor(None, lambda: sys.stdin.readline())
            if not line:
                break
            text = line.strip()
            if text.lower() in ("!quit", "!exit"):
                break
            parsed = parse_host_command(text)
            if parsed:
                cmd, arg = parsed
                arg = (arg or "").strip()
                if cmd in ("board", "leaderboard"):
                    log(session.leaderboard_line())
                elif cmd == "help":
                    log(
                        "!PHRASE = full answer (e.g. !football); !word PHRASE = same; !setword PHRASE = new word; "
                        "!resetsession = zero session scores; !skip; !addpoints @handle POINTS (all-time); "
                        "one letter or !guess T"
                    )
                elif cmd in ("addpoints", "addpts"):
                    path = default_storage_path()
                    parts = arg.split()
                    if len(parts) < 2:
                        log("[HOST] Usage: !addpoints USERNAME POINTS (all-time; negative subtracts).")
                    else:
                        target_raw = parts[0].lstrip("@")
                        try:
                            delta = int(parts[1])
                        except ValueError:
                            log("[HOST] POINTS must be a whole number.")
                        else:
                            if delta == 0:
                                log("[HOST] POINTS cannot be 0.")
                            else:
                                tkey = resolve_user_key_from_handle(target_raw, path)
                                if not tkey:
                                    log(f"[HOST] No all-time match for {target_raw!r}.")
                                else:
                                    dn = (display_name_for_key(tkey, path) or "").strip() or target_raw
                                    add_points(tkey, dn, delta, path)
                                    sign = "+" if delta > 0 else ""
                                    log(f"[HOST] All-time for @{dn}: {sign}{delta} pts.")
                elif cmd == "word" and arg:
                    msg, completed, _ = session.process_full_word_guess("offline_tester", "Tester", arg)
                    if msg:
                        log(msg)
                    if completed:
                        session.random_new_word()
                        log(f"Next word: {session.mask()}")
                elif cmd == "word" and not arg:
                    log("Usage: !YOUR PHRASE (e.g. !football) or !word FISH AND CHIPS")
                elif cmd in ("queue", "song", "addsong"):
                    for line in spotify_queue_chat_lines(
                        arg=arg,
                        uid="offline_tester",
                        user_key="offline_tester",
                        nick="Tester",
                        host_username="offline_tester",
                    ):
                        log(line)
                elif cmd not in BANG_RESERVED_COMMANDS:
                    phrase = text.strip()[1:].strip()
                    if phrase:
                        msg, completed, _ = session.process_full_word_guess("offline_tester", "Tester", phrase)
                        if msg:
                            log(msg)
                        if completed:
                            session.random_new_word()
                            log(f"Next word: {session.mask()}")
                elif cmd in ("resetsession", "resetscores"):
                    session.reset_session_scores()
                    log("[HOST] Session scores reset to 0 (this session only).")
                elif cmd in ("setword", "set") and arg:
                    try:
                        session.end_word_unsolved()
                        session.new_word(arg)
                        log(f"New word: {session.mask()}")
                    except ValueError as e:
                        log(str(e))
                elif cmd == "skip":
                    log(session.end_word_unsolved())
                    session.random_new_word()
                    log(f"Next: {session.mask()}")
                continue
            letter = parse_letter_from_message(text)
            if not letter:
                log("Send one letter (e.g. P) or !board.")
                continue
            msg, completed, _ = session.process_guess("offline_tester", "Tester", letter)
            if msg:
                log(msg)
            if completed:
                session.random_new_word()
                log(f"Next word: {session.mask()}")

    asyncio.run(stdin_loop())


def main() -> None:
    p = argparse.ArgumentParser(description="TikTok LIVE Hangman")
    p.add_argument(
        "--username",
        default=os.environ.get("TIKTOK_LIVE_USERNAME", "y666.suf"),
        help="TikTok @username that is currently LIVE (default: y666.suf; override with TIKTOK_LIVE_USERNAME)",
    )
    p.add_argument(
        "--host-username",
        default="",
        help="Only this @username can use !word / !skip / etc. (default: same as --username)",
    )
    p.add_argument(
        "--max-wrong",
        type=int,
        default=6,
        help="Wrong guesses per player per word before they are out for that word (default 6).",
    )
    p.add_argument(
        "--no-auto-next",
        action="store_true",
        help="After a solve, do not start a random next word automatically.",
    )
    p.add_argument(
        "--offline",
        action="store_true",
        help="Test game logic without TikTok (stdin).",
    )
    args = p.parse_args()
    try:
        from pathlib import Path

        from dotenv import load_dotenv

        load_dotenv(Path(__file__).resolve().parent / ".env", override=False)
    except ImportError:
        pass
    host = args.host_username or args.username

    if args.offline:
        run_offline(args.max_wrong)
        return

    asyncio.run(
        run_live(
            username=args.username,
            host_username=host,
            max_wrong=args.max_wrong,
            auto_next=not args.no_auto_next,
        )
    )


if __name__ == "__main__":
    main()
