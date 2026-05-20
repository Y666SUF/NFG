/** Normalize Hangman WS / guess payloads to a stable mobile shape. */

function asLetterArray(value) {
  if (Array.isArray(value)) {
    return value
      .map((c) => String(c).trim())
      .filter((c) => c.length === 1 && /^[A-Za-z]$/.test(c));
  }
  if (typeof value === "string" && value.length === 1 && /^[A-Za-z]$/.test(value)) {
    return [value];
  }
  return [];
}

function upperLetters(list) {
  return asLetterArray(list).map((c) => c.toUpperCase());
}

/** WS poll, guess API, or nested `state` → raw snapshot for normalizeHangmanState. */
export function payloadToHangmanRaw(payload) {
  if (!payload || typeof payload !== "object") return null;
  const hasFlat =
    Array.isArray(payload.slots) ||
    payload.mask ||
    payload.maskedWord ||
    payload.masked_word;
  if (hasFlat) return payload;
  if (payload.state && typeof payload.state === "object") return payload.state;
  return payload;
}

export function sanitizeKeyboard(kb) {
  if (!kb || typeof kb !== "object" || Array.isArray(kb)) {
    return { correct: [], wrong: [] };
  }
  return {
    correct: upperLetters(kb.correct),
    wrong: upperLetters(kb.wrong),
  };
}

export function formatMaskFromSlots(slots) {
  if (!Array.isArray(slots)) return "";
  const groups = [];
  let current = [];
  for (const ch of slots) {
    if (ch === " ") {
      if (current.length) {
        groups.push(current.map((c) => (c ? String(c).toUpperCase() : "_")).join(" "));
        current = [];
      }
    } else {
      current.push(ch ? String(c).toUpperCase() : "_");
    }
  }
  if (current.length) groups.push(current.join(" "));
  return groups.join("  |  ");
}

export function placeholderMask(length) {
  const n = Math.max(1, Math.min(32, Number(length) || 5));
  return Array(n).fill("_").join(" ");
}

function countLettersInMask(mask) {
  if (!mask) return 0;
  return String(mask).replace(/[^a-zA-Z_]/g, "").length;
}

/** Build slots from mask string e.g. "_ _ _ _ S _ _" or multi-word with | */
export function parseMaskToSlots(mask, length = 0) {
  const text = String(mask || "").trim();
  if (!text) {
    return length > 0 ? Array(length).fill(null) : null;
  }
  const slots = [];
  const words = text.split(/\s*\|\s*/);
  for (let wi = 0; wi < words.length; wi++) {
    if (wi > 0) slots.push(" ");
    const parts = words[wi].trim().split(/\s+/).filter(Boolean);
    for (const part of parts) {
      if (part.length === 1 && /^[a-zA-Z]$/.test(part)) slots.push(part.toUpperCase());
      else slots.push(null);
    }
  }
  if (slots.length) return slots;
  return length > 0 ? Array(length).fill(null) : null;
}

function coerceSlotChar(ch) {
  if (ch === " " || ch === "") return " ";
  if (ch == null || ch === false) return null;
  const s = String(ch).trim();
  if (s.length === 1 && /^[a-zA-Z]$/.test(s)) return s.toUpperCase();
  if (s === "_" || s === "—" || s === "\u00A0") return null;
  return null;
}

function normalizeSlots(rawSlots, mask, length) {
  let slots = null;
  if (Array.isArray(rawSlots) && rawSlots.length > 0) {
    slots = rawSlots.map(coerceSlotChar);
  } else if (typeof rawSlots === "string") {
    try {
      const parsed = JSON.parse(rawSlots);
      if (Array.isArray(parsed)) slots = parsed.map(coerceSlotChar);
    } catch {
      slots = parseMaskToSlots(rawSlots, length);
    }
  }
  const hasRevealed = slots?.some((ch) => ch && ch !== " ");
  const maskStr = String(mask || "").trim();
  if ((!slots || !slots.length || !hasRevealed) && maskStr) {
    const fromMask = parseMaskToSlots(maskStr, length);
    if (fromMask?.length) {
      if (!slots?.length) slots = fromMask;
      else {
        slots = slots.map((ch, i) => (ch && ch !== " " ? ch : fromMask[i] ?? ch));
      }
    }
  }
  if (!slots?.length && length > 0) slots = Array(length).fill(null);
  return slots?.length ? slots : null;
}

function lettersRevealedInSlots(slots) {
  if (!Array.isArray(slots)) return [];
  return slots
    .filter((ch) => ch && ch !== " ")
    .map((ch) => String(ch).toUpperCase())
    .filter((c) => /^[A-Z]$/.test(c));
}

function normalizeGuessedLetters(raw, keyboardCorrect, keyboardWrong) {
  if (Array.isArray(raw)) {
    return raw.map((c) => String(c).toLowerCase()).filter((c) => /^[a-z]$/.test(c));
  }
  return [...keyboardCorrect, ...keyboardWrong].map((c) => String(c).toLowerCase());
}

export function normalizeHangmanState(raw) {
  try {
    if (!raw || typeof raw !== "object") return null;

    const maskStr = String(raw.mask ?? raw.masked_word ?? raw.maskedWord ?? "").trim();
    const length =
      Number(raw.length) ||
      countLettersInMask(maskStr) ||
      (Array.isArray(raw.slots) ? raw.slots.filter((c) => c !== " ").length : 0);

    const slots = normalizeSlots(raw.slots, maskStr, length);
    const kb = sanitizeKeyboard(raw.keyboard);
    const revealed = lettersRevealedInSlots(slots);
    const keyboardCorrect = [...new Set([...kb.correct, ...revealed])];
    const keyboardWrong = kb.wrong.filter((c) => !keyboardCorrect.includes(c));

    const revealedCount = lettersRevealedInSlots(slots).length;
    const maskLetterCount = (maskStr.match(/[a-zA-Z]/g) || []).length;
    let maskedWord = maskStr;
    if (slots?.length && revealedCount >= maskLetterCount) {
      maskedWord = formatMaskFromSlots(slots);
    } else if (!maskedWord && length > 0) {
      maskedWord = placeholderMask(length);
    } else if (maskStr && revealedCount < maskLetterCount) {
      // Keep server mask when slots[] are stale nulls but mask has letters
      maskedWord = maskStr;
    }

    const guessedLetters = normalizeGuessedLetters(
      raw.guessed_letters ?? raw.guessedLetters ?? raw.guessed,
      keyboardCorrect,
      keyboardWrong
    );

    const displayMask =
      maskLetterCount > 0 || maskStr.includes("_")
        ? maskedWord
        : formatMaskFromSlots(slots) || maskedWord;

    return {
      maskedWord: displayMask,
      slots,
      length,
      wrongGuesses: Number(raw.wrong_guesses ?? raw.wrong ?? 0),
      maxWrong: Number(raw.max_wrong ?? raw.maxWrong ?? 6),
      guessedLetters,
      keyboardCorrect,
      keyboardWrong,
      phase: String(raw.phase ?? ""),
      wordTheme: String(raw.word_theme ?? raw.wordTheme ?? ""),
    };
  } catch (err) {
    console.warn("[hangman] normalize state failed", err);
    return null;
  }
}

function toRawShape(state) {
  if (!state) return {};
  return {
    mask: state.maskedWord,
    slots: state.slots,
    length: state.length,
    guessed_letters: state.guessedLetters,
    keyboard: { correct: state.keyboardCorrect, wrong: state.keyboardWrong },
    wrong_guesses: state.wrongGuesses,
    max_wrong: state.maxWrong,
    phase: state.phase,
    word_theme: state.wordTheme,
  };
}

/** Apply immediate guess API fields before the next WS update. */
export function mergeGuessIntoState(prev, out) {
  try {
    if (!out?.ok) return prev;
    const patch = {};
    if (Array.isArray(out.slots)) patch.slots = out.slots;
    if (out.keyboard && typeof out.keyboard === "object" && !Array.isArray(out.keyboard)) {
      patch.keyboard = sanitizeKeyboard(out.keyboard);
    }
    if (out.length) patch.length = out.length;
    const masked = out.masked || out.maskedWord;
    if (masked) patch.mask = String(masked);
    if (Array.isArray(out.guessed)) patch.guessed_letters = out.guessed;
    const next = normalizeHangmanState({ ...toRawShape(prev), ...patch });
    return next ?? prev;
  } catch (err) {
    console.warn("[hangman] merge guess state failed", err);
    return prev;
  }
}
