"""
Build ``data/word_theme_map.json`` for Hangman: one theme label per bank line.

For each **single** word, fetches **multiple** definition snippets from the Free Dictionary API
(``https://dictionaryapi.dev`` — no API key), joins them, scrubs the headword from the text,
and runs the keyword topic scorer in ``word_topic.py``. More senses → better keyword hits.

**Phrases** skip the network and use the built-in phrase / keyword classifier only.

Optional ``--openai-fallback`` (needs ``HANGMAN_OPENAI_API_KEY`` or ``HANGMAN_WORD_THEME_API_KEY``):
if the keyword path still yields a generic label (Grammar / Length / Dictionary sense / …),
one GPT call is made **using the definition text only** (headword not sent).

Resumable: ``--resume`` keeps existing keys and only fills gaps. ``--force`` recomputes every
word (still merges with ``--resume`` only if you omit ``--force``). Delete the output file for a full rebuild.

Examples (from repo root)::

  py scripts/build_word_themes.py --resume --sleep 0.35
  py scripts/build_word_themes.py --resume --openai-fallback --sleep 0.35

Restart the Hangman server after updating the map. Override path with ``HANGMAN_WORD_THEME_MAP_PATH``.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

try:
    from name_filter import should_exclude_wordlist_entry
except ImportError:

    def should_exclude_wordlist_entry(line: str) -> bool:
        return False


from word_topic import (  # noqa: E402
    _normalize_secret_key,
    theme_for_bank_line_build,
    theme_is_weak_heuristic_label,
)

DATA = ROOT / "data"
DEFAULT_BANK = DATA / "hangman_word_bank_large.txt"
DEFAULT_OUT = DATA / "word_theme_map.json"
_MAX_COMBINED_GLOSS_CHARS = 1500


def load_bank_lines(path: Path) -> list[str]:
    if not path.is_file():
        return []
    text = path.read_text(encoding="utf-8", errors="ignore")
    lines: list[str] = []
    seen: set[str] = set()
    for ln in text.splitlines():
        u = ln.strip().upper()
        if not u or u in seen or should_exclude_wordlist_entry(u):
            continue
        seen.add(u)
        lines.append(u)
    return lines


def _load_existing_themes(out_path: Path) -> dict[str, str]:
    if not out_path.is_file():
        return {}
    try:
        raw = json.loads(out_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}
    if not isinstance(raw, dict):
        return {}
    inner = raw.get("themes") if isinstance(raw.get("themes"), dict) else raw
    if not isinstance(inner, dict):
        return {}
    out: dict[str, str] = {}
    for k, v in inner.items():
        if str(k).startswith("_") or not isinstance(v, str):
            continue
        nk = _normalize_secret_key(str(k))
        vv = v.strip()
        if nk and vv:
            out[nk] = vv
    return out


def fetch_free_dictionary(word_lc: str) -> tuple[str | None, str | None]:
    """
    Return combined definition text from several senses (better for keyword scoring)
    and the part of speech of the first meaning.
    """
    url = f"https://api.dictionaryapi.dev/api/v2/entries/en/{urllib.parse.quote(word_lc)}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "HangmanWordThemes/1.0 (offline word game; educational)"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, json.JSONDecodeError):
        return None, None
    if not isinstance(payload, list) or not payload:
        return None, None
    first = payload[0]
    meanings = first.get("meanings") or []
    if not meanings:
        return None, None

    pos_primary: str | None = None
    chunks: list[str] = []
    for mi, m in enumerate(meanings[:5]):
        if not isinstance(m, dict):
            continue
        if mi == 0:
            p = m.get("partOfSpeech")
            if isinstance(p, str) and p.strip():
                pos_primary = p.strip()
        defs = m.get("definitions") or []
        for d in defs[:2]:
            if not isinstance(d, dict):
                continue
            g = d.get("definition")
            if isinstance(g, str) and (t := g.strip()):
                chunks.append(t)

    if not chunks:
        return None, pos_primary

    combined = " ".join(chunks)
    if len(combined) > _MAX_COMBINED_GLOSS_CHARS:
        combined = combined[: _MAX_COMBINED_GLOSS_CHARS - 3] + "..."
    return combined, pos_primary


def write_themes_json(
    out_path: Path,
    themes: dict[str, str],
    *,
    bank_name: str,
    api_calls: int,
    openai_calls: int,
) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_suffix(out_path.suffix + ".tmp")
    out_obj = {
        "_meta": {
            "source_bank": bank_name,
            "entry_count": len(themes),
            "dictionary_lookups": api_calls,
            "openai_fallback_calls": openai_calls,
        },
        "themes": dict(sorted(themes.items())),
    }
    tmp.write_text(json.dumps(out_obj, indent=0, ensure_ascii=False), encoding="utf-8")
    tmp.replace(out_path)


def main() -> None:
    ap = argparse.ArgumentParser(description="Build word_theme_map.json from word bank + dictionary API")
    ap.add_argument("--bank", type=Path, default=DEFAULT_BANK, help="Word list (one per line, uppercase ok)")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="Output JSON path")
    ap.add_argument("--sleep", type=float, default=0.35, help="Seconds between dictionary API calls")
    ap.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Max dictionary HTTP fetches for single-token lines only (0 = fetch for every word; "
        "phrases never hit the API). After the cap, single words use keyword heuristics only.",
    )
    ap.add_argument(
        "--resume",
        action="store_true",
        help="Keep existing entries in --out and only add missing keys",
    )
    ap.add_argument(
        "--force",
        action="store_true",
        help="Recompute themes for all bank lines (overwrites keys in memory; use without --resume to start from empty map)",
    )
    ap.add_argument(
        "--save-every",
        type=int,
        default=400,
        help="Write JSON after this many new entries (crash safety; 0 = only at end)",
    )
    ap.add_argument(
        "--openai-fallback",
        action="store_true",
        help="If keyword theme is still generic, call OpenAI on definition text only (needs API key)",
    )
    args = ap.parse_args()

    lines = load_bank_lines(args.bank)
    if args.resume and not args.force:
        themes: dict[str, str] = _load_existing_themes(args.out)
    elif args.force:
        themes = {}
        if args.resume:
            print("[warn] --force ignores saved entries; treating theme map as empty", flush=True)
    else:
        themes = {}
    api_calls = 0
    openai_calls = 0
    new_since_save = 0

    print(
        f"[start] bank_lines={len(lines)} existing_themes={len(themes)} resume={args.resume} "
        f"openai_fallback={args.openai_fallback}",
        flush=True,
    )

    for i, line in enumerate(lines):
        key = _normalize_secret_key(line)
        if not key:
            continue
        if not args.force and key in themes:
            continue
        if " " in key:
            themes[key] = theme_for_bank_line_build(line)
        else:
            use_api = args.limit == 0 or api_calls < args.limit
            combined: str | None = None
            pos: str | None = None
            if use_api:
                combined, pos = fetch_free_dictionary(line.strip().lower())
                api_calls += 1
                label = theme_for_bank_line_build(line, definition=combined, part_of_speech=pos)
                if (
                    args.openai_fallback
                    and combined
                    and theme_is_weak_heuristic_label(label)
                ):
                    try:
                        from word_topic_ai import fetch_ai_topic_from_glossary

                        ai_label = fetch_ai_topic_from_glossary(combined, pos)
                        openai_calls += 1
                        if ai_label:
                            label = ai_label
                    except Exception:
                        pass
                themes[key] = label
                if args.sleep > 0:
                    time.sleep(args.sleep)
            else:
                themes[key] = theme_for_bank_line_build(line)

        new_since_save += 1
        se = args.save_every
        if se > 0 and new_since_save >= se:
            write_themes_json(
                args.out,
                themes,
                bank_name=args.bank.name,
                api_calls=api_calls,
                openai_calls=openai_calls,
            )
            print(
                f"[checkpoint] line {i + 1}/{len(lines)} themes={len(themes)} "
                f"dict_lookups={api_calls} openai={openai_calls}",
                flush=True,
            )
            new_since_save = 0

        if (i + 1) % 250 == 0:
            print(
                f"[progress] line {i + 1}/{len(lines)} themes={len(themes)} "
                f"dict_lookups={api_calls} openai={openai_calls}",
                flush=True,
            )

    write_themes_json(
        args.out,
        themes,
        bank_name=args.bank.name,
        api_calls=api_calls,
        openai_calls=openai_calls,
    )
    print(
        f"[done] Wrote {len(themes)} entries to {args.out} "
        f"(dictionary lookups this run: {api_calls}, openai fallback: {openai_calls})",
        flush=True,
    )


if __name__ == "__main__":
    main()
