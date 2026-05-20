const ROWS = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"];

export default function GuessKeyboard({ guessedLetters = [], disabled, onGuess, lastResult }) {
  const guessed = new Set(
    (guessedLetters || []).map((c) => String(c).toUpperCase()).filter((c) => /^[A-Z]$/.test(c))
  );

  return (
    <div className="keyboard-wrap">
      {ROWS.map((row) => (
        <div key={row} className="kb-row">
          {row.split("").map((letter) => {
            const used = guessed.has(letter);
            return (
              <button
                key={letter}
                type="button"
                className={`kb-key${used ? " used" : ""}`}
                disabled={disabled || used}
                onClick={() => onGuess(letter)}
              >
                {letter}
              </button>
            );
          })}
        </div>
      ))}
      {lastResult ? (
        <p className={`guess-result ${lastResult.ok ? "ok" : "bad"}`}>{lastResult.text}</p>
      ) : null}
      {!disabled ? (
        <p className="kb-hint">6 wrong guesses eliminates you for this word (same as live chat).</p>
      ) : (
        <p className="kb-hint warn">Link TikTok to guess from the app keyboard.</p>
      )}
    </div>
  );
}
