import React, { useEffect, useState } from "react";
import { motion } from "framer-motion";

function isDevFrontendServer() {
  return typeof window !== "undefined" && window.location.port === "3000";
}

function leaderboardUrl(limit = 12) {
  if (isDevFrontendServer()) {
    const base = String(process.env.REACT_APP_BACKEND_URL || "http://127.0.0.1:3847").replace(/\/+$/, "");
    return `${base}/api/hangman/leaderboard?limit=${limit}`;
  }
  return `/api/hangman/leaderboard?limit=${limit}`;
}

function normalizeEntries(data) {
  const rows = Array.isArray(data?.top) ? data.top : [];
  return rows.map((row, idx) => ({
    id: row.user_key || row.name || `hm-${idx}`,
    player_name: row.name || row.user_key || "PLAYER",
    score: Number(row.score || 0),
  }));
}

async function fetchHangmanLeaderboard(limit = 12) {
  const url = leaderboardUrl(limit);
  let lastErr = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const res = await fetch(url, {
        method: "GET",
        cache: "no-store",
        credentials: "same-origin",
        headers: { Accept: "application/json" },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      return normalizeEntries(data);
    } catch (err) {
      lastErr = err;
      if (attempt < 2) await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
    }
  }
  throw lastErr || new Error("hangman leaderboard fetch failed");
}

export default function HangmanLeaderboard() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = async () => {
    try {
      setLoading(true);
      setEntries(await fetchHangmanLeaderboard(12));
      setError(null);
    } catch (e) {
      setError(e.message || "Could not load Hangman leaderboard");
      setEntries([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    const t = window.setInterval(load, 20000);
    return () => window.clearInterval(t);
  }, []);

  return (
    <section data-testid="hangman-leaderboard">
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <div>
          <span className="label-tag">// HANGMAN ALL-TIME</span>
          <h2 className="font-display font-black uppercase text-3xl md:text-4xl tracking-tight mt-2">
            Leaderboard
          </h2>
          <p className="mt-2 text-zinc-400 text-sm max-w-lg">
            Separate from NFG Crash points. Updates from the live Hangman game server.
          </p>
        </div>
        <button type="button" className="btn-ghost text-sm" onClick={load}>
          Refresh
        </button>
      </div>

      {loading && <p className="text-zinc-400 font-mono text-sm">Loading…</p>}
      {error && !loading && (
        <p className="text-rose-300 font-mono text-sm" data-testid="hangman-leaderboard-error">
          Signal lost — {error}
        </p>
      )}

      {!loading && !error && (
        <div className="grid gap-2">
          {entries.length === 0 ? (
            <p className="text-zinc-500 text-sm">No scores yet. Play on @y666.suf live Hangman.</p>
          ) : (
            entries.map((row, i) => (
              <motion.div
                key={row.id}
                initial={{ opacity: 0, x: -8 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.04 }}
                className="flex items-center justify-between gap-4 rounded-xl border border-fuchsia-400/20 bg-black/55 px-4 py-3"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <span className="font-display font-black text-fuchsia-300 w-8">{i + 1}</span>
                  <span className="truncate text-zinc-100">{row.player_name}</span>
                </div>
                <span className="font-mono text-cyan-300 font-bold">{row.score.toLocaleString()}</span>
              </motion.div>
            ))
          )}
        </div>
      )}
    </section>
  );
}
