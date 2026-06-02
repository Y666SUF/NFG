/**
 * NFG Tower World — native iOS multiplayer plaza (WebSocket on same Node port as Crash).
 */
const WebSocket = require("ws");
const { validateBearer } = require("./mobile-auth");
const { getPublicTowerHero } = require("./mobile-arcade");

const TOWER_WS_PATH = "/api/mobile/tower/world/ws";
const MAX_PLAYERS = 32;
const CHAT_COOLDOWN_MS = 800;

/** @type {Map<string, { ws: import('ws'), player: object, lastChatAt: number }>} */
const clients = new Map();

function parseUpgradePath(request) {
  try {
    return new URL(request.url || "/", "http://localhost").pathname;
  } catch {
    return String(request.url || "/").split("?")[0] || "/";
  }
}

function sessionFromUpgrade(request) {
  const auth = validateBearer({ headers: request.headers });
  return auth.ok ? auth.session : null;
}

function clampCoord(v, fallback = 0) {
  const n = Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(-18, Math.min(18, n));
}

function normalizeAppearance(raw) {
  const a = raw && typeof raw === "object" ? raw : {};
  return {
    bodyStyle: String(a.bodyStyle || "male"),
    skinTone: Math.max(0, Math.min(5, Math.floor(Number(a.skinTone) || 2))),
    hairStyle: Math.max(0, Math.min(5, Math.floor(Number(a.hairStyle) || 1))),
    hairColor: Math.max(0, Math.min(5, Math.floor(Number(a.hairColor) || 3))),
    beard: !!a.beard,
    heroName: String(a.heroName || "").slice(0, 32),
    created: true,
  };
}

function normalizeEquipment(raw) {
  const e = raw && typeof raw === "object" ? raw : {};
  const slot = (key, fallback) => String(e[key] || fallback).slice(0, 64);
  return {
    head: slot("head", "cloth_hood"),
    body: slot("body", "gambler_tunic"),
    legs: slot("legs", "worn_trousers"),
    shield: slot("shield", "chip_buckler"),
    weapon: slot("weapon", "rusty_dagger"),
    cape: slot("cape", "novice_cloak"),
  };
}

function publicPlayer(rec) {
  const p = rec.player;
  return {
    id: p.id,
    userId: p.id,
    displayName: p.displayName,
    x: p.x,
    y: p.y,
    z: p.z,
    rotY: p.rotY,
    appearance: p.appearance,
    equipment: p.equipment,
  };
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

function sendSnapshot(ws) {
  const players = [];
  for (const rec of clients.values()) {
    players.push(publicPlayer(rec));
  }
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: "snapshot", players }));
  }
}

function removeClient(userId) {
  if (!clients.has(userId)) return;
  clients.delete(userId);
  broadcast({ type: "player_leave", id: userId });
}

function handleClientMessage(userId, raw) {
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

  if (type === "move") {
    rec.player.x = clampCoord(msg.x, rec.player.x);
    rec.player.y = Math.max(0.35, Math.min(1.2, Number(msg.y) || rec.player.y));
    rec.player.z = clampCoord(msg.z, rec.player.z);
    rec.player.rotY = Number(msg.rotY) || 0;
    broadcast(
      {
        type: "move",
        id: userId,
        x: rec.player.x,
        y: rec.player.y,
        z: rec.player.z,
        rotY: rec.player.rotY,
        seq: msg.seq,
      },
      userId
    );
    return;
  }

  if (type === "chat") {
    const text = String(msg.text || "")
      .trim()
      .slice(0, 120);
    if (!text) return;
    const now = Date.now();
    if (now - (rec.lastChatAt || 0) < CHAT_COOLDOWN_MS) return;
    rec.lastChatAt = now;
    broadcast({
      type: "chat",
      id: userId,
      displayName: rec.player.displayName,
      text,
    });
  }
}

function registerTowerWorldRoutes(app, ctx) {
  const { validateBearer: validateSession, pointStore } = ctx;

  app.get("/api/mobile/tower/world/profile", (req, res) => {
    const session = validateSession(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    const profile = pointStore.getUserPresentation
      ? pointStore.getUserPresentation(session.userId)
      : { displayName: session.displayName };

    const towerHero = getPublicTowerHero(session.userId);
    const displayName =
      String(profile?.displayName || session.displayName || session.userId || "").trim() ||
      session.userId;

    if (!towerHero) {
      return res.json({
        ok: true,
        userId: session.userId,
        displayName,
        hero: null,
        message: "Customize your tower hero in NFG Tower first.",
      });
    }

    return res.json({
      ok: true,
      userId: session.userId,
      displayName,
      hero: {
        level: towerHero.level,
        heroName: towerHero.heroName,
        appearance: towerHero.appearance,
        equipment: towerHero.equipment,
        visuals: towerHero.visuals,
      },
    });
  });
}

/**
 * Returns true if this upgrade was handled (Tower World WS).
 */
function tryTowerWorldUpgrade(request, socket, head) {
  if (parseUpgradePath(request) !== TOWER_WS_PATH) return false;

  const session = sessionFromUpgrade(request);
  if (!session) {
    socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
    socket.destroy();
    return true;
  }

  const towerWss = new WebSocket.Server({ noServer: true });
  towerWss.handleUpgrade(request, socket, head, (ws) => {
    const userId = session.userId;
    if (clients.has(userId)) {
      try {
        clients.get(userId).ws.close(4000, "replaced");
      } catch {
        /* ignore */
      }
      removeClient(userId);
    }

    if (clients.size >= MAX_PLAYERS) {
      ws.close(1013, "plaza full");
      return;
    }

    const savedHero = getPublicTowerHero(userId);
    const player = {
      id: userId,
      displayName: String(session.displayName || userId),
      x: 0,
      y: 0.45,
      z: 0,
      rotY: 0,
      appearance: savedHero?.appearance || normalizeAppearance({}),
      equipment: savedHero?.equipment || normalizeEquipment({}),
    };

    clients.set(userId, { ws, player, lastChatAt: 0 });

    ws.on("message", (data) => {
      let msg;
      try {
        msg = JSON.parse(String(data));
      } catch {
        return;
      }
      if (!msg || typeof msg !== "object") return;

      if (msg.type === "join") {
        const rec = clients.get(userId);
        if (!rec) return;
        rec.player.displayName = String(msg.displayName || rec.player.displayName).slice(0, 40);
        rec.player.x = clampCoord(msg.x, 0);
        rec.player.y = Math.max(0.35, Math.min(1.2, Number(msg.y) || 0.45));
        rec.player.z = clampCoord(msg.z, 0);
        rec.player.rotY = Number(msg.rotY) || 0;
        if (msg.appearance) rec.player.appearance = normalizeAppearance(msg.appearance);
        if (msg.equipment) rec.player.equipment = normalizeEquipment(msg.equipment);
        sendSnapshot(ws);
        broadcast({ type: "player_join", player: publicPlayer(rec) }, userId);
        return;
      }

      handleClientMessage(userId, data);
    });

    ws.on("close", () => removeClient(userId));
    ws.on("error", () => removeClient(userId));

    ws.send(
      JSON.stringify({
        type: "welcome",
        id: userId,
        displayName: player.displayName,
        online: clients.size,
      })
    );
  });

  return true;
}

module.exports = {
  registerTowerWorldRoutes,
  tryTowerWorldUpgrade,
  TOWER_WS_PATH,
};
