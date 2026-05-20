"""
Hangman session: shared word, per-player wrong counts and scores.
"""
from __future__ import annotations

import os
import re
import random
import time
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Optional

from alltime_leaderboard import (
    default_storage_path,
    persist_word_solve_streak_currents_batch,
    record_word_streak_peak,
    word_solve_streak_current_for_key,
)
from text_normalize import normalize_chat_for_letter_parse
from word_bank import UK_WORDS as DEFAULT_WORDS, get_word_choice_rng
from word_topic import word_theme_label

POINTS_CORRECT = 10
POINTS_WRONG = -10
BONUS_MOST_CORRECT_IN_WORD = 50
# Whole-phrase guess (!word ANSWER): reward risk — more points when fewer letter slots were revealed.
WHOLE_WORD_POINTS_MIN = 40
WHOLE_WORD_POINTS_MAX = 240
# Avoid repeating the same answer for this many recent rounds (random picks only).
RECENT_ANSWERS_MAX = 50

# If !word arrives just after someone else solved, matching the previous answer costs no points (chat race).
# Default is long enough to cover HANGMAN_AUTO_NEXT_DELAY_SEC + TikTok chat lag (see chat_bridge).
def _late_word_grace_seconds() -> float:
    try:
        return max(0.5, float(os.environ.get("HANGMAN_LATE_WORD_GRACE_SEC", "7").strip()))
    except ValueError:
        return 7.0


def _recent_deque() -> deque[str]:
    return deque(maxlen=RECENT_ANSWERS_MAX)


# Cross-game command-like tokens that should never be valid Hangman answers.
BLOCKED_SECRET_WORDS: frozenset[str] = frozenset({"PLAY", "END", "P1", "P2"})


def print_round_answer_to_console(normalized_answer: str) -> None:
    """Print the current answer to the process console for the host (set HANGMAN_PRINT_ANSWER=0 to disable)."""
    if os.environ.get("HANGMAN_PRINT_ANSWER", "1").strip().lower() in ("0", "false", "no"):
        return
    pretty = normalized_answer.replace(" ", " · ")
    print(f"[Hangman] Round answer: {pretty}", flush=True)


def normalize_secret(text: str) -> str:
    """Uppercase A–Z and spaces only; collapse whitespace. At least one letter required."""
    s = text.upper()
    s = re.sub(r"[^A-Z\s]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    if not s or not any(c.isalpha() for c in s):
        raise ValueError("Need at least one letter (phrases can use spaces).")
    if s in BLOCKED_SECRET_WORDS:
        raise ValueError(f'"{s.lower()}" is reserved and cannot be used in Hangman.')
    return s


def letter_position_reveal_ratio(secret: str, guessed: set[str]) -> float:
    """Share of letter positions already revealed (0–1). Spaces ignored."""
    letter_positions = [c for c in secret if c != " "]
    if not letter_positions:
        return 1.0
    revealed = sum(1 for c in letter_positions if c in guessed)
    return revealed / len(letter_positions)


def whole_word_award_points(secret: str, guessed_before: set[str]) -> tuple[int, float, float]:
    """
    Points for a correct full-phrase guess, plus (reveal_ratio, hidden_ratio) for logging.
    More hidden letters → higher score (up to WHOLE_WORD_POINTS_MAX).
    """
    r = letter_position_reveal_ratio(secret, guessed_before)
    hidden = max(0.0, min(1.0, 1.0 - r))
    span = WHOLE_WORD_POINTS_MAX - WHOLE_WORD_POINTS_MIN
    # Slight curve: last few hidden letters still matter
    pts = WHOLE_WORD_POINTS_MIN + int(span * (hidden**1.12))
    pts = max(WHOLE_WORD_POINTS_MIN, min(WHOLE_WORD_POINTS_MAX, pts))
    return pts, r, hidden


def rosa_hint_text(secret: str, guessed: set[str]) -> str:
    """
    Short hint for the Rosa gift: word lengths / structure plus one random letter not yet revealed.
    Does not print the full answer.
    """
    words = secret.split()
    parts: list[str] = []
    if len(words) > 1:
        parts.append(f"{len(words)} words")
        parts.append(" · ".join(f"{len(w)} letters" for w in words))
    else:
        parts.append(f"{len(words[0])} letters")
    hidden_pool = sorted({c for c in secret if c.isalpha() and c not in guessed})
    if hidden_pool:
        pick = random.choice(hidden_pool)
        parts.append(f"a hidden letter is {pick}")
    else:
        parts.append("every letter is already visible")
    return " · ".join(parts)


def parse_letter_from_message(text: str) -> Optional[str]:
    """Extract a single A-Z guess from chat (e.g. 'a', '!e', '!guess T', '*A*')."""
    if not text:
        return None
    raw = normalize_chat_for_letter_parse(text).upper()
    if not raw:
        return None
    # Explicit !guess / !GUESS with space (avoids treating 'G' from the word GUESS as the letter)
    m = re.match(r"^!GUESS\s+([A-Z])(?:\s|[!.])*$", raw)
    if m:
        return m.group(1)
    # Bare letter: A, !A, !A.
    m = re.match(r"^!?([A-Z])\.?$", raw)
    if m:
        return m.group(1)
    if len(raw) == 1 and raw.isalpha():
        return raw
    # Exactly one A–Z in the message (emoji/punctuation around it: "🔥A", "A!")
    letters = [c for c in raw if "A" <= c <= "Z"]
    if len(letters) == 1:
        return letters[0]
    return None


@dataclass
class PlayerState:
    user_key: str
    display_name: str
    score: int = 0
    incorrect_this_word: int = 0
    correct_guesses_this_word: int = 0
    eliminated_this_word: bool = False
    # Wager: max wrong guesses before out (phase 1 = max_wrong; after double-KO extension += 5).
    wager_wrong_cap: Optional[int] = None
    # Consecutive words this player sealed (winning letter or !word); others reset to 0 each solve.
    # Host !skip / !random / !setword clears everyone (see end_word_unsolved).
    word_solve_streak: int = 0
    # Money Gun: while > 0, wrong guesses still count toward elimination, but do not reduce points.
    # This value decrements when a new round starts.
    money_gun_rounds_left: int = 0


@dataclass
class WagerState:
    key_a: str
    key_b: str
    name_a: str
    name_b: str
    amount: int
    extension_used: bool = False


@dataclass
class HangmanSession:
    secret: str
    max_wrong_per_player: int = 6
    on_event: Optional[Callable[[str], None]] = None
    on_score_delta: Optional[Callable[[str, str, int], None]] = None
    on_answer_changed: Optional[Callable[[str], None]] = None
    guessed_letters: set[str] = field(default_factory=set)
    players: dict[str, PlayerState] = field(default_factory=dict)
    recent_secrets: deque[str] = field(default_factory=_recent_deque)
    rosa_hint_used_this_word: bool = False
    # Cap gift: viewers queued here are blocked for the word that starts after redemption (one round only).
    queued_round_ignore: set[str] = field(default_factory=set)
    active_round_ignore: set[str] = field(default_factory=set)
    word_theme: str = "Theme: General vocabulary"
    # (normalized secret, monotonic time) for rounds that just finished — late !word can avoid penalty.
    _recent_completed_rounds: deque[tuple[str, float]] = field(
        default_factory=lambda: deque(maxlen=48)
    )
    # Bumps on every new_word(); used to skip stale delayed auto-next if host skips early.
    round_id: int = 0
    # Consecutive words solved (host !skip / !random resets streak).
    win_streak: int = 0
    # Head-to-head all-time wager (two players only; others are spectators for this word).
    wager: Optional[WagerState] = None
    # If set, word-solve streak persistence uses this file; else ``default_storage_path()``.
    alltime_path: Path | None = None

    def _alltime_path(self) -> Path:
        return self.alltime_path if self.alltime_path is not None else default_storage_path()

    def _emit(self, message: str) -> None:
        if self.on_event:
            self.on_event(message)

    def _wager_participant_blocks_negative_alltime(self, p: PlayerState) -> bool:
        """Wrong guesses still change session score, but not all-time — so settlement can use the full stake."""
        w = self.wager
        return bool(w and p.user_key in (w.key_a, w.key_b))

    def _notify_delta(self, p: PlayerState, delta: int) -> None:
        if not delta or not self.on_score_delta:
            return
        if delta < 0 and self._wager_participant_blocks_negative_alltime(p):
            return
        self.on_score_delta(p.user_key, p.display_name, int(delta))

    def _player(self, user_key: str, display_name: str) -> PlayerState:
        if user_key not in self.players:
            cur = word_solve_streak_current_for_key(user_key, self._alltime_path())
            self.players[user_key] = PlayerState(
                user_key=user_key, display_name=display_name, word_solve_streak=cur
            )
        else:
            self.players[user_key].display_name = display_name
        return self.players[user_key]

    def _effective_wrong_limit(self, p: PlayerState) -> int:
        if p.wager_wrong_cap is not None:
            return int(p.wager_wrong_cap)
        return self.max_wrong_per_player

    def _has_wrong_penalty_protection(self, p: PlayerState) -> bool:
        return int(getattr(p, "money_gun_rounds_left", 0) or 0) > 0

    def grant_money_gun_shield(self, user_key: str, display_name: str, rounds: int = 5) -> int:
        """Grant no-wrong-point-loss protection for N rounds to one viewer."""
        p = self._player(user_key, display_name)
        p.money_gun_rounds_left = max(0, int(rounds))
        return p.money_gun_rounds_left

    def _clear_wager_inner(self) -> None:
        self.wager = None
        for pl in self.players.values():
            pl.wager_wrong_cap = None

    def cancel_wager(self) -> None:
        """Host skip / round abort: drop wager without transferring all-time points."""
        self._clear_wager_inner()

    def activate_wager(self, key_a: str, name_a: str, key_b: str, name_b: str, amount: int) -> None:
        self.wager = WagerState(
            key_a=key_a,
            key_b=key_b,
            name_a=name_a,
            name_b=name_b,
            amount=int(amount),
        )
        for uk, nm in ((key_a, name_a), (key_b, name_b)):
            pl = self._player(uk, nm)
            pl.wager_wrong_cap = self.max_wrong_per_player
            pl.incorrect_this_word = 0
            pl.eliminated_this_word = False

    def wager_current_round_has_progress(self) -> bool:
        """True if the puzzle is not a clean start (letters guessed, activity on the word, or solved)."""
        if self.is_solved():
            return True
        if self.guessed_letters:
            return True
        for pl in self.players.values():
            if pl.incorrect_this_word or pl.correct_guesses_this_word or pl.eliminated_this_word:
                return True
        return False

    def begin_wager_with_clean_word_if_needed(self) -> tuple[Optional[str], str]:
        """
        If the round already has progress, end it and pick a new word so the wager starts on a fresh puzzle.
        If the board is still untouched, keep the same word and bump round_id so delayed auto-next cannot
        fire on the wrong phase.
        Returns (optional chat log from ending the round, current secret string).
        """
        if self.wager_current_round_has_progress():
            msg = self.end_word_unsolved()
            secret = self.random_new_word()
            return msg, secret
        self.cancel_wager()
        self.round_id += 1
        return None, self.secret

    def _wager_spectator_reply(self, display_name: str) -> tuple[str, bool, None]:
        w = self.wager
        assert w is not None
        return (
            f"@{display_name}: this round is a wager — {w.name_a} vs {w.name_b}. Spectators only!",
            False,
            None,
        )

    def _wager_after_both_eliminated(self) -> tuple[str, Optional[dict[str, Any]]]:
        """When both wager players are out: first time extend +5 wrongs each; second time draw."""
        w = self.wager
        if not w:
            return "", None
        pa = self.players.get(w.key_a)
        pb = self.players.get(w.key_b)
        if pa is None or pb is None:
            return "", None
        if not (pa.eliminated_this_word and pb.eliminated_this_word):
            return "", None
        if not w.extension_used:
            w.extension_used = True
            cap = self.max_wrong_per_player + 5
            for pl in (pa, pb):
                pl.incorrect_this_word = 0
                pl.eliminated_this_word = False
                pl.wager_wrong_cap = cap
            return (
                "\n⚔️ Wager: both were eliminated — +5 wrong guesses each! Keep going.",
                None,
            )
        self._clear_wager_inner()
        return (
            "\n⚔️ Wager draw — both out again. No points change.",
            {"wager_draw": True, "duration_ms": 5500},
        )

    def _finalize_solved_word(self, sealed: PlayerState) -> tuple[str, dict[str, Any]]:
        text, meta = self._finish_word_and_meta(sealed)
        w = self.wager
        if w:
            winner_key = sealed.user_key
            loser_key = w.key_b if winner_key == w.key_a else w.key_a
            ow = self.players.get(loser_key)
            meta["wager_settlement"] = {
                "winner_key": winner_key,
                "loser_key": loser_key,
                "amount": w.amount,
                "winner_name": sealed.display_name,
                "loser_name": ow.display_name if ow else loser_key,
            }
            self._clear_wager_inner()
        return text, meta

    def viewer_session_points(self, user_key: str, fallback_name: str) -> tuple[str, int]:
        """Session score for overlays (!points); does not create a player row."""
        p = self.players.get(user_key)
        if p is None:
            return (fallback_name, 0)
        return (p.display_name, p.score)

    def mask(self) -> str:
        words = self.secret.split(" ")
        parts: list[str] = []
        for w in words:
            parts.append(" ".join(c if c in self.guessed_letters else "_" for c in w))
        return "  |  ".join(parts)

    def is_solved(self) -> bool:
        return all(c in self.guessed_letters for c in self.secret if c.isalpha())

    def queue_ignore_next_round(self, victim_user_key: str) -> None:
        """After a Cap gift, the chosen user cannot play the next word (only)."""
        if victim_user_key:
            self.queued_round_ignore.add(victim_user_key)

    def _append_round_just_completed(self) -> None:
        """Call when the current word is solved (before the next word is chosen)."""
        self._recent_completed_rounds.append((self.secret, time.monotonic()))

    def _update_personal_word_streaks(self, sealed_user_key: str) -> None:
        """Sealer +1 streak; every other tracked player drops to 0."""
        sealed: Optional[PlayerState] = None
        for p in self.players.values():
            if p.user_key == sealed_user_key:
                p.word_solve_streak += 1
                sealed = p
            else:
                p.word_solve_streak = 0
        if sealed is not None and sealed.user_key:
            record_word_streak_peak(
                sealed.user_key,
                sealed.display_name,
                sealed.word_solve_streak,
                self._alltime_path(),
            )
            batch = [(p.user_key, p.display_name, p.word_solve_streak) for p in self.players.values()]
            persist_word_solve_streak_currents_batch(batch, self._alltime_path())

    def _clear_all_personal_word_streaks(self) -> None:
        batch: list[tuple[str, str, int]] = []
        for p in self.players.values():
            p.word_solve_streak = 0
            batch.append((p.user_key, p.display_name, 0))
        if batch:
            persist_word_solve_streak_currents_batch(batch, self._alltime_path())

    def _late_word_same_time_race(self, normalized_guess: str) -> bool:
        """
        True only if this guess equals the *immediately previous* completed answer (within grace
        seconds). Broader matching wrongly skipped penalties for genuine wrong !word guesses.
        """
        if normalized_guess == self.secret:
            return False
        if not self._recent_completed_rounds:
            return False
        secret, t = self._recent_completed_rounds[-1]
        if time.monotonic() - t > _late_word_grace_seconds():
            return False
        return normalized_guess == secret

    def process_guess(self, user_key: str, display_name: str, letter: str) -> tuple[str, bool, Optional[dict[str, Any]]]:
        """
        Returns (message, word_just_completed, round_popup_or_none).
        round_popup is sent to the web UI when the word is solved (correct answer, MVP, finisher).
        """
        letter = letter.upper()
        if len(letter) != 1 or not letter.isalpha():
            return "", False, None

        if user_key in self.active_round_ignore:
            return (
                f"@{display_name}: you're sidelined this word (Cap) — try again next round.",
                False,
                None,
            )

        if self.wager and user_key not in (self.wager.key_a, self.wager.key_b):
            return self._wager_spectator_reply(display_name)

        p = self._player(user_key, display_name)
        lim = self._effective_wrong_limit(p)
        if p.eliminated_this_word:
            return (
                f"@{p.display_name}: you are out for this word ({lim} wrong guesses).",
                False,
                None,
            )

        if letter in self.guessed_letters:
            return f"@{p.display_name}: '{letter}' was already guessed — no change.", False, None

        if letter in self.secret:
            self.guessed_letters.add(letter)
            p.score += POINTS_CORRECT
            self._notify_delta(p, POINTS_CORRECT)
            p.correct_guesses_this_word += 1
            msg = (
                f"@{p.display_name}: '{letter}' is correct! +{POINTS_CORRECT} pts "
                f"(total {p.score}). Word: {self.mask()}"
            )
            if self.is_solved():
                self._append_round_just_completed()
                finish_text, round_popup = self._finalize_solved_word(p)
                msg += "\n" + finish_text
                return msg, True, round_popup
            return msg, False, None

        # Wrong letter
        self.guessed_letters.add(letter)
        if self._has_wrong_penalty_protection(p):
            penalty = 0
        else:
            penalty = POINTS_WRONG
        p.score += penalty
        self._notify_delta(p, penalty)
        p.incorrect_this_word += 1
        lim = self._effective_wrong_limit(p)
        if penalty < 0:
            msg = (
                f"@{p.display_name}: '{letter}' is not in the word. {POINTS_WRONG} pts "
                f"(total {p.score}). Wrong this word: {p.incorrect_this_word}/{lim}."
            )
        else:
            msg = (
                f"@{p.display_name}: '{letter}' is not in the word. No point loss (Money Gun active). "
                f"Total {p.score}. Wrong this word: {p.incorrect_this_word}/{lim}."
            )
        if p.incorrect_this_word >= lim:
            p.eliminated_this_word = True
            msg += " You're out for this word."
            extra, draw_popup = self._wager_after_both_eliminated()
            msg += extra
            if draw_popup is not None:
                return msg, False, draw_popup
        return msg, False, None

    def process_full_word_guess(
        self, user_key: str, display_name: str, phrase: str
    ) -> tuple[str, bool, Optional[dict[str, Any]]]:
        """
        Full-phrase guess (!word PHRASE or !PHRASE). Scoring scales with how much was still hidden.
        Wrong guesses apply POINTS_WRONG × letter count (minimum one letter) to session score; during a wager,
        all-time is not reduced for the two duelists on wrong guesses so the agreed stake can still settle.
        Returns (message, word_just_completed, round_popup_or_none).
        """
        if self.is_solved():
            return "The word is already fully revealed.", False, None

        try:
            g = normalize_secret(phrase)
        except ValueError as e:
            return f"@{display_name}: {e}", False, None

        if user_key in self.active_round_ignore:
            return (
                f"@{display_name}: you're sidelined this word (Cap) — try again next round.",
                False,
                None,
            )

        if self.wager and user_key not in (self.wager.key_a, self.wager.key_b):
            return self._wager_spectator_reply(display_name)

        p = self._player(user_key, display_name)
        lim = self._effective_wrong_limit(p)
        if p.eliminated_this_word:
            return (
                f"@{p.display_name}: you are out for this word ({lim} wrong guesses).",
                False,
                None,
            )

        if g != self.secret:
            if self._late_word_same_time_race(g):
                return (
                    f"@{display_name}: that was the answer, but someone just solved it — no penalty "
                    f"(same-time guess).",
                    False,
                    None,
                )
            n_letters_in_guess = max(1, sum(1 for c in g if c.isalpha()))
            if self._has_wrong_penalty_protection(p):
                penalty = 0
            else:
                penalty = POINTS_WRONG * n_letters_in_guess
            p.score += penalty
            self._notify_delta(p, int(penalty))
            p.incorrect_this_word += 1
            if penalty < 0:
                msg = (
                    f"@{p.display_name}: that's not the full phrase. {penalty} pts "
                    f"(-{abs(POINTS_WRONG)} per letter in your guess, {n_letters_in_guess} letters). "
                    f"Total {p.score}. Wrong this word: {p.incorrect_this_word}/{lim}."
                )
            else:
                msg = (
                    f"@{p.display_name}: that's not the full phrase. No point loss "
                    f"(Money Gun active, {n_letters_in_guess} letters in guess). "
                    f"Total {p.score}. Wrong this word: {p.incorrect_this_word}/{lim}."
                )
            if p.incorrect_this_word >= lim:
                p.eliminated_this_word = True
                msg += " You're out for this word."
                extra, draw_popup = self._wager_after_both_eliminated()
                msg += extra
                if draw_popup is not None:
                    return msg, False, draw_popup
            return msg, False, None

        guessed_before = set(self.guessed_letters)
        award, reveal_ratio, hidden_ratio = whole_word_award_points(self.secret, guessed_before)
        pct_hidden = int(round(hidden_ratio * 100))
        pct_shown = int(round(reveal_ratio * 100))

        for c in self.secret:
            if c.isalpha():
                self.guessed_letters.add(c)

        secret_letters = {c for c in self.secret if c.isalpha()}
        newly_revealed = secret_letters - guessed_before
        p.correct_guesses_this_word += len(newly_revealed)

        p.score += award
        self._notify_delta(p, award)

        msg = (
            f"@{p.display_name}: whole phrase correct! +{award} pts "
            f"({pct_hidden}% of letter slots still hidden, {pct_shown}% already shown). "
            f"Total: {p.score}. Answer: {self.secret.replace(' ', ' · ')}"
        )
        finish_text, meta = self._finalize_solved_word(p)
        meta["whole_word_solve"] = True
        meta["whole_word_points"] = award
        meta["hidden_pct_before"] = pct_hidden
        meta["shown_pct_before"] = pct_shown
        msg += "\n" + finish_text
        self._append_round_just_completed()
        return msg, True, meta

    def _finish_word_and_meta(self, sealed: PlayerState) -> tuple[str, dict[str, Any]]:
        self.win_streak += 1
        self._update_personal_word_streaks(sealed.user_key)
        bonus_lines, winners = self._apply_round_bonus()
        text = "\n".join(["Word solved!"] + bonus_lines)
        display = self.secret.replace(" ", " · ")
        meta: dict[str, Any] = {
            "word": self.secret,
            "display_word": display,
            "mvps": [{"user_key": p.user_key, "name": p.display_name} for p in winners],
            "sealed_by": {"user_key": sealed.user_key, "name": sealed.display_name},
            "duration_ms": 4500,
        }
        return text, meta

    def _apply_round_bonus(self) -> tuple[list[str], list[PlayerState]]:
        """+50 to everyone tied for the most correct guesses this word."""
        if not self.players:
            return (["No players — no MVP bonus."], [])
        best = max(p.correct_guesses_this_word for p in self.players.values())
        if best == 0:
            return (["No one scored a correct letter this word — no MVP bonus."], [])
        winners = [p for p in self.players.values() if p.correct_guesses_this_word == best]
        for p in winners:
            p.score += BONUS_MOST_CORRECT_IN_WORD
            self._notify_delta(p, BONUS_MOST_CORRECT_IN_WORD)
        names = ", ".join(f"@{p.display_name}" for p in winners)
        lines = [
            f"MVP bonus (+{BONUS_MOST_CORRECT_IN_WORD} each): {names} "
            f"with {best} correct letter guess(es) this word."
        ]
        return (lines, winners)

    def end_word_unsolved(self) -> str:
        """Force end (e.g. new word); still award MVP bonus for guesses so far."""
        self.cancel_wager()
        self.win_streak = 0
        self._clear_all_personal_word_streaks()
        bonus_lines, _ = self._apply_round_bonus()
        parts = [f"Round ended. The word was: {self.secret}"] + bonus_lines
        return "\n".join(parts)

    def new_word(self, word: str) -> None:
        self._clear_wager_inner()
        w = normalize_secret(word)
        self.secret = w
        self.guessed_letters.clear()
        # Cap gift: anyone queued is sidelined for this word only; previous sideline list clears.
        self.active_round_ignore = set(self.queued_round_ignore)
        self.queued_round_ignore.clear()
        for p in self.players.values():
            p.incorrect_this_word = 0
            p.correct_guesses_this_word = 0
            p.eliminated_this_word = False
            p.wager_wrong_cap = None
            if p.money_gun_rounds_left > 0:
                p.money_gun_rounds_left = max(0, int(p.money_gun_rounds_left) - 1)
        if self.on_answer_changed:
            self.on_answer_changed(w)
        self.recent_secrets.append(w)
        self.rosa_hint_used_this_word = False
        self.word_theme = word_theme_label(w)
        self.round_id += 1

    def random_new_word(self, bank: Optional[list[str]] = None) -> str:
        bank = bank or DEFAULT_WORDS
        normalized: list[str] = []
        for raw in bank:
            try:
                normalized.append(normalize_secret(raw))
            except ValueError:
                continue
        if not normalized:
            raise ValueError("Word bank has no valid entries.")
        recent = set(self.recent_secrets)
        candidates = [w for w in normalized if w not in recent]
        if not candidates:
            candidates = [w for w in normalized if w != self.secret]
        if not candidates:
            candidates = normalized
        w = get_word_choice_rng().choice(candidates)
        self.new_word(w)
        return w

    def reset_session_scores(self) -> None:
        """Zero everyone’s session points; does not change the current word, streaks, or all-time totals."""
        for p in self.players.values():
            p.score = 0
        self.win_streak = 0

    def try_rosa_hint_popup(self) -> Optional[dict[str, Any]]:
        """
        One hint per word: resets on new_word(). Extra Rosa gifts in the same round do nothing.
        Returns UI payload or None if the word is solved or a hint was already shown this round.
        """
        if self.is_solved():
            return None
        if self.rosa_hint_used_this_word:
            return None
        self.rosa_hint_used_this_word = True
        hint = rosa_hint_text(self.secret, self.guessed_letters)
        return {"hint": hint, "duration_ms": 7500}

    def leaderboard_line(self, top: int = 10) -> str:
        ranked = sorted(self.players.values(), key=lambda p: p.score, reverse=True)[:top]
        if not ranked:
            return "Leaderboard: (no players yet)"
        rows = [f"{i + 1}. {p.display_name}: {p.score} pts" for i, p in enumerate(ranked)]
        return "Leaderboard:\n" + "\n".join(rows)

    def snapshot(self, top: int = 10) -> dict:
        """JSON-serializable state for the browser UI (does not expose the secret word)."""
        # `top` only limits the leaderboard strip in the UI; all players remain in `self.players` for guesses.
        ranked = sorted(self.players.values(), key=lambda p: p.score, reverse=True)[:top]
        secret_letters = {c for c in self.secret if c.isalpha()}
        guessed = self.guessed_letters
        correct_keys = sorted(guessed & secret_letters)
        wrong_keys = sorted(guessed - secret_letters)
        wager_snap: Optional[dict[str, Any]] = None
        if self.wager:
            wg = self.wager
            wager_snap = {
                "key_a": wg.key_a,
                "key_b": wg.key_b,
                "name_a": wg.name_a,
                "name_b": wg.name_b,
                "amount": wg.amount,
            }
        return {
            "mask": self.mask(),
            "length": sum(1 for c in self.secret if c != " "),
            "word_theme": self.word_theme,
            "win_streak": self.win_streak,
            "wager": wager_snap,
            "slots": [
                (c if c in self.guessed_letters else None) if c != " " else " "
                for c in self.secret
            ],
            "guessed_letters": sorted(self.guessed_letters),
            "keyboard": {"correct": correct_keys, "wrong": wrong_keys},
            "players": [
                {
                    "name": p.display_name,
                    "user_key": p.user_key,
                    "score": p.score,
                    "wrong": p.incorrect_this_word,
                    "out": p.eliminated_this_word,
                    "word_solve_streak": p.word_solve_streak,
                }
                for p in ranked
            ],
        }


def parse_host_command(text: str) -> Optional[tuple[str, str]]:
    """
    Returns (command, arg) for lines starting with !, e.g. !setword HELLO -> ('setword', 'HELLO').
    """
    t = text.strip()
    if not t.startswith("!"):
        return None
    parts = t[1:].split(maxsplit=1)
    cmd = parts[0].lower()
    arg = parts[1].strip() if len(parts) > 1 else ""
    return cmd, arg
