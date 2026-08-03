/**
 * NFG Jump VS — multiplayer lobby + pace elimination matches (WebSocket on Crash port).
 */
const WebSocket = require("ws");
const { validateBearer } = require("./mobile-auth");
const {
  prepareJumpVsMatch,
  syncJumpVsSessionPoints,
  finalizeJumpVsMatch,
  getJumpPlayerCosmetics,
} = require("./mobile-arcade");

const JUMP_VS_WS_PATH = "/api/mobile/jump/vs/ws";
const COUNTDOWN_MS = 15_000;
const MILESTONE_STEP = 2500;
const MAX_LOBBY_PLAYERS = 16;
const PACE_CHECK_MS = 500;

/** @type {Map<string, { ws: import('ws'), player: object }>} */
const clients = new Map();

let lobbyPhase = "waiting";
let countdownEndAt = 0;
let countdownTimer = null;
let paceTimer = null;
let activeMatch = null;
/** @type {{ pointStore?: object } | null} */
let jumpVsCtx = null;

function parseUpgradePath(request) {
  try {
    return new URL(request.url || "/", "http://localhost").pathname;
  } catch {
    return String(request.url || "/").split("?")[0] || "/";
  }
}

function sessionFromUpgrade(request) {
  const auth = validateBearer({ headers: request.headers });
  if (auth.ok) return auth.session;
  try {
    const url = new URL(request.url || "/", "http://localhost");
    const token = String(url.searchParams.get("token") || "").trim();
    if (token) {
      const qAuth = validateBearer({ headers: { authorization: `Bearer ${token}` } });
      if (qAuth.ok) return qAuth.session;
    }
  } catch {
    /* ignore */
  }
  return null;
}

function broadcast(obj, exceptUserId = null) {
  const text = JSON.stringify(obj);
  for (const [uid, rec] of clients) {
    if (exceptUserId && uid === exceptUserId) continue;
    if (rec.ws.readyState === WebSocket.OPEN) {
      try {
        rec.ws.send(text);
      } catch {
        /* ignore */
      }
    }
  }
}

function publicLobbyPlayers() {
  const rows = [];
  for (const rec of clients.values()) {
    const p = rec.player;
    rows.push({
      id: p.id,
      displayName: p.displayName,
      height: p.height || 0,
      skinId: p.skinId,
      fill: p.fill,
      ring: p.ring,
      eliminated: !!p.eliminated,
      sessionPoints: p.sessionPoints || 0,
    });
  }
  return rows;
}

function countdownSecondsLeft(now = Date.now()) {
  if (lobbyPhase !== "countdown" || !countdownEndAt) return 0;
  return Math.max(0, Math.ceil((countdownEndAt - now) / 1000));
}

function sendLobbyState(ws = null) {
  const payload = {
    type: "lobby_state",
    phase: lobbyPhase,
    players: publicLobbyPlayers(),
    countdownSeconds: countdownSecondsLeft(),
    match: activeMatch
      ? {
          matchSeed: activeMatch.matchSeed,
          startedAt: activeMatch.startedAt,
        }
      : null,
  };
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(payload));
    return;
  }
  broadcast(payload);
}

function clearCountdownTimer() {
  if (countdownTimer) {
    clearTimeout(countdownTimer);
    countdownTimer = null;
  }
}

function clearPaceTimer() {
  if (paceTimer) {
    clearInterval(paceTimer);
    paceTimer = null;
  }
}

function maybeStartCountdown() {
  if (lobbyPhase === "match") return;
  const ready = clients.size;
  if (ready < 2) {
    if (lobbyPhase === "countdown") {
      lobbyPhase = "waiting";
      countdownEndAt = 0;
      clearCountdownTimer();
      sendLobbyState();
    }
    return;
  }
  if (lobbyPhase === "countdown") return;
  lobbyPhase = "countdown";
  countdownEndAt = Date.now() + COUNTDOWN_MS;
  sendLobbyState();
  clearCountdownTimer();
  countdownTimer = setTimeout(() => {
    countdownTimer = null;
    if (clients.size >= 2 && lobbyPhase === "countdown") {
      startMatch();
    } else {
      lobbyPhase = "waiting";
      countdownEndAt = 0;
      sendLobbyState();
    }
  }, COUNTDOWN_MS);
}

function startMatch() {
  if (clients.size < 2) {
    lobbyPhase = "waiting";
    countdownEndAt = 0;
    sendLobbyState();
    return;
  }

  const matchSeed = Math.floor(Math.random() * 0x7fffffff);
  const playerIds = [...clients.keys()];
  const matchId = `jv-${Date.now().toString(36)}-${matchSeed.toString(36)}`;

  for (const rec of clients.values()) {
    rec.player.height = 0;
    rec.player.playerX = 0;
    rec.player.playerY = 120;
    rec.player.velocityY = 0;
    rec.player.elapsed = 0;
    rec.player.eliminated = false;
    rec.player.sessionPoints = 0;
  }

  prepareJumpVsMatch(playerIds, matchId, matchSeed);

  activeMatch = {
    matchId,
    matchSeed,
    startedAt: Date.now(),
    playerIds: [...playerIds],
  };
  lobbyPhase = "match";
  countdownEndAt = 0;
  clearCountdownTimer();

  broadcast({
    type: "match_start",
    matchSeed,
    matchId,
    startedAt: activeMatch.startedAt,
    players: publicLobbyPlayers(),
  });
  sendLobbyState();

  clearPaceTimer();
  paceTimer = setInterval(checkPaceElimination, PACE_CHECK_MS);
}

function leaderHeight() {
  let max = 0;
  for (const rec of clients.values()) {
    if (rec.player.eliminated) continue;
    max = Math.max(max, Math.floor(Number(rec.player.height) || 0));
  }
  return max;
}

function checkPaceElimination() {
  if (lobbyPhase !== "match" || !activeMatch) return;
  const leader = leaderHeight();
  const leaderTier = Math.floor(leader / MILESTONE_STEP);
  let changed = false;

  for (const [uid, rec] of clients) {
    if (rec.player.eliminated) continue;
    const h = Math.floor(Number(rec.player.height) || 0);
    const tier = Math.floor(h / MILESTONE_STEP);
    if (leaderTier - tier > 1) {
      rec.player.eliminated = true;
      changed = true;
      broadcast({
        type: "eliminated",
        id: uid,
        displayName: rec.player.displayName,
        reason: "pace",
        leaderHeight: leader,
      });
    }
  }

  if (changed) sendLobbyState();
  maybeEndMatch();
}

function aliveCount() {
  let n = 0;
  for (const rec of clients.values()) {
    if (!rec.player.eliminated) n += 1;
  }
  return n;
}

function maybeEndMatch() {
  if (lobbyPhase !== "match" || !activeMatch) return;
  const alive = aliveCount();
  if (alive > 1) return;

  let winnerId = null;
  let winnerHeight = -1;
  for (const [uid, rec] of clients) {
    if (rec.player.eliminated) continue;
    const h = Math.floor(Number(rec.player.height) || 0);
    if (h >= winnerHeight) {
      winnerHeight = h;
      winnerId = uid;
    }
  }

  if (!winnerId) {
    for (const [uid, rec] of clients) {
      const h = Math.floor(Number(rec.player.height) || 0);
      if (h >= winnerHeight) {
        winnerHeight = h;
        winnerId = uid;
      }
    }
  }

  endMatch(winnerId);
}

function endMatch(winnerId) {
  if (!activeMatch) return;
  clearPaceTimer();

  const playerIds = [...activeMatch.playerIds];
  const pot = finalizeJumpVsMatch(winnerId, playerIds, jumpVsCtx?.pointStore);

  const rankings = publicLobbyPlayers().sort((a, b) => (b.height || 0) - (a.height || 0));

  broadcast({
    type: "match_end",
    winnerId,
    pot,
    rankings,
    message:
      pot > 0 && winnerId
        ? `Winner takes ${pot.toLocaleString()} pts from the match pot!`
        : "Match ended.",
  });

  activeMatch = null;
  lobbyPhase = "waiting";
  countdownEndAt = 0;
  sendLobbyState();
  maybeStartCountdown();
}

function removeClient(userId) {
  if (!clients.has(userId)) return;
  const wasInMatch = lobbyPhase === "match" && !!activeMatch;
  clients.delete(userId);
  broadcast({ type: "player_leave", id: userId });
  sendLobbyState();

  if (wasInMatch) {
    maybeEndMatch();
    if (clients.size < 2 && lobbyPhase === "match") {
      const survivor = [...clients.keys()][0] || null;
      endMatch(survivor);
    }
  } else {
    maybeStartCountdown();
  }
}

function handleClientMessage(userId, raw, pointStore) {
  let msg;
  try {
    msg = JSON.parse(String(raw));
  } catch {
    return;
  }
  if (!msg || typeof msg !== "object") return;
  const rec = clients.get(userId);
  if (!rec) return;

  const type = String(msg.type || "");

  if (type === "join") {
    const cosmetics = getJumpPlayerCosmetics(userId);
    rec.player.displayName = String(msg.displayName || rec.player.displayName).slice(0, 40);
    rec.player.skinId = String(msg.skinId || cosmetics.skinId || "classic").slice(0, 32);
    rec.player.fill = String(msg.fill || cosmetics.fill || "#596ff2").slice(0, 16);
    rec.player.ring = String(msg.ring || cosmetics.ring || "#f2c733").slice(0, 16);
    sendLobbyState();
    broadcast(
      {
        type: "player_join",
        player: {
          id: userId,
          displayName: rec.player.displayName,
          skinId: rec.player.skinId,
          fill: rec.player.fill,
          ring: rec.player.ring,
        },
      },
      userId
    );
    return;
  }

  if (type === "progress" && lobbyPhase === "match") {
    const height = Math.max(0, Math.floor(Number(msg.height) || 0));
    const playerX = Number(msg.playerX);
    const playerY = Number(msg.playerY);
    const velocityY = Number(msg.velocityY);
    const elapsed = Math.max(0, Math.floor(Number(msg.elapsed) || 0));
    rec.player.height = height;
    if (Number.isFinite(playerX)) rec.player.playerX = playerX;
    if (Number.isFinite(playerY)) rec.player.playerY = playerY;
    if (Number.isFinite(velocityY)) rec.player.velocityY = velocityY;
    rec.player.elapsed = elapsed;
    if (msg.sessionPoints != null) {
      rec.player.sessionPoints = Math.max(0, Math.floor(Number(msg.sessionPoints) || 0));
    } else {
      rec.player.sessionPoints = syncJumpVsSessionPoints(userId);
    }

    broadcast(
      {
        type: "opponent_progress",
        id: userId,
        displayName: rec.player.displayName,
        height,
        playerX: rec.player.playerX ?? 0,
        playerY: rec.player.playerY ?? height + 80,
        velocityY: rec.player.velocityY ?? 0,
        elapsed: rec.player.elapsed ?? 0,
        skinId: rec.player.skinId,
        fill: rec.player.fill,
        ring: rec.player.ring,
        sessionPoints: rec.player.sessionPoints,
        eliminated: !!rec.player.eliminated,
      },
      userId
    );
    checkPaceElimination();
    return;
  }

  if (type === "forfeit") {
    rec.player.eliminated = true;
    broadcast({ type: "eliminated", id: userId, reason: "forfeit" });
    sendLobbyState();
    maybeEndMatch();
  }
}

function registerJumpVsRoutes(app, ctx) {
  const { validateBearer: validateSession } = ctx;

  app.get("/api/mobile/jump/vs/status", (req, res) => {
    const session = validateSession(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });
    return res.json({
      ok: true,
      phase: lobbyPhase,
      online: clients.size,
      countdownSeconds: countdownSecondsLeft(),
      inMatch: lobbyPhase === "match",
      matchSeed: activeMatch?.matchSeed || null,
      players: publicLobbyPlayers(),
      wsPath: JUMP_VS_WS_PATH,
    });
  });
}

function tryJumpVsUpgrade(request, socket, head, ctx) {
  if (parseUpgradePath(request) !== JUMP_VS_WS_PATH) return false;
  jumpVsCtx = ctx || null;

  const session = sessionFromUpgrade(request);
  if (!session) {
    socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
    socket.destroy();
    return true;
  }

  const { pointStore } = ctx || {};
  const vsWss = new WebSocket.Server({ noServer: true });
  vsWss.handleUpgrade(request, socket, head, (ws) => {
    const userId = session.userId;
    if (clients.has(userId)) {
      try {
        clients.get(userId).ws.close(4000, "replaced");
      } catch {
        /* ignore */
      }
      removeClient(userId);
    }

    if (clients.size >= MAX_LOBBY_PLAYERS) {
      ws.close(1013, "lobby full");
      return;
    }

    const cosmetics = getJumpPlayerCosmetics(userId);
    const player = {
      id: userId,
      displayName: String(session.displayName || userId),
      height: 0,
      playerX: 0,
      playerY: 120,
      velocityY: 0,
      elapsed: 0,
      skinId: cosmetics.skinId,
      fill: cosmetics.fill,
      ring: cosmetics.ring,
      sessionPoints: 0,
      eliminated: false,
    };

    clients.set(userId, { ws, player });

    ws.on("message", (data) => handleClientMessage(userId, data, pointStore));
    ws.on("close", () => removeClient(userId));
    ws.on("error", () => removeClient(userId));

    ws.send(
      JSON.stringify({
        type: "welcome",
        id: userId,
        displayName: player.displayName,
        online: clients.size,
        phase: lobbyPhase,
        matchSeed: activeMatch?.matchSeed || null,
      })
    );
    sendLobbyState(ws);
    maybeStartCountdown();
  });

  return true;
}

module.exports = {
  registerJumpVsRoutes,
  tryJumpVsUpgrade,
  JUMP_VS_WS_PATH,
};
