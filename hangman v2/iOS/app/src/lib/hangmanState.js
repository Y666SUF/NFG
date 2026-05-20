/** Normalize Hangman WS / guess payloads to a stable mobile shape. */

function upperLetters(list) {
  return (list || [])
    .map((c) => String(c).toUpperCase())
    .filter((c) => /^[A-Z]$/.test(c));
}

export function formatMaskFromSlots(slots) {
  const groups = [];
  let current = [];
  for (const ch of slots) {
    if (ch === " ") {
      if (current.length) {
        groups.push(current.map((c) => (c ? String(c).toUpperCase() : "_")).join(" "));
        current = [];
      }
    } else {
      current.push(c ? String(c).toUpperCase() : "_");
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

export function normalizeHangmanState(raw) {
  if (!raw || typeof raw !== "object") return null;

  const slots = Array.isArray(raw.slots) ? raw.slots : null;
  const kb = raw.keyboard || {};
  const keyboardCorrect = upperLetters(kb.correct);
  const keyboardWrong = upperLetters(kb.wrong);

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

  const guessedLetters = Array.isArray(raw.guessed_letters)
    ? raw.guessed_letters
    : Array.isArray(raw.guessedLetters)
      ? raw.guessedLetters
      : [...keyboardCorrect, ...keyboardWrong].map((c) => String(c).toLowerCase());

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
  if (!out?.ok) return prev;
  const patch = {};
  if (Array.isArray(out.slots)) patch.slots = out.slots;
  if (out.keyboard && typeof out.keyboard === "object") patch.keyboard = out.keyboard;
  if (out.length) patch.length = out.length;
  const masked = out.masked || out.maskedWord;
  if (masked) patch.mask = masked;
  if (Array.isArray(out.guessed)) patch.guessed_letters = out.guessed;
  return normalizeHangmanState({ ...toRawShape(prev), ...patch });
}
