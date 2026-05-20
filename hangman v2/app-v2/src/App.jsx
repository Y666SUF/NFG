import { useEffect, useMemo, useState } from "react";

const AVATARS = [
  { id: "ninja-fox", name: "Ninja Fox", icon: "🦊", requiredLevel: 1, price: 0, accent: "#ff9b4d" },
  { id: "pixel-mage", name: "Pixel Mage", icon: "🧙", requiredLevel: 4, price: 240, accent: "#8f8bff" },
  { id: "owl-sage", name: "Owl Sage", icon: "🦉", requiredLevel: 6, price: 420, accent: "#52c6ff" },
  { id: "panda-tank", name: "Panda Tank", icon: "🐼", requiredLevel: 8, price: 650, accent: "#a4f58b" },
  { id: "robot-glitch", name: "Robot Glitch", icon: "🤖", requiredLevel: 10, price: 900, accent: "#ff6fd1" }
];

const BOARD_SKINS = [
  {
    id: "chalk",
    name: "Classroom Chalkboard",
    requiredLevel: 1,
    price: 0,
    subtitle: "Classic clean look",
    hangmanTheme: "Chalk outline gallows"
  },
  {
    id: "neon",
    name: "Neon Arcade",
    requiredLevel: 5,
    price: 300,
    subtitle: "Glowing cyber style",
    hangmanTheme: "Power core stability meter"
  },
  {
    id: "pirate",
    name: "Pirate Deck",
    requiredLevel: 7,
    price: 500,
    subtitle: "Wood, ropes, storm glow",
    hangmanTheme: "Ship hull integrity"
  },
  {
    id: "space",
    name: "Space Void",
    requiredLevel: 9,
    price: 760,
    subtitle: "Nebula and stars",
    hangmanTheme: "Oxygen reserve"
  }
];

function normalizeState(raw) {
  if (!raw || typeof raw !== "object") return null;
  return {
    maskedWord: String(raw.masked_word ?? ""),
    wrongGuesses: Number(raw.wrong_guesses ?? 0),
    maxWrong: Number(raw.max_wrong ?? 6),
    guessedLetters: Array.isArray(raw.guessed_letters) ? raw.guessed_letters : [],
    pointsRound: Array.isArray(raw.points_round) ? raw.points_round : [],
    phase: String(raw.phase ?? "")
  };
}

export default function App() {
  const [status, setStatus] = useState("Connecting...");
  const [streamer, setStreamer] = useState("");
  const [theme, setTheme] = useState("");
  const [state, setState] = useState(null);
  const [allTime, setAllTime] = useState([]);
  const [connected, setConnected] = useState(false);
  const [activeView, setActiveView] = useState("customization");
  const [selectedAvatarId, setSelectedAvatarId] = useState(AVATARS[0].id);
  const [selectedSkinId, setSelectedSkinId] = useState(BOARD_SKINS[1].id);
  const [previewWrong, setPreviewWrong] = useState(2);
  const [coins] = useState(780);
  const [level] = useState(7);

  useEffect(() => {
    let ws = null;
    let pingTimer = null;
    let reconnectTimer = null;
    let isDisposed = false;

    function connectSocket() {
      if (isDisposed) return;
      const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
      ws = new WebSocket(`${protocol}//${window.location.host}/ws`);

      ws.onopen = () => {
        setConnected(true);
        setStatus("Live");
      };

      ws.onclose = () => {
        setConnected(false);
        setStatus("Offline preview");
        if (pingTimer) clearInterval(pingTimer);
        if (!isDisposed) {
          reconnectTimer = setTimeout(connectSocket, 5000);
        }
      };

      ws.onerror = () => ws.close();

      ws.onmessage = (event) => {
        let data;
        try {
          data = JSON.parse(event.data);
        } catch {
          return;
        }
        if (data.type !== "update") return;

        if (typeof data.tiktok_status === "string" && data.tiktok_status.trim()) {
          setStatus(data.tiktok_status);
        }
        if (typeof data.tiktok === "string") {
          setStreamer(data.tiktok);
        }
        if (data.state) {
          setState(normalizeState(data.state));
        }
        if (Array.isArray(data.alltime)) {
          setAllTime(data.alltime.slice(0, 10));
        }
        if (data.state && typeof data.state.word_theme === "string") {
          setTheme(data.state.word_theme);
        }
      };

      pingTimer = setInterval(() => {
        if (ws && ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "ping" }));
        }
      }, 25000);
    }

    connectSocket();

    return () => {
      isDisposed = true;
      if (pingTimer) clearInterval(pingTimer);
      if (reconnectTimer) clearTimeout(reconnectTimer);
      if (ws) ws.close();
    };
  }, []);

  const guessedLetters = useMemo(
    () => (state?.guessedLetters ?? []).join(" "),
    [state?.guessedLetters]
  );
  const selectedAvatar = useMemo(
    () => AVATARS.find((item) => item.id === selectedAvatarId) ?? AVATARS[0],
    [selectedAvatarId]
  );
  const selectedSkin = useMemo(
    () => BOARD_SKINS.find((item) => item.id === selectedSkinId) ?? BOARD_SKINS[0],
    [selectedSkinId]
  );
  const previewHeartsLeft = Math.max(0, 6 - previewWrong);

  function isUnlocked(item) {
    return level >= item.requiredLevel && coins >= item.price;
  }

  return (
    <main className="page">
      <section className="panel top-panel">
        <header className="header">
          <div>
            <h1>Hangman V2</h1>
            <p className="subheading">Avatar + board skins prototype</p>
          </div>
          <span className={`pill ${connected ? "ok" : "warn"}`}>{status}</span>
        </header>

        <div className="view-toggle">
          <button
            type="button"
            className={activeView === "customization" ? "active" : ""}
            onClick={() => setActiveView("customization")}
          >
            Customization Lab (Preview)
          </button>
          <button
            type="button"
            className={activeView === "live" ? "active" : ""}
            onClick={() => setActiveView("live")}
          >
            Live Board
          </button>
        </div>
      </section>

      {activeView === "customization" ? (
        <>
          <section className="panel preview-panel">
            <div className="preview-topbar">
              <div className="profile-chip" style={{ borderColor: selectedAvatar.accent }}>
                <span className="avatar-icon" role="img" aria-label={selectedAvatar.name}>
                  {selectedAvatar.icon}
                </span>
                <div>
                  <strong>{selectedAvatar.name}</strong>
                  <p>Level {level} • {coins} coins</p>
                </div>
              </div>
              <div className="skin-meta">
                <strong>{selectedSkin.name}</strong>
                <span>{selectedSkin.hangmanTheme}</span>
              </div>
            </div>

            <div className={`board-preview skin-${selectedSkin.id}`}>
              <div className="board-heading">{selectedSkin.subtitle}</div>
              <div className="board-word">C _ S T O M I Z E</div>
              <p className="board-caption">
                Wrong guesses: {previewWrong}/6 • Hearts left: {previewHeartsLeft}
              </p>
              <div className="damage-track">
                {[1, 2, 3, 4, 5, 6].map((step) => (
                  <span key={step} className={step <= previewWrong ? "filled" : ""} />
                ))}
              </div>
            </div>

            <div className="preview-controls">
              <button type="button" onClick={() => setPreviewWrong((v) => Math.max(0, v - 1))}>
                Guess Right
              </button>
              <button type="button" onClick={() => setPreviewWrong((v) => Math.min(6, v + 1))}>
                Guess Wrong
              </button>
              <button type="button" onClick={() => setPreviewWrong(0)}>
                Reset Round
              </button>
            </div>
          </section>

          <section className="panel locker-panel">
            <h2>Locker</h2>
            <p className="muted">Click any card to preview style in-game.</p>

            <h3>Avatars</h3>
            <div className="card-grid">
              {AVATARS.map((avatar) => {
                const unlocked = isUnlocked(avatar);
                const selected = selectedAvatarId === avatar.id;
                return (
                  <button
                    key={avatar.id}
                    type="button"
                    className={`locker-card ${selected ? "selected" : ""}`}
                    onClick={() => setSelectedAvatarId(avatar.id)}
                    style={{ borderColor: selected ? avatar.accent : undefined }}
                  >
                    <div className="locker-title-row">
                      <span className="locker-icon">{avatar.icon}</span>
                      <strong>{avatar.name}</strong>
                    </div>
                    <p>{unlocked ? "Ready to equip" : "Preview only"}</p>
                    <span className={`badge ${unlocked ? "ok" : "locked"}`}>
                      {unlocked ? "Unlocked" : `Lv${avatar.requiredLevel} • ${avatar.price} coins`}
                    </span>
                  </button>
                );
              })}
            </div>

            <h3>Board Skins</h3>
            <div className="card-grid">
              {BOARD_SKINS.map((skin) => {
                const unlocked = isUnlocked(skin);
                const selected = selectedSkinId === skin.id;
                return (
                  <button
                    key={skin.id}
                    type="button"
                    className={`locker-card ${selected ? "selected" : ""}`}
                    onClick={() => setSelectedSkinId(skin.id)}
                  >
                    <div className="locker-title-row">
                      <strong>{skin.name}</strong>
                    </div>
                    <p>{skin.subtitle}</p>
                    <span className={`badge ${unlocked ? "ok" : "locked"}`}>
                      {unlocked ? "Unlocked" : `Lv${skin.requiredLevel} • ${skin.price} coins`}
                    </span>
                  </button>
                );
              })}
            </div>
          </section>

          <section className="panel mission-panel">
            <h2>Example Progress Loop</h2>
            <ul className="mission-list">
              <li>
                <span>Win 3 rounds today</span>
                <strong>2/3</strong>
              </li>
              <li>
                <span>Solve a word with 4+ hearts left</span>
                <strong>1/1</strong>
              </li>
              <li>
                <span>Play Neon Arcade 5 times</span>
                <strong>3/5</strong>
              </li>
            </ul>
          </section>
        </>
      ) : (
        <>
          <section className="panel">
            <p className="meta">Watching: {streamer ? `@${streamer}` : "not set"}</p>
            <p className="theme">{theme || "Theme: waiting..."}</p>

            <div className="word-box">{state?.maskedWord || "_ _ _ _ _"}</div>

            <div className="stats-row">
              <div>
                <strong>Wrong guesses:</strong> {state?.wrongGuesses ?? 0}/{state?.maxWrong ?? 6}
              </div>
              <div>
                <strong>Phase:</strong> {state?.phase || "starting"}
              </div>
            </div>

            <div className="guessed">
              <strong>Guessed letters:</strong> {guessedLetters || "-"}
            </div>
          </section>

          <section className="panel">
            <h2>All-time Top 10</h2>
            <ol className="rank-list">
              {allTime.length === 0 ? (
                <li className="muted">Waiting for leaderboard data...</li>
              ) : (
                allTime.map((row, idx) => (
                  <li key={`${row.user_key || row.name || idx}`}>
                    <span className="rank-name">{row.name || row.user_key || "Unknown"}</span>
                    <span className="rank-score">{Number(row.score || 0).toLocaleString()} pts</span>
                  </li>
                ))
              )}
            </ol>
          </section>
        </>
      )}
    </main>
  );
}
