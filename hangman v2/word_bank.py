"""
Word bank for Hangman: large file when present (~20k wordfreq-based English + UK/US curated
phrases, family-filtered at build time), else embedded UK fallback.

Person given names are removed at load time (see name_filter.py and data/person_names_*.txt).

Each server process increments data/word_bank_run_id.txt and shuffles the bank with that id
so the order of picks (including the first ~500 rounds) differs across restarts for many sessions.
Override path with HANGMAN_WORD_BANK_PATH.
"""
from __future__ import annotations

import os
import random
from pathlib import Path

try:
    from name_filter import should_exclude_wordlist_entry
except ImportError:
    def should_exclude_wordlist_entry(line: str) -> bool:
        return False

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
LARGE_BANK = DATA / "hangman_word_bank_large.txt"
RUN_ID_FILE = DATA / "word_bank_run_id.txt"

UK_WORDS_AND_PHRASES: list[str] = [
    # ~10 letters (or 9–11)
    "BIRMINGHAM",
    "EDINBURGH",
    "MANCHESTER",
    "YORKSHIRE",
    "STRAWBERRY",
    "BLACKPOOL",
    "BRIGHTON",
    "GREENWICH",
    "WIMBLEDON",
    "CRICKETERS",
    "FOOTBALLER",
    "MARMALADE",
    "PARLIAMENT",
    "WESTMINSTER",
    "BUCKINGHAM",
    "STONEHENGE",
    "DOUBLEDECKER",
    "UNDERGROUND",
    "QUEUING",
    "AUBERGINE",
    "COURGETTE",
    "CORIANDER",
    "GOBSMACKED",
    "KNACKERED",
    "ROUNDABOUT",
    "MOTORWAY",
    "FOLKESTONE",
    "NOTTINGHAM",
    "LEICESTER",
    "LONDONEYE",
    "HADRIANS WALL",
    "CORPORATION",
    # shorter UK-flavoured words
    "LORRY",
    "BISCUIT",
    "CRISPS",
    "CHIPS",
    "CHEEKY",
    "CHUFFED",
    "PECKISH",
    "SKINT",
    "TAKEAWAY",
    "PAVEMENT",
    "TRAINERS",
    "JUMPER",
    "TROUSERS",
    "BRILLIANT",
    "MATE",
    "CHEERS",
    "CODSWALLOP",
    "BLOKE",
    "PLONKER",
    "BOBBY",
    "PETROL",
    "BANGERS",
    "MASH",
    "EALING",
    "OXFORD",
    "CAMBRIDGE",
    "BRISTOL",
    "CARDIFF",
    "NEWCASTLE",
    "LIVERPOOL",
    "SHEFFIELD",
    "NORWICH",
    "PLYMOUTH",
    "ABERDEEN",
    "INVERNESS",
    "BELFAST",
    "LONDON",
    "THAMES",
    "BIGBEN",
    "TUBE",
    "BEEFEATER",
    "HAGGIS",
    "NEEPS",
    "TATTIES",
    "ELEVENSES",
    "CUSTARD",
    "FLAPJACK",
    "POSTBOX",
    "QUEUE",
    "BROLLY",
    "WELLIES",
    "DRIZZLE",
    "GREY",
    "SORRY",
    # phrases
    "CUP OF TEA",
    "NICE ONE",
    "MIND THE GAP",
    "FULL ENGLISH",
    "FISH AND CHIPS",
    "BANGERS AND MASH",
    "TOAD IN THE HOLE",
    "SPOTTED DICK",
    "YORKSHIRE PUDDING",
    "RED PHONE BOX",
    "DOUBLE DECKER BUS",
    "GOD SAVE THE KING",
    "BRITISH SUMMER",
    "BOBS YOUR UNCLE",
    "CHIN UP",
    "KEEP CALM",
    "HOUSES OF PARLIAMENT",
    "RIVER THAMES",
    "SCOTTISH HIGHLANDS",
    "BITS AND BOBS",
    "JAMMIE DODGER",
    "IRN BRU",
    "CLOTTED CREAM",
    "SUNDAY ROAST",
    "STIFF UPPER LIP",
]

WORD_SESSION_RUN_ID: int = 0
_word_choice_rng: random.Random | None = None


def get_word_pick_seed() -> int:
    """Monotonic-ish id for this process (from disk); used to shuffle the bank and seed word RNG."""
    return WORD_SESSION_RUN_ID


def get_word_choice_rng() -> random.Random:
    """Per-process RNG for picking words so order differs each server restart."""
    global _word_choice_rng
    if _word_choice_rng is None:
        _word_choice_rng = random.Random(WORD_SESSION_RUN_ID)
    return _word_choice_rng


def _read_run_id() -> int:
    try:
        return int(RUN_ID_FILE.read_text(encoding="utf-8").strip())
    except Exception:
        return 0


def _write_run_id(n: int) -> None:
    RUN_ID_FILE.parent.mkdir(parents=True, exist_ok=True)
    RUN_ID_FILE.write_text(str(n), encoding="utf-8")


def _load_lines_from_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    return [ln.strip() for ln in text.splitlines() if ln.strip()]


def _embedded_fallback_lines() -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for _w in UK_WORDS_AND_PHRASES:
        u = _w.strip().upper()
        if u and u not in seen and not should_exclude_wordlist_entry(u):
            seen.add(u)
            out.append(u)
    return out


def _bootstrap() -> list[str]:
    global WORD_SESSION_RUN_ID
    WORD_SESSION_RUN_ID = _read_run_id() + 1
    _write_run_id(WORD_SESSION_RUN_ID)

    env_path = os.environ.get("HANGMAN_WORD_BANK_PATH", "").strip()
    path = Path(env_path) if env_path else LARGE_BANK
    if env_path and not path.is_file():
        path = LARGE_BANK

    lines: list[str] = []
    if path.is_file() and path.stat().st_size > 0:
        lines = _load_lines_from_file(path)
    else:
        lines = _embedded_fallback_lines()

    seen: set[str] = set()
    uniq: list[str] = []
    for ln in lines:
        u = ln.strip().upper()
        if u and u not in seen:
            seen.add(u)
            uniq.append(u)

    uniq = [u for u in uniq if not should_exclude_wordlist_entry(u)]

    rng = random.Random(WORD_SESSION_RUN_ID)
    rng.shuffle(uniq)
    return uniq


UK_WORDS: list[str] = _bootstrap()
