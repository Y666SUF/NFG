"""
Optional AI-assisted hangman theme labels (category only, no spoilers in intent).

Enable with HANGMAN_OPENAI_API_KEY (or HANGMAN_WORD_THEME_API_KEY). Disable with
HANGMAN_WORD_THEME_AI=0. Optional: HANGMAN_WORD_THEME_AI_MODEL (default gpt-4o-mini),
HANGMAN_WORD_THEME_AI_TIMEOUT (seconds, default 2.5).
"""
from __future__ import annotations

import json
import logging
import os
import re
import urllib.error
import urllib.request
from collections import OrderedDict

logger = logging.getLogger(__name__)

_MAX_TOPIC_LEN = 88
_MAX_CACHE = 2048
# Bump when prompt / acceptance rules change so stale labels are not reused.
_CACHE_KEY_PREFIX = "t2:"
_CACHE: OrderedDict[str, str] = OrderedDict()

# Reject AI lines that read like a generic bucket (heuristics are usually better).
_VAGUE_SUBTYPE = re.compile(
    r"·\s*(general|misc|miscellaneous|various|stuff|things?|objects?|words?|vocabulary|"
    r"concepts?|ideas?|everything|other|common|typical|basic|random|unknown)\s*$",
    re.I,
)
_VAGUE_DOMAIN = re.compile(
    r"^(general|misc|miscellaneous|various|unknown|random|other|things?|stuff)\s*·",
    re.I,
)


def topic_line_acceptable(line: str) -> bool:
    """
    True if the model line looks like a concrete two-part theme (not a vague bucket).
    Used to fall back to keyword heuristics when the API is unhelpful.
    """
    s = line.strip()
    if len(s) < 10 or len(s) > _MAX_TOPIC_LEN:
        return False
    # Require a clear domain / subtype split (middle dot preferred; allow spaced hyphen).
    if "\u00b7" not in s and " - " not in s:
        return False
    if _VAGUE_SUBTYPE.search(s) or _VAGUE_DOMAIN.search(s):
        return False
    if re.search(r"\b(the answer|this word|the word|hangman|puzzle)\b", s, re.I):
        return False
    return True


def _normalize_cache_key(secret: str) -> str:
    s = secret.upper().strip()
    s = re.sub(r"[^A-Z\s]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _ai_env_enabled() -> bool:
    v = os.environ.get("HANGMAN_WORD_THEME_AI", "1").strip().lower()
    return v not in ("0", "false", "no", "off")


def _api_key() -> str:
    return (
        os.environ.get("HANGMAN_OPENAI_API_KEY", "").strip()
        or os.environ.get("HANGMAN_WORD_THEME_API_KEY", "").strip()
    )


def _response_leaks_answer(secret: str, text: str) -> bool:
    key = _normalize_cache_key(secret).replace(" ", "")
    if len(key) < 4:
        return False
    compact = re.sub(r"[^A-Z]", "", text.upper())
    return key in compact


def _sanitize_topic_line(raw: str) -> str | None:
    line = raw.strip().splitlines()[0] if raw.strip() else ""
    line = line.strip().strip('"').strip("'")
    line = re.sub(r"^theme:\s*", "", line, flags=re.I)
    if not line or len(line) > _MAX_TOPIC_LEN:
        return None
    if re.search(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", line):
        return None
    return line


def fetch_ai_topic_openai(secret: str, heuristic_hint: str | None = None) -> str | None:
    if not _ai_env_enabled():
        return None
    api_key = _api_key()
    if not api_key:
        return None

    model = os.environ.get("HANGMAN_WORD_THEME_AI_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"
    try:
        timeout = float(os.environ.get("HANGMAN_WORD_THEME_AI_TIMEOUT", "2.5"))
    except ValueError:
        timeout = 2.5
    timeout = max(0.5, min(timeout, 15.0))

    system = (
        "You write a single theme hint for a hangman puzzle answer. Output exactly ONE line of plain text.\n"
        "Format MUST be: Wider domain · narrow subtype — use the middle dot character (·) between the two parts.\n"
        "The subtype must name a *kind of thing* the answer refers to (what it is in the real world), "
        "not grammar, not letter-count, not 'common word' or 'vocabulary'.\n"
        "Good: 'Food · breakfast pastry', 'Nature · farm animal', 'Home · cleaning tool', 'Film · movie genre'.\n"
        "Bad: anything with a vague second half (general, miscellaneous, things, stuff, concepts, everyday, various, "
        "common words, random, other).\n"
        "Do not repeat or spell the answer, use its substrings as hints, or list letters. "
        "No quotes, bullets, second sentences, or a 'Theme:' prefix. Max ~75 characters."
    )
    hint = (heuristic_hint or "").strip()
    if len(hint) > 72:
        hint = hint[:69] + "..."
    user_parts = [
        f"Answer (classify only; keep secret): {secret.strip()}",
    ]
    if hint:
        user_parts.append(
            f"Automatic keyword guess (often coarse; replace if it clearly does not fit this answer): {hint}"
        )
    user = "\n".join(user_parts)

    body = json.dumps(
        {
            "model": model,
            "temperature": 0.12,
            "max_tokens": 80,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, json.JSONDecodeError) as e:
        logger.debug("word_topic_ai: request failed: %s", e)
        return None

    try:
        raw = (payload["choices"][0]["message"]["content"] or "").strip()
    except (KeyError, IndexError, TypeError):
        return None

    topic = _sanitize_topic_line(raw)
    if not topic:
        return None
    if _response_leaks_answer(secret, topic):
        logger.debug("word_topic_ai: rejected topic that looked like a leak")
        return None
    if not topic_line_acceptable(topic):
        logger.debug("word_topic_ai: rejected topic as too vague or malformed")
        return None
    return topic


def fetch_ai_topic_from_glossary(gloss: str, part_of_speech: str | None = None) -> str | None:
    """
    Offline theme-map builder: classify from dictionary definition text only (headword not shown).
    Uses the same OpenAI env vars as ``fetch_ai_topic_openai``; not cached.
    """
    if not _ai_env_enabled():
        return None
    api_key = _api_key()
    if not api_key or not (gloss or "").strip():
        return None

    model = os.environ.get("HANGMAN_WORD_THEME_AI_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"
    try:
        timeout = float(os.environ.get("HANGMAN_WORD_THEME_AI_TIMEOUT", "2.5"))
    except ValueError:
        timeout = 2.5
    timeout = max(0.5, min(timeout, 30.0))

    system = (
        "You see only an English dictionary definition; the headword is hidden from you.\n"
        "Output exactly ONE line: 'Wider domain · narrow subtype' using the middle dot (·).\n"
        "Describe what kind of thing, process, person, place, or idea is being defined — "
        "specific enough to help someone guess the category, without naming or spelling the word.\n"
        "Avoid vague second halves (general, miscellaneous, things, stuff, concepts, vocabulary). "
        "Max ~78 characters. No 'Theme:' prefix, no quotes, no second sentence."
    )
    user = gloss.strip()
    if len(user) > 2800:
        user = user[:2797] + "..."
    if part_of_speech:
        user = f"{user}\nPart of speech: {part_of_speech.strip()}"

    body = json.dumps(
        {
            "model": model,
            "temperature": 0.12,
            "max_tokens": 80,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, json.JSONDecodeError) as e:
        logger.debug("word_topic_ai: glossary request failed: %s", e)
        return None

    try:
        raw = (payload["choices"][0]["message"]["content"] or "").strip()
    except (KeyError, IndexError, TypeError):
        return None

    topic = _sanitize_topic_line(raw)
    if not topic or not topic_line_acceptable(topic):
        return None
    return topic


def fetch_ai_topic_cached(secret: str, heuristic_hint: str | None = None) -> str | None:
    raw_key = _normalize_cache_key(secret)
    if not raw_key:
        return None
    key = f"{_CACHE_KEY_PREFIX}{raw_key}"
    if key in _CACHE:
        _CACHE.move_to_end(key)
        return _CACHE[key]
    topic = fetch_ai_topic_openai(secret, heuristic_hint=heuristic_hint)
    if topic:
        _CACHE[key] = topic
        while len(_CACHE) > _MAX_CACHE:
            _CACHE.popitem(last=False)
    return topic
