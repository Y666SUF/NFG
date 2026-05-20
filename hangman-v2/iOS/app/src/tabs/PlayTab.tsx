import { useCallback, useState } from "react";
import { ApiError, postHangmanGuess } from "../lib/api";
import type { HangmanState } from "../types";

const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

interface Props {
  state: HangmanState | null;
  loggedIn: boolean;
  onState: (s: HangmanState) => void;
}

export function PlayTab({ state, loggedIn, onState }: Props) {
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const wrong = state?.wrong ?? 0;
  const maxWrong = state?.maxWrong ?? 6;
  const guessed = new Set((state?.guessed || []).map((g) => g.toUpperCase()));
  const masked = state?.masked || "— — —";
  const out = state?.eliminated || state?.lost || wrong >= maxWrong;
  const won = state?.won === true;

  const guess = useCallback(
    async (letter: string) => {
      if (!loggedIn) {
        setError("Link your TikTok on the Account tab first.");
        return;
      }
      if (out || won || guessed.has(letter) || busy) return;
      setBusy(true);
      setError(null);
      try {
        const result = await postHangmanGuess(letter);
        onState({
          ...state,
          ...result,
          guessed: result.guessed ?? [...(state?.guessed || []), letter.toLowerCase()],
        });
      } catch (e) {
        setError(e instanceof ApiError ? e.message : "Guess failed");
      } finally {
        setBusy(false);
      }
    },
    [loggedIn, out, won, guessed, busy, state, onState]
  );

  return (
    <div>
      <h2 style={{ margin: "0 0 8px", fontSize: 18 }}>Hangman</h2>
      <p className="muted" style={{ marginTop: 0 }}>
        Guess letters on @y666.suf LIVE — 6 wrong and you&apos;re out.
      </p>

      {error && <div className="error-banner" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="panel" style={{ marginBottom: 16, textAlign: "center" }}>
        <div className="masked-word">{masked}</div>
        <p className="muted" style={{ margin: "12px 0 0" }}>
          Wrong {wrong}/{maxWrong}
        </p>
        {out && !won && (
          <p style={{ color: "var(--danger)", fontWeight: 700 }}>You&apos;re out this round</p>
        )}
        {won && <p style={{ color: "var(--accent2)", fontWeight: 700 }}>You got it!</p>}
        {state?.message && <p className="muted">{state.message}</p>}
      </div>

      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          gap: 8,
          justifyContent: "center",
        }}
      >
        {LETTERS.map((L) => {
          const used = guessed.has(L);
          const cls = ["btn-key", used ? "correct" : ""].filter(Boolean).join(" ");
          return (
            <button
              key={L}
              type="button"
              className={cls}
              disabled={!loggedIn || out || won || used || busy}
              onClick={() => guess(L)}
            >
              {L}
            </button>
          );
        })}
      </div>
    </div>
  );
}
