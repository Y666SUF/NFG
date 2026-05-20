"""Normalize TikTok handles and names so keys and lookups survive invisible / odd Unicode."""
from __future__ import annotations

import unicodedata

# Safe to strip from display names (does not break ZWJ emoji sequences).
_DISPLAY_DISRUPTIVE: tuple[str, ...] = (
    "\u200b",  # ZWSP
    "\u200e",  # LRM
    "\u200f",  # RLM
    "\u2028",
    "\u2029",
    "\u2060",  # word joiner
    "\u2066",
    "\u2067",
    "\u2068",
    "\u2069",
    "\ufeff",
)

# Also strip ZWNJ/ZWJ and generic format chars from machine identifiers only.
_MACHINE_EXTRA: tuple[str, ...] = ("\u200c", "\u200d")


def _strip_chars(s: str, chars: tuple[str, ...]) -> str:
    for ch in chars:
        s = s.replace(ch, "")
    return s


def _strip_format_chars(s: str) -> str:
    out: list[str] = []
    for ch in s:
        if unicodedata.category(ch) == "Cf":
            continue
        out.append(ch)
    return "".join(out)


def normalize_display_name(s: str) -> str:
    """Trim + NFC + remove bidi / BOM / ZWSP; keeps ZWJ so emoji ligatures stay intact."""
    t = (s or "").strip()
    t = _strip_chars(t, _DISPLAY_DISRUPTIVE)
    return unicodedata.normalize("NFC", t).strip()


def normalize_tiktok_user_key(s: str) -> str:
    """NFKC + strip invisible/format for @username, id_str, sec_uid fragments."""
    t = (s or "").strip()
    t = _strip_chars(t, _DISPLAY_DISRUPTIVE + _MACHINE_EXTRA)
    t = _strip_format_chars(t)
    t = unicodedata.normalize("NFKC", t)
    return t.strip()


def normalize_lookup_token(s: str) -> str:
    """Case-insensitive match token (handles, stored names, cap targets)."""
    return normalize_tiktok_user_key(s).lower().lstrip("@")


def normalize_chat_for_letter_parse(text: str) -> str:
    """Strip junk that sometimes prefixes TikTok comment bodies before letter extraction."""
    t = (text or "").strip()
    t = _strip_chars(t, _DISPLAY_DISRUPTIVE + _MACHINE_EXTRA)
    t = _strip_format_chars(t)
    return unicodedata.normalize("NFKC", t).strip()
