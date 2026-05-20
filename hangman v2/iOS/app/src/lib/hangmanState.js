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

function normalizeGuessedLetters(raw, keyboardCorrect, keyboardWrong) {
  if (Array.isArray(raw)) {
    return raw.map((c) => String(c).toLowerCase()).filter((c) => /^[a-z]$/.test(c));
  }
  return [...keyboardCorrect, ...keyboardWrong].map((c) => String(c).toLowerCase());
}

export function normalizeHangmanState(raw) {
  try {
    if (!raw || typeof raw !== "object") return null;

    const slots = Array.isArray(raw.slots) ? raw.slots : null;
    const { correct: keyboardCorrect, wrong: keyboardWrong } = sanitizeKeyboard(raw.keyboard);

    const length =
      Number(raw.length) ||
      (slots ? slots.filter((c) => c !== " ").length : 0) ||
      countLettersInMask(String(raw.mask ?? raw.masked_word ?? raw.maskedWord ?? ""));

    let maskedWord = String(raw.masked_word ?? raw.maskedWord ?? raw.mask ?? "").trim();
    if (slots?.length) {
      maskedWord = formatMaskFromSlots(slots);
    } else if (!maskedWord && length > 0) {
      maskedWord = placeholderMask(length);
    }

    const guessedLetters = normalizeGuessedLetters(
      raw.guessed_letters ?? raw.guessedLetters ?? raw.guessed,
      keyboardCorrect,
      keyboardWrong
    );

    return {
      maskedWord,
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
