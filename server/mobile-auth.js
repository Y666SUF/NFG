const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { normalizeUser } = require("./store");
const { getAppRoot } = require("./paths");

const DATA_DIR = path.join(getAppRoot(), "data");
const SESSIONS_FILE = path.join(DATA_DIR, "mobile-sessions.json");
const LINK_CODE_TTL_MS = 10 * 60 * 1000;
const SESSION_TTL_MS = 90 * 24 * 60 * 60 * 1000;

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}

function createEmptyState() {
  return {
    pendingLinks: {},
    sessions: {},
  };
}

function loadState() {
  ensureDataDir();
  if (!fs.existsSync(SESSIONS_FILE)) return createEmptyState();
  try {
    const raw = fs.readFileSync(SESSIONS_FILE, "utf8");
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return createEmptyState();
    return {
      pendingLinks:
        parsed.pendingLinks && typeof parsed.pendingLinks === "object" ? { ...parsed.pendingLinks } : {},
      sessions: parsed.sessions && typeof parsed.sessions === "object" ? { ...parsed.sessions } : {},
    };
  } catch {
    return createEmptyState();
  }
}

let state = loadState();

function saveState() {
  ensureDataDir();
  fs.writeFileSync(SESSIONS_FILE, JSON.stringify(state, null, 2), "utf8");
}

function newLinkCode() {
  return crypto.randomBytes(3).toString("hex").toUpperCase();
}

function newSessionToken() {
  return crypto.randomBytes(32).toString("hex");
}

function nowMs() {
  return Date.now();
}

function pruneExpired() {
  const now = nowMs();
  let changed = false;

  for (const [code, rec] of Object.entries(state.pendingLinks)) {
    const expiresAt = Number(rec && rec.expiresAt) || 0;
    if (expiresAt > 0 && expiresAt > now) continue;
    delete state.pendingLinks[code];
    changed = true;
  }

  for (const [token, rec] of Object.entries(state.sessions)) {
    const expiresAt = Number(rec && rec.expiresAt) || 0;
    if (expiresAt > 0 && expiresAt > now) continue;
    delete state.sessions[token];
    changed = true;
  }

  if (changed) saveState();
}

function parseBearer(req) {
  const auth = String(req.headers.authorization || "").trim();
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m ? String(m[1] || "").trim() : "";
}

function validateBearer(req) {
  pruneExpired();
  const token = parseBearer(req);
  if (!token) return { ok: false, error: "auth_required" };
  const session = state.sessions[token];
  if (!session) return { ok: false, error: "auth_required" };
  const now = nowMs();
  if ((Number(session.expiresAt) || 0) <= now) {
    delete state.sessions[token];
    saveState();
    return { ok: false, error: "auth_required" };
  }
  session.lastSeenAt = now;
  saveState();
  return {
    ok: true,
    token,
    session: {
      token,
      userId: normalizeUser(session.userId),
      displayName: String(session.displayName || session.userId || ""),
      deviceId: String(session.deviceId || ""),
      issuedAt: Number(session.issuedAt) || 0,
      linkedAt: Number(session.linkedAt) || 0,
      lastSeenAt: Number(session.lastSeenAt) || now,
      expiresAt: Number(session.expiresAt) || 0,
    },
  };
}

function completeLinkFromTikTok(userId, displayName, message) {
  pruneExpired();
  const text = String(message || "").trim();
  const m = text.match(/^!link\s+([a-fA-F0-9]{6})\s*$/i);
  if (!m) return { handled: false };

  const code = String(m[1] || "").toUpperCase();
  const pending = state.pendingLinks[code];
  if (!pending) {
    return {
      handled: true,
      linked: false,
      tiktokChatReply: `Invalid or expired link code ${code}. Open the iOS app and generate a new one.`,
    };
  }
  const now = nowMs();
  if ((Number(pending.expiresAt) || 0) <= now) {
    delete state.pendingLinks[code];
    saveState();
    return {
      handled: true,
      linked: false,
      tiktokChatReply: `Link code ${code} expired. Generate a new code in the iOS app.`,
    };
  }

  const normalizedUser = normalizeUser(userId);
  if (!normalizedUser) {
    return {
      handled: true,
      linked: false,
      tiktokChatReply: "Could not link account. TikTok user id missing.",
    };
  }

  const token = newSessionToken();
  const expiresAt = now + SESSION_TTL_MS;
  state.sessions[token] = {
    token,
    deviceId: String(pending.deviceId || ""),
    userId: normalizedUser,
    displayName: String(displayName || normalizedUser),
    issuedAt: now,
    linkedAt: now,
    lastSeenAt: now,
    expiresAt,
  };

  state.pendingLinks[code] = {
    ...pending,
    status: "linked",
    userId: normalizedUser,
    displayName: String(displayName || normalizedUser),
    linkedAt: now,
    token,
    expiresAt: pending.expiresAt,
  };
  saveState();
  return {
    handled: true,
    linked: true,
    code,
    token,
    userId: normalizedUser,
    tiktokChatReply: `Linked successfully for @${normalizedUser}. Return to your iOS app.`,
  };
}

function registerMobileAuthRoutes(app) {
  app.post("/api/mobile/link/start", (req, res) => {
    pruneExpired();
    const deviceId = String(req.body?.deviceId || "").trim().slice(0, 200);
    if (!deviceId) return res.status(400).json({ ok: false, error: "deviceId required" });

    const now = nowMs();
    const stillActive = Object.entries(state.pendingLinks).find(([, rec]) => {
      if (!rec || rec.status === "linked") return false;
      if (String(rec.deviceId || "") !== deviceId) return false;
      return (Number(rec.expiresAt) || 0) > now;
    });

    let code;
    let expiresAt;
    if (stillActive) {
      code = stillActive[0];
      expiresAt = Number(stillActive[1].expiresAt) || now + LINK_CODE_TTL_MS;
    } else {
      do {
        code = newLinkCode();
      } while (state.pendingLinks[code]);
      expiresAt = now + LINK_CODE_TTL_MS;
      state.pendingLinks[code] = {
        code,
        status: "pending",
        deviceId,
        createdAt: now,
        expiresAt,
      };
      saveState();
    }

    res.json({
      ok: true,
      code,
      expiresInSeconds: Math.max(1, Math.ceil((expiresAt - now) / 1000)),
      tiktokCommand: `!link ${code}`,
    });
  });

  app.get("/api/mobile/link/status/:code", (req, res) => {
    pruneExpired();
    const code = String(req.params.code || "").trim().toUpperCase();
    const rec = state.pendingLinks[code];
    if (!rec) return res.json({ ok: true, status: "expired_or_unknown" });
    const now = nowMs();
    if ((Number(rec.expiresAt) || 0) <= now) {
      delete state.pendingLinks[code];
      saveState();
      return res.json({ ok: true, status: "expired_or_unknown" });
    }
    if (String(rec.status || "") === "linked" && rec.token && rec.userId) {
      return res.json({
        ok: true,
        status: "linked",
        token: String(rec.token),
        userId: normalizeUser(rec.userId),
      });
    }
    return res.json({
      ok: true,
      status: "pending",
      expiresInSeconds: Math.max(1, Math.ceil((Number(rec.expiresAt) - now) / 1000)),
    });
  });

  app.get("/api/mobile/session", (req, res) => {
    const auth = validateBearer(req);
    if (!auth.ok) return res.status(401).json({ ok: false, error: "auth_required" });
    res.json({ ok: true, session: auth.session });
  });

  app.post("/api/mobile/session/logout", (req, res) => {
    const auth = validateBearer(req);
    if (!auth.ok) return res.status(401).json({ ok: false, error: "auth_required" });
    delete state.sessions[auth.token];
    saveState();
    res.json({ ok: true, loggedOut: true });
  });
}

function validateBearerSession(req) {
  const auth = validateBearer(req);
  return auth && auth.ok ? auth.session : null;
}

module.exports = {
  registerMobileAuthRoutes,
  completeLinkFromTikTok,
  validateBearer,
  validateBearerSession,
};

