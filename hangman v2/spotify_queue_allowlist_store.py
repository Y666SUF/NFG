"""Persist which viewer user_keys may use !queue / !song / !addsong besides the broadcaster."""
from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

_lock = threading.Lock()


def load_allowed_keys(path: Path) -> set[str]:
    if not path.exists():
        return set()
    with _lock:
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError):
            return set()
    if not isinstance(data, dict):
        return set()
    raw = data.get("allowed_user_keys")
    if not isinstance(raw, list):
        return set()
    return {str(x).strip() for x in raw if str(x).strip()}


def save_allowed_keys(path: Path, keys: set[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    obj: dict[str, Any] = {"allowed_user_keys": sorted(keys)}
    with _lock:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(obj, f, indent=0, ensure_ascii=False)
        tmp.replace(path)
