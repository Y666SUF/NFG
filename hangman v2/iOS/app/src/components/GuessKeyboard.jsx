const ROWS = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"];

export default function GuessKeyboard({
  keyboardCorrect = [],
  keyboardWrong = [],
  disabled,
  onGuess,
  lastResult,
}) {
  const correct = new Set(
    (keyboardCorrect || []).map((c) => String(c).toUpperCase()).filter((c) => /^[A-Z]$/.test(c))
  );
  const wrong = new Set(
    (keyboardWrong || []).map((c) => String(c).toUpperCase()).filter((c) => /^[A-Z]$/.test(c))
  );

  return (
    <div className="keyboard-wrap">
      {ROWS.map((row) => (
        <div key={row} className="kb-row">
          {row.split("").map((letter) => {
            const isCorrect = correct.has(letter);
            const isWrong = wrong.has(letter);
            const used = isCorrect || isWrong;
            let cls = "kb-key";
            if (isCorrect) cls += " kb-correct";
            else if (isWrong) cls += " kb-wrong";
            return (
              <button
                key={letter}
                type="button"
                className={cls}
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
