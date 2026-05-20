"""
Galaxy steal protection after TikTok Racing Debut gift: per-user wall-clock expiry on disk.
"""
from __future__ import annotations

import json
import os
import threading
import time
from pathlib import Path
from typing import Any

_lock = threading.Lock()


def default_shield_path() -> Path:
    return Path(__file__).resolve().parent / "data" / "racing_debut_shield.json"


def default_drop_grace_path() -> Path:
    """After a Car Drifting trim fully removes someone's shield: short window before Galaxy steals work again."""
    return Path(__file__).resolve().parent / "data" / "shield_drop_grace.json"


def shield_drop_grace_duration_sec() -> float:
    try:
        s = float(os.environ.get("HANGMAN_SHIELD_DROP_GRACE_SEC", "300").strip())
    except ValueError:
        s = 300.0
    return max(1.0, s)


def shield_duration_sec() -> float:
    try:
        h = float(os.environ.get("HANGMAN_RACING_DEBUT_SHIELD_HOURS", "48").strip())
    except ValueError:
        h = 48.0
    return max(1.0, h) * 3600.0


def _load(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def _save(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    text = json.dumps(data, indent=0, ensure_ascii=False)
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    tmp.replace(path)


def _prune(data: dict[str, float], now: float) -> dict[str, float]:
    return {k: v for k, v in data.items() if isinstance(v, (int, float)) and float(v) > now}


def grant_shield(user_key: str, path: Path | None = None) -> float:
    """
    Racing Debut / shield grant: if this user already has an unexpired shield, add ``shield_duration_sec()``
    onto that expiry (stacking). If not (or stored expiry is in the past), protection runs from now for one duration.
    Clears any post-trim steal grace for this user (they sent Racing Debut again).
    Returns new expiry unix time.
    """
    if not user_key:
        return 0.0
    path = path or default_shield_path()
    grace_path = default_drop_grace_path()
    now = time.time()
    dur = shield_duration_sec()
    with _lock:
        data = _load(path)
        raw = {k: float(v) for k, v in data.items() if isinstance(v, (int, float))}
        cur = raw.get(user_key, 0.0)
        if float(cur) > now:
            new_exp = float(cur) + dur
        else:
            new_exp = now + dur
        raw[user_key] = new_exp
        raw = _prune(raw, now)
        _save(path, raw)
        graw = {k: float(v) for k, v in _load(grace_path).items() if isinstance(v, (int, float))}
        if user_key in graw:
            graw.pop(user_key, None)
            _save(grace_path, _prune(graw, now))
    return new_exp


def start_shield_drop_grace(user_key: str, grace_path: Path | None = None) -> float:
    """
    When Racing Debut shield is fully removed by Car Drifting: victim has this long to send Racing Debut;
    Galaxy steals from them are blocked until grace ends or they grant a new shield.
    Returns grace end unix time.
    """
    if not user_key:
        return 0.0
    grace_path = grace_path or default_drop_grace_path()
    now = time.time()
    until = now + shield_drop_grace_duration_sec()
    with _lock:
        raw = {k: float(v) for k, v in _load(grace_path).items() if isinstance(v, (int, float))}
        raw = _prune(raw, now)
        raw[user_key] = until
        _save(grace_path, raw)
    return until


def shield_drop_grace_until(user_key: str, grace_path: Path | None = None) -> float | None:
    if not user_key:
        return None
    grace_path = grace_path or default_drop_grace_path()
    now = time.time()
    with _lock:
        raw = {k: float(v) for k, v in _load(grace_path).items() if isinstance(v, (int, float))}
        pruned = _prune(raw, now)
        if len(pruned) != len(raw):
            _save(grace_path, pruned)
            raw = pruned
        exp = raw.get(user_key)
    if exp is None:
        return None
    exp = float(exp)
    return exp if exp > now else None


def is_shield_drop_grace_active(user_key: str, grace_path: Path | None = None) -> bool:
    return shield_drop_grace_until(user_key, grace_path) is not None


def list_shield_drop_grace_expirations(grace_path: Path | None = None) -> list[tuple[str, float]]:
    """Active (user_key, grace_until_unix) sorted by grace_until ascending."""
    grace_path = grace_path or default_drop_grace_path()
    now = time.time()
    with _lock:
        raw = {k: float(v) for k, v in _load(grace_path).items() if isinstance(v, (int, float))}
        pruned = _prune(raw, now)
        if len(pruned) != len(raw):
            _save(grace_path, pruned)
            raw = pruned
    return sorted(((k, float(v)) for k, v in raw.items()), key=lambda x: x[1])


def shield_expiry_unix(user_key: str, path: Path | None = None) -> float | None:
    """Unix time when protection ends, or None if not protected."""
    if not user_key:
        return None
    path = path or default_shield_path()
    now = time.time()
    with _lock:
        raw = {k: float(v) for k, v in _load(path).items() if isinstance(v, (int, float))}
        pruned = _prune(raw, now)
        if len(pruned) != len(raw):
            _save(path, pruned)
            raw = pruned
        exp = raw.get(user_key)
    if exp is None:
        return None
    exp = float(exp)
    return exp if exp > now else None


def is_protected(user_key: str, path: Path | None = None) -> bool:
    return shield_expiry_unix(user_key, path) is not None


def trim_shield_by_hours(victim_key: str, hours: float, path: Path | None = None) -> tuple[str, float | None]:
    """
    Subtract wall-clock time from the victim's Racing Debut shield expiry.
    Returns (outcome, new_expiry_unix_or_None).
    outcome: no_shield | removed | shortened
    """
    if not victim_key:
        return ("no_shield", None)
    path = path or default_shield_path()
    now = time.time()
    sec = max(0.0, float(hours)) * 3600.0
    with _lock:
        data = _load(path)
        raw = {k: float(v) for k, v in data.items() if isinstance(v, (int, float))}
        exp = raw.get(victim_key)
        if exp is None or float(exp) <= now:
            return ("no_shield", None)
        new_exp = float(exp) - sec
        if new_exp <= now:
            raw.pop(victim_key, None)
            raw = _prune(raw, now)
            _save(path, raw)
            return ("removed", None)
        raw[victim_key] = new_exp
        raw = _prune(raw, now)
        _save(path, raw)
        return ("shortened", new_exp)
