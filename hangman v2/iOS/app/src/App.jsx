import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import AccountPanel from "./components/AccountPanel";
import NFGHangmanLogo from "./components/NFGHangmanLogo";
import ChatPanel from "./components/ChatPanel";
import GuessKeyboard from "./components/GuessKeyboard";
import OnlinePanel from "./components/OnlinePanel";
import WordDisplay from "./components/WordDisplay";
import {
  connectPlatformSocket,
  fetchPlatformStatus,
  fetchSession,
  guessLetter,
  hangmanWsUrl,
  sendPresenceHeartbeat,
} from "./lib/nfgApi";
import { mergeGuessIntoState, normalizeHangmanState } from "./lib/hangmanState";

const TABS = [
  { id: "play", label: "Play" },
  { id: "board", label: "Board" },
  { id: "chat", label: "Chat" },
  { id: "account", label: "Account" },
];

export default function App() {
  const [tab, setTab] = useState("play");
  const [session, setSession] = useState(null);
  const [platform, setPlatform] = useState(null);
  const [onlineUsers, setOnlineUsers] = useState([]);
  const [onlineCount, setOnlineCount] = useState(0);

  const [hmStatus, setHmStatus] = useState("Connecting…");
  const [streamer, setStreamer] = useState("");
  const [theme, setTheme] = useState("");
  const [state, setState] = useState(null);
  const [allTime, setAllTime] = useState([]);
  const [hmConnected, setHmConnected] = useState(false);
  const [guessBusy, setGuessBusy] = useState(false);
  const [guessResult, setGuessResult] = useState(null);

  const appendChatRef = useRef(null);

  const liveOn = useMemo(() => {
    const tl = platform?.tiktokLive;
    return !!(tl?.isLive || tl?.hangman?.isLive || tl?.crash?.isLive);
  }, [platform]);

  const refreshPlatform = useCallback(async () => {
    try {
      const body = await fetchPlatformStatus();
      if (body.ok) {
        setPlatform(body);
        setOnlineUsers(body.activeAppUserList || []);
        setOnlineCount(Number(body.activeAppUsers) || 0);
      }
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    fetchSession().then((body) => {
      if (body.ok && body.session) setSession(body.session);
    });
    refreshPlatform();
    const platformTimer = window.setInterval(refreshPlatform, 12000);
    const presenceTimer = window.setInterval(() => {
      sendPresenceHeartbeat().then((body) => {
        if (body.ok) {
          setOnlineUsers(body.activeAppUserList || []);
          setOnlineCount(Number(body.activeAppUsers) || 0);
        }
      });
    }, 20000);
    sendPresenceHeartbeat();

    const ws = connectPlatformSocket({
      onChat: (row) => appendChatRef.current?.(row),
      onPresence: (payload) => {
        setOnlineUsers(payload.activeAppUserList || []);
        setOnlineCount(Number(payload.activeAppUsers) || 0);
      },
    });

    return () => {
      window.clearInterval(platformTimer);
      window.clearInterval(presenceTimer);
      ws.close();
    };
  }, [refreshPlatform]);

  useEffect(() => {
    const target = hangmanWsUrl();
    let ws = null;
    let pingTimer = null;
    let reconnectTimer = null;
    let disposed = false;

    function connect() {
      if (disposed) return;
      ws = new WebSocket(target);
      ws.onopen = () => {
        setHmConnected(true);
        setHmStatus("Live");
      };
      ws.onclose = () => {
        setHmConnected(false);
        setHmStatus("Reconnecting…");
        reconnectTimer = window.setTimeout(connect, 2000);
      };
      ws.onerror = () => ws?.close();
      ws.onmessage = (event) => {
        let data;
        try {
          data = JSON.parse(event.data);
        } catch {
          return;
        }
        if (data.type !== "update") return;
        if (typeof data.tiktok_status === "string" && data.tiktok_status.trim()) {
          setHmStatus(data.tiktok_status);
        }
        if (typeof data.tiktok === "string") setStreamer(data.tiktok);
        if (data.state) {
          const next = normalizeHangmanState(data.state);
          setState(next);
          if (next?.wordTheme) setTheme(next.wordTheme);
        }
        if (Array.isArray(data.alltime)) setAllTime(data.alltime.slice(0, 15));
      };
      pingTimer = window.setInterval(() => {
        if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: "ping" }));
      }, 25000);
    }

    connect();
    return () => {
      disposed = true;
      if (pingTimer) window.clearInterval(pingTimer);
      if (reconnectTimer) window.clearInterval(reconnectTimer);
      ws?.close();
    };
  }, []);

  const registerChatAppend = useCallback((fn) => {
    appendChatRef.current = fn;
  }, []);

  async function handleGuess(letter) {
    if (!session?.userId || guessBusy) return;
    setGuessBusy(true);
    setGuessResult(null);
    try {
      const out = await guessLetter(letter);
      if (!out.ok) {
        setGuessResult({ ok: false, text: out.message || out.error || "Guess failed" });
      } else if (out.eliminated) {
        setGuessResult({ ok: false, text: `Out for this word (${out.wrongGuesses}/${out.maxWrong} wrong)` });
      } else {
        const line = Array.isArray(out.lines) && out.lines.length ? out.lines[out.lines.length - 1] : "";
        setGuessResult({ ok: true, text: line || `Guessed ${letter}` });
        setState((prev) => mergeGuessIntoState(prev, out));
      }
    } catch (e) {
      setGuessResult({ ok: false, text: e.message });
    } finally {
      setGuessBusy(false);
    }
  }

  const guessedLetters = useMemo(
    () => (state?.guessedLetters ?? []).join(" "),
    [state?.guessedLetters]
  );

  return (
    <main className="app-shell">
      <header className="top-bar">
        <div className="brand">
          <NFGHangmanLogo height={46} />
          <p className="tag">Companion</p>
        </div>
        <div className="live-stats">
          <span className={`live-dot${liveOn ? " on" : ""}`} title="TikTok live" />
          <span className="live-label">{liveOn ? "LIVE" : "OFFLINE"}</span>
          <span className="live-users">{onlineCount} in apps</span>
        </div>
      </header>

      <nav className="tabs">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            className={`tab${tab === t.id ? " active" : ""}`}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </nav>

      {tab === "play" ? (
        <section className="panel game-panel">
          <header className="section-head">
            <h2>Current word</h2>
            <span className={`pill ${hmConnected ? "ok" : "warn"}`}>{hmStatus}</span>
          </header>
          <p className="meta">@{streamer || "hangman"} · {theme || "Theme pending"}</p>
          <WordDisplay slots={state?.slots} length={state?.length} maskedWord={state?.maskedWord} />
          <div className="stats-row">
            <span>
              Wrong: {state?.wrongGuesses ?? 0}/{state?.maxWrong ?? 6}
            </span>
            <span>Phase: {state?.phase || "—"}</span>
          </div>
          <p className="guessed">
            <strong>Guessed:</strong> {guessedLetters || "—"}
          </p>
          <GuessKeyboard
            keyboardCorrect={state?.keyboardCorrect}
            keyboardWrong={state?.keyboardWrong}
            disabled={!session?.userId || guessBusy}
            onGuess={handleGuess}
            lastResult={guessResult}
          />
        </section>
      ) : null}

      {tab === "board" ? (
        <>
          <section className="panel">
            <header className="section-head">
              <h2>Hangman all-time</h2>
              <span className="sub">Separate from NFG Crash</span>
            </header>
            <ol className="rank-list">
              {allTime.length === 0 ? (
                <li className="muted">Waiting for leaderboard…</li>
              ) : (
                allTime.map((row, idx) => (
                  <li key={`${row.user_key || row.name || idx}`}>
                    <span className="rank-idx">{idx + 1}</span>
                    <span className="rank-name">{row.name || row.user_key || "Unknown"}</span>
                    <span className="rank-score">{Number(row.score || 0).toLocaleString()}</span>
                  </li>
                ))
              )}
            </ol>
          </section>
          <OnlinePanel users={onlineUsers} count={onlineCount} />
        </>
      ) : null}

      {tab === "chat" ? (
        <>
          <ChatPanel session={session} registerAppend={registerChatAppend} />
          <OnlinePanel users={onlineUsers} count={onlineCount} />
        </>
      ) : null}

      {tab === "account" ? <AccountPanel onSession={setSession} /> : null}
    </main>
  );
}
