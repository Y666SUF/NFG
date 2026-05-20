"""
Build data/hangman_word_bank_large.txt (~20k lines): realistic English vocabulary for Hangman.

Uses **wordfreq** (large English wordlist + Zipf frequencies from mixed corpora including
SUBTLEX-UK data — not subtitle token dumps, so far fewer random names / OCR artefacts than
FrequencyWords en_full). Tokens must also appear in the public-domain **words_alpha** list
(dwyl/english-words) so acronyms and stray tokens are dropped.

**UK lean:** merges data/us_spelling_blocklist.txt to drop common American-only spellings
where British alternatives exist in the corpus (colour, theatre, etc.). This is **not** the
Oxford University Press dictionary text (that material is not redistributable here); it is
standard open frequency data suitable for classroom-style word games.

**Family-safe:** merges LDNOOBW English blocklist + data/word_filter_blocklist.txt.

  py -m pip install wordfreq
  py scripts/build_large_word_bank.py

Offline: after `pip install wordfreq`, place `data/words_alpha.txt` (from dwyl english-words)
to avoid downloading it once. The LDNOOBW blocklist still needs network unless you paste it locally.
"""
from __future__ import annotations

import random
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

sys.path.insert(0, str(ROOT))
from name_filter import should_exclude_wordlist_entry  # noqa: E402
OUT = DATA / "hangman_word_bank_large.txt"
CURATED_UK = DATA / "uk_curated.txt"
CURATED_US = DATA / "us_curated.txt"
LOCAL_BLOCKLIST = DATA / "word_filter_blocklist.txt"
US_SPELLING_BLOCK = DATA / "us_spelling_blocklist.txt"
# Public-domain alphabetic dictionary (filters acronyms / junk; not OUP-specific).
WORDS_ALPHA_URL = (
    "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"
)
LOCAL_WORDS_ALPHA = DATA / "words_alpha.txt"

LDNOOBW_EN_URL = (
    "https://raw.githubusercontent.com/LDNOOBW/"
    "List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/en"
)

TARGET_LINES = 20_000
MIN_LEN = 3
MAX_LEN = 22
MAX_PHRASE_WORDS = 5

# Keep mostly dictionary-like tokens: drop ultra-rare noise and extremely common grammar words.
ZIPF_MIN = 2.88
ZIPF_MAX = 6.06

# Soft caps on -ly / -ed among frequency-sourced words (curated phrases exempt).
MAX_LY_RATIO = 0.065
MAX_ED_RATIO = 0.11
MIN_WORD_LEN_FOR_SUFFIX_RULE = 5

FREQ_SCAN_CAP = 350_000


def _normalize_token_line(s: str) -> str | None:
    s = (s or "").strip().upper()
    s = re.sub(r"[^A-Z\s]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    if not s or not any(c.isalpha() for c in s):
        return None
    n = sum(1 for c in s if c.isalpha())
    if n < MIN_LEN or n > MAX_LEN:
        return None
    if len(s.split()) > MAX_PHRASE_WORDS:
        return None
    return s


def _load_curated_paths(paths: list[Path]) -> list[str]:
    lines: list[str] = []
    for path in paths:
        if not path.exists():
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            if raw.strip().startswith("#"):
                continue
            n = _normalize_token_line(raw)
            if n:
                lines.append(n)
    return lines


def _suffix_flags(w: str) -> tuple[bool, bool]:
    if len(w) < MIN_WORD_LEN_FOR_SUFFIX_RULE:
        return False, False
    return w.endswith("LY"), w.endswith("ED")


def _normalize_block_line(raw: str) -> str | None:
    s = (raw or "").strip()
    if not s or s.startswith("#"):
        return None
    if any(c.isdigit() for c in s):
        return None
    s = re.sub(r"[^a-z\s]", "", s.lower())
    s = re.sub(r"\s+", " ", s).strip()
    if len(s) < 2:
        return None
    return s


def _fetch_ldnoobw_blocklist() -> str:
    req = urllib.request.Request(LDNOOBW_EN_URL, headers={"User-Agent": "hangman-word-bank-build/4.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read().decode("utf-8", errors="ignore")


def _build_block_filters(text: str) -> tuple[set[str], set[str]]:
    blocked_words: set[str] = set()
    blocked_phrases: set[str] = set()
    for raw in text.splitlines():
        norm = _normalize_block_line(raw)
        if not norm:
            continue
        parts = norm.split()
        if len(parts) == 1:
            w = parts[0].upper()
            if len(w) >= 3:
                blocked_words.add(w)
        else:
            blocked_phrases.add(" ".join(p.upper() for p in parts))
    return blocked_words, blocked_phrases


def _load_combined_block_filters() -> tuple[set[str], set[str]]:
    chunks: list[str] = []
    try:
        chunks.append(_fetch_ldnoobw_blocklist())
        print("Loaded remote English blocklist (LDNOOBW).")
    except Exception as e:
        print(f"Warning: could not fetch LDNOOBW blocklist: {e}", file=sys.stderr)
    if LOCAL_BLOCKLIST.is_file():
        chunks.append(LOCAL_BLOCKLIST.read_text(encoding="utf-8", errors="ignore"))
        print(f"Merged local {LOCAL_BLOCKLIST.name}.")
    words: set[str] = set()
    phrases: set[str] = set()
    for ch in chunks:
        w, p = _build_block_filters(ch)
        words |= w
        phrases |= p
    print(f"Block filters: {len(words)} single words, {len(phrases)} phrases.")
    return words, phrases


def _load_alpha_dictionary() -> set[str]:
    """Lowercase alphabetic words only (~370k); public domain (dwyl english-words)."""
    if LOCAL_WORDS_ALPHA.is_file():
        print(f"Loading alphabetic dictionary from {LOCAL_WORDS_ALPHA} ...")
        raw = LOCAL_WORDS_ALPHA.read_text(encoding="utf-8", errors="ignore")
        lines = raw.splitlines()
    else:
        print(f"Downloading alphabetic dictionary ({WORDS_ALPHA_URL}) ...")
        req = urllib.request.Request(WORDS_ALPHA_URL, headers={"User-Agent": "hangman-word-bank-build/4.0"})
        with urllib.request.urlopen(req, timeout=300) as r:
            lines = r.read().decode("utf-8", errors="ignore").splitlines()
    out: set[str] = set()
    for line in lines:
        w = line.strip().lower()
        if w.isalpha() and len(w) >= 2:
            out.add(w)
    print(f"Alphabetic dictionary: {len(out)} words.")
    return out


def _load_us_spelling_block() -> set[str]:
    out: set[str] = set()
    if not US_SPELLING_BLOCK.is_file():
        return out
    for raw in US_SPELLING_BLOCK.read_text(encoding="utf-8").splitlines():
        s = (raw or "").strip().lower()
        if not s or s.startswith("#"):
            continue
        s = re.sub(r"[^a-z]", "", s)
        if len(s) >= 2:
            out.add(s.upper())
    print(f"US spelling block (UK lean): {len(out)} types.")
    return out


def _is_blocked_single(w: str, blocked_words: set[str]) -> bool:
    if w in blocked_words:
        return True
    if len(w) >= 4 and w.endswith("S") and w[:-1] in blocked_words:
        return True
    if len(w) >= 5 and w.endswith("ES") and w[:-2] in blocked_words:
        return True
    if len(w) >= 6 and w.endswith("ING") and w[:-3] in blocked_words:
        return True
    if len(w) >= 5 and w.endswith("ED") and w[:-2] in blocked_words:
        return True
    return False


def _is_blocked_entry(
    entry: str,
    blocked_words: set[str],
    blocked_phrases: set[str],
) -> bool:
    if " " in entry:
        e = re.sub(r"\s+", " ", entry.strip()).upper()
        if e in blocked_phrases:
            return True
        for tok in e.split():
            if _is_blocked_single(tok, blocked_words):
                return True
        return False
    return _is_blocked_single(entry.strip().upper(), blocked_words)


def _wordfreq_candidates(
    alpha: set[str],
    us_block: set[str],
    blocked_words: set[str],
    blocked_phrases: set[str],
) -> list[str]:
    from wordfreq import top_n_list, zipf_frequency

    out: list[str] = []
    seen: set[str] = set()
    scanned = 0
    for w in top_n_list("en", FREQ_SCAN_CAP, wordlist="large", ascii_only=True):
        scanned += 1
        wl = w.strip().lower()
        if wl not in alpha:
            continue
        if not wl.isalpha() or not wl.isascii():
            continue
        u = wl.upper()
        if u in us_block:
            continue
        if len(u) < MIN_LEN or len(u) > MAX_LEN:
            continue
        z = zipf_frequency(wl, "en")
        if z < ZIPF_MIN or z >= ZIPF_MAX:
            continue
        if _is_blocked_entry(u, blocked_words, blocked_phrases):
            continue
        if should_exclude_wordlist_entry(u):
            continue
        if u in seen:
            continue
        seen.add(u)
        out.append(u)
    print(f"wordfreq scan: {scanned} tokens -> {len(out)} candidates (Zipf {ZIPF_MIN}–{ZIPF_MAX}).")
    return out


def main() -> int:
    try:
        import wordfreq  # noqa: F401
    except ImportError:
        print("Install wordfreq:  py -m pip install wordfreq", file=sys.stderr)
        return 1

    DATA.mkdir(parents=True, exist_ok=True)
    blocked_words, blocked_phrases = _load_combined_block_filters()
    us_block = _load_us_spelling_block()
    alpha = _load_alpha_dictionary()

    freq_order = _wordfreq_candidates(alpha, us_block, blocked_words, blocked_phrases)
    if len(freq_order) < 16_000:
        print(
            "Too few candidates after filters — widen ZIPF range or check wordfreq install.",
            file=sys.stderr,
        )
        return 1

    seen: set[str] = set()
    merged: list[str] = []
    filtered_curated = 0
    filtered_freq = 0

    for w in _load_curated_paths([CURATED_UK, CURATED_US]):
        if should_exclude_wordlist_entry(w):
            filtered_curated += 1
            continue
        if _is_blocked_entry(w, blocked_words, blocked_phrases):
            filtered_curated += 1
            continue
        if " " not in w:
            parts = w.split()
            if len(parts) == 1 and parts[0] in us_block:
                filtered_curated += 1
                continue
        else:
            skip = False
            for tok in w.split():
                if tok in us_block:
                    skip = True
                    break
            if skip:
                filtered_curated += 1
                continue
        if w not in seen:
            seen.add(w)
            merged.append(w)
        if len(merged) >= TARGET_LINES:
            break

    max_ly = int(TARGET_LINES * MAX_LY_RATIO)
    max_ed = int(TARGET_LINES * MAX_ED_RATIO)
    ly_ct = sum(1 for w in merged if _suffix_flags(w)[0])
    ed_ct = sum(1 for w in merged if _suffix_flags(w)[1])

    for w in freq_order:
        if len(merged) >= TARGET_LINES:
            break
        if w in seen:
            continue
        if _is_blocked_entry(w, blocked_words, blocked_phrases):
            filtered_freq += 1
            continue
        if should_exclude_wordlist_entry(w):
            filtered_freq += 1
            continue
        ly, ed = _suffix_flags(w)
        if ly and ly_ct >= max_ly:
            continue
        if ed and ed_ct >= max_ed:
            continue
        seen.add(w)
        merged.append(w)
        if ly:
            ly_ct += 1
        if ed:
            ed_ct += 1

    for w in freq_order:
        if len(merged) >= TARGET_LINES:
            break
        if w in seen:
            continue
        if _is_blocked_entry(w, blocked_words, blocked_phrases):
            filtered_freq += 1
            continue
        if should_exclude_wordlist_entry(w):
            filtered_freq += 1
            continue
        seen.add(w)
        merged.append(w)

    if len(merged) < TARGET_LINES:
        print(f"Warning: only {len(merged)} unique lines (target {TARGET_LINES}).", file=sys.stderr)

    print(f"Filtered (blocklist): {filtered_freq} frequency words, {filtered_curated} curated lines.")

    rng = random.Random(42)
    rng.shuffle(merged)

    OUT.write_text("\n".join(merged) + "\n", encoding="utf-8")
    print(f"Wrote {len(merged)} lines to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
