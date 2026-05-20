import { useEffect, useState } from "react";
import { ApiError, fetchActiveUsers, fetchHangmanLeaderboard } from "../lib/api";
import { SuperFanBadge } from "../components/SuperFanBadge";
import type { ActiveAppUser, HangmanLeaderboardRow } from "../types";

interface Props {
  leaderboard: HangmanLeaderboardRow[];
  onLeaderboard: (rows: HangmanLeaderboardRow[]) => void;
}

function rowName(r: HangmanLeaderboardRow): string {
  return r.displayName || r.name || r.user || "?";
}

export function BoardTab({ leaderboard, onLeaderboard }: Props) {
  const [online, setOnline] = useState<ActiveAppUser[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [lb, pres] = await Promise.all([
          fetchHangmanLeaderboard().catch(() => leaderboard),
          fetchActiveUsers(),
        ]);
        if (cancelled) return;
        if (lb.length) onLeaderboard(lb);
        setOnline(pres.activeAppUserList || []);
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof ApiError ? e.message : "Could not refresh board");
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [leaderboard, onLeaderboard]);

  return (
    <div>
      <h2 style={{ margin: "0 0 8px", fontSize: 18 }}>All-time board</h2>
      <p className="muted" style={{ marginTop: 0 }}>
        Hangman wins — not Crash crash leaderboard.
      </p>

      {error && <div className="error-banner" style={{ marginBottom: 12 }}>{error}</div>}

      <div className="panel" style={{ marginBottom: 16 }}>
        <h3 style={{ margin: "0 0 10px", fontSize: 14, color: "var(--accent)" }}>
          Online now ({online.length})
        </h3>
        {online.length === 0 ? (
          <p className="muted">No other players detected in NFG apps.</p>
        ) : (
          <ul style={{ margin: 0, padding: 0, listStyle: "none" }}>
            {online.map((u) => (
              <li
                key={u.userId}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  padding: "8px 0",
                  borderBottom: "1px solid var(--border)",
                }}
              >
                <span>{u.displayName || u.userId}</span>
                <SuperFanBadge superFan={u.superFan} level={u.superFanLevel} />
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="panel">
        <h3 style={{ margin: "0 0 10px", fontSize: 14 }}>Leaderboard</h3>
        {leaderboard.length === 0 ? (
          <p className="muted">Waiting for scores from the server…</p>
        ) : (
          <ol style={{ margin: 0, paddingLeft: 20 }}>
            {leaderboard.map((r, i) => (
              <li key={`${rowName(r)}-${i}`} style={{ padding: "6px 0" }}>
                <strong>{rowName(r)}</strong>
                <span className="muted">
                  {" "}
                  — {r.wins ?? r.score ?? 0} win{(r.wins ?? r.score ?? 0) === 1 ? "" : "s"}
                </span>
              </li>
            ))}
          </ol>
        )}
      </div>
    </div>
  );
}
