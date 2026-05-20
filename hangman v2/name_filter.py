"""
Exclude person given names from Hangman word-bank picks.

Loads:
  data/person_names_first_dominictarr.txt — broad first-name variants (dominictarr/random-name).
  data/person_names_us_common_supplement.txt — common US-style names underrepresented there (e.g. JOHN, JAMES).
  data/person_names_homograph_allow.txt — tokens that are also normal words/places (keep in bank).

A phrase is excluded only if every word looks like a name token (e.g. JOHN PAUL), so
\"VICTORIA SPONGE\" and \"WHITE HOUSE\" stay.
"""
from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"

_NAME_FILES = (
    "person_names_first_dominictarr.txt",
    "person_names_us_common_supplement.txt",
)
_HOMOGRAPH = "person_names_homograph_allow.txt"

_TOKEN_RE = re.compile(r"^[A-Za-z][A-Za-z\-']*$")


def _normalize_name_line(raw: str) -> str | None:
    w = raw.strip()
    if not w or w.startswith("#"):
        return None
    if not _TOKEN_RE.match(w):
        return None
    return w.upper()


@lru_cache(maxsize=1)
def person_name_tokens() -> frozenset[str]:
    names: set[str] = set()
    for fname in _NAME_FILES:
        path = DATA / fname
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for line in text.splitlines():
            n = _normalize_name_line(line)
            if n:
                names.add(n)
    return frozenset(names)


@lru_cache(maxsize=1)
def homograph_allow_tokens() -> frozenset[str]:
    path = DATA / _HOMOGRAPH
    out: set[str] = set()
    if not path.is_file():
        return frozenset()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        s = re.sub(r"[^A-Za-z]", "", s)
        if len(s) >= 2:
            out.add(s.upper())
    return frozenset(out)


def token_is_person_name(token: str) -> bool:
    t = token.strip().upper()
    if not t or not t.isalpha():
        return False
    if t in homograph_allow_tokens():
        return False
    return t in person_name_tokens()


def normalize_wordlist_key(line: str) -> str | None:
    s = (line or "").strip().upper()
    s = re.sub(r"[^A-Z\s]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    if not s or not any(c.isalpha() for c in s):
        return None
    return s


def should_exclude_wordlist_entry(line: str) -> bool:
    """True if this bank line is only person-name material and should be dropped."""
    key = normalize_wordlist_key(line)
    if not key:
        return False
    parts = key.split()
    if len(parts) == 1:
        return token_is_person_name(parts[0])
    return all(token_is_person_name(t) for t in parts)
