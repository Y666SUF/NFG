"""
Build data/hangman_word_bank.txt (~20k lines) for Hangman.

Requires: pip install wordfreq

Uses word frequencies to drop ultra-common/generic tokens, plus data/uk_curated.txt
for spaced phrases (e.g. LONDON EYE). Output order is shuffled so each rebuild differs.

  py scripts/build_word_bank.py
"""
from __future__ import annotations

import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUT = DATA / "hangman_word_bank.txt"
CURATED_IN = DATA / "uk_curated.txt"

# Exclude extremely frequent / generic single words (zipf scale ~0–8; "the" ≈ 7.3).
ZIPF_MAX_SINGLE = 6.12

MIN_LEN = 4
MAX_LEN = 15

# Common English stopwords + very generic gameplay words (lowercase).
_STOPWORDS: set[str] = {
    "that", "this", "with", "have", "from", "they", "been", "were", "said", "each",
    "which", "their", "time", "will", "about", "there", "could", "other", "than",
    "first", "into", "more", "very", "what", "know", "just", "only", "come", "over",
    "think", "also", "back", "after", "well", "work", "great", "year", "good", "some",
    "them", "make", "like", "then", "most", "even", "such", "take", "many", "these",
    "must", "same", "under", "through", "being", "both", "before", "those", "much",
    "where", "while", "should", "between", "never", "another", "might", "every", "against",
    "without", "again", "around", "however", "something", "nothing", "everything",
    "anything", "sometimes", "always", "maybe", "perhaps", "though", "although",
    "because", "either", "neither", "rather", "quite", "really", "still", "already",
    "thing", "things", "stuff", "people", "person", "way", "ways", "day", "days", "part",
    "parts", "place", "places", "case", "cases", "point", "points", "number", "numbers",
    "hand", "hands", "week", "weeks", "month", "months", "life", "world", "fact", "facts",
    "today", "tomorrow", "yesterday", "morning", "night", "home", "house", "room",
    "word", "words", "name", "names", "line", "lines", "end",
    "ends", "left", "right", "next", "last", "long", "little", "large", "small", "young",
    "old", "new", "high", "low", "few", "several", "certain", "sure", "whole", "full",
    "half", "once", "twice", "here", "there", "when", "where", "why", "how", "who",
    "whom", "whose",     "upon", "unto", "thus", "hence",
}


def _normalize_phrase(line: str) -> str | None:
    s = line.strip()
    if not s or s.startswith("#"):
        return None
    s = s.upper()
    s = re.sub(r"[^A-Z\s]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    if not s or not any(c.isalpha() for c in s):
        return None
    letter_count = sum(1 for c in s if c.isalpha())
    if letter_count < 3:
        return None
    return s


def _load_curated() -> list[str]:
    if not CURATED_IN.exists():
        return []
    out: list[str] = []
    seen: set[str] = set()
    for raw in CURATED_IN.read_text(encoding="utf-8").splitlines():
        n = _normalize_phrase(raw)
        if n and n not in seen:
            seen.add(n)
            out.append(n)
    return out


def _build_from_wordfreq(target_count: int) -> list[str]:
    from wordfreq import zipf_frequency, top_n_list

    out: list[str] = []
    seen: set[str] = set()
    for w in top_n_list("en", 600000):
        wl = w.lower()
        if not wl.isalpha():
            continue
        n = len(wl)
        if n < MIN_LEN or n > MAX_LEN:
            continue
        if wl in _STOPWORDS:
            continue
        if zipf_frequency(wl, "en") >= ZIPF_MAX_SINGLE:
            continue
        u = wl.upper()
        if u in seen:
            continue
        seen.add(u)
        out.append(u)
        if len(out) >= target_count:
            break
    return out


def main() -> int:
    try:
        from wordfreq import zipf_frequency  # noqa: F401
    except ImportError:
        print("Install wordfreq:  pip install wordfreq", file=sys.stderr)
        return 1

    DATA.mkdir(parents=True, exist_ok=True)
    curated = _load_curated()
    need = max(0, 20000 - len(curated))
    generated = _build_from_wordfreq(need)

    merged: list[str] = []
    seen: set[str] = set()
    for block in (curated, generated):
        for w in block:
            if w not in seen:
                seen.add(w)
                merged.append(w)

    rng = random.Random()
    rng.shuffle(merged)

    OUT.write_text("\n".join(merged) + "\n", encoding="utf-8")
    print(f"Wrote {len(merged)} entries to {OUT} ({len(curated)} curated + {len(generated)} generated)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
