const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { normalizeUser } = require("./store");
const { getAppRoot } = require("./paths");
const { mergeArcadeUserRecords } = require("./mobile-arcade");

const DATA_DIR = path.join(getAppRoot(), "data");
const SESSIONS_FILE = path.join(DATA_DIR, "mobile-sessions.json");
const LINK_CODE_TTL_MS = 10 * 60 * 1000;
const SESSION_TTL_MS = 365 * 24 * 60 * 60 * 1000;
const APP_GUEST_DISPLAY_NAME = "App User";

let _pointStore = null;

const APP_REVIEW_USER_ID = "apple_app_review";
const APP_REVIEW_DISPLAY_NAME = "Apple Review";
const APP_REVIEW_BALANCE = 200_000;

function expectedAppReviewCode() {
  const raw = process.env.MOBILE_APP_REVIEW_CODE;
  if (raw != null && String(raw).trim() !== "") return String(raw).trim();
  return "Spice!1994";
}

function registerAppReviewSession(deviceId) {
  pruneExpired();
  const now = nowMs();
  const token = newSessionToken();
  const expiresAt = now + SESSION_TTL_MS;
  state.sessions[token] = {
    token,
    deviceId: String(deviceId || "").trim().slice(0, 200),
    userId: APP_REVIEW_USER_ID,
    displayName: APP_REVIEW_DISPLAY_NAME,
    issuedAt: now,
    linkedAt: now,
    lastSeenAt: now,
    expiresAt,
    linkedVia: "app_review",
  };
  saveState();
  return token;
}

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}

function createEmptyState() {
  return {
    pendingLinks: {},
    sessions: {},
    deviceLinks: {},
  };
}

function loadState() {
  ensureDataDir();
  if (!fs.existsSync(SESSIONS_FILE)) return createEmptyState();
  try {
    const raw = fs.readFileSync(SESSIONS_FILE, "utf8");
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return createEmptyState();
    const state = {
      pendingLinks:
        parsed.pendingLinks && typeof parsed.pendingLinks === "object" ? { ...parsed.pendingLinks } : {},
      sessions: parsed.sessions && typeof parsed.sessions === "object" ? { ...parsed.sessions } : {},
      deviceLinks:
        parsed.deviceLinks && typeof parsed.deviceLinks === "object" ? { ...parsed.deviceLinks } : {},
    };
    migrateDeviceLinksFromSessions(state);
    return state;
  } catch {
    return createEmptyState();
  }
}

/** Backfill durable device→TikTok bindings from existing sessions / completed links. */
function migrateDeviceLinksFromSessions(targetState) {
  if (!targetState.deviceLinks) targetState.deviceLinks = {};
  let changed = false;
  for (const rec of Object.values(targetState.sessions || {})) {
    if (String(rec.linkedVia || "") !== "tiktok") continue;
    const deviceId = String(rec.deviceId || "").trim();
    const userId = normalizeUser(rec.userId);
    if (!deviceId || !userId) continue;
    if (targetState.deviceLinks[deviceId]?.userId === userId) continue;
    targetState.deviceLinks[deviceId] = {
      userId,
      displayName: String(rec.displayName || userId),
      linkedAt: Number(rec.linkedAt) || Number(rec.issuedAt) || nowMs(),
      linkedVia: "tiktok",
    };
    changed = true;
  }
  for (const rec of Object.values(targetState.pendingLinks || {})) {
    if (String(rec.status || "") !== "linked") continue;
    const deviceId = String(rec.deviceId || "").trim();
    const userId = normalizeUser(rec.userId);
    if (!deviceId || !userId) continue;
    if (targetState.deviceLinks[deviceId]?.userId === userId) continue;
    targetState.deviceLinks[deviceId] = {
      userId,
      displayName: String(rec.displayName || userId),
      linkedAt: Number(rec.linkedAt) || nowMs(),
      linkedVia: "tiktok",
    };
    changed = true;
  }
  if (changed) saveStateFrom(targetState);
}

function saveStateFrom(targetState) {
  ensureDataDir();
  fs.writeFileSync(SESSIONS_FILE, JSON.stringify(targetState, null, 2), "utf8");
}

let state = loadState();
migrateDeviceLinksFromSessions(state);

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

function saveDeviceLink(deviceId, userId, displayName) {
  const id = String(deviceId || "").trim().slice(0, 200);
  const uid = normalizeUser(userId);
  if (!id || !uid) return;
  if (!state.deviceLinks) state.deviceLinks = {};
  state.deviceLinks[id] = {
    userId: uid,
    displayName: String(displayName || uid),
    linkedAt: nowMs(),
    linkedVia: "tiktok",
  };
  saveState();
}

function clearDeviceLink(deviceId) {
  const id = String(deviceId || "").trim().slice(0, 200);
  if (!id || !state.deviceLinks || !state.deviceLinks[id]) return;
  delete state.deviceLinks[id];
  saveState();
}

function clearDeviceSessions(deviceId, exceptToken = null) {
  const id = String(deviceId || "");
  if (!id) return;
  let changed = false;
  for (const [token, rec] of Object.entries(state.sessions)) {
    if (String(rec.deviceId || "") !== id) continue;
    if (exceptToken && token === exceptToken) continue;
    delete state.sessions[token];
    changed = true;
  }
  if (changed) saveState();
}

function sessionPriority(rec) {
  const via = String(rec.linkedVia || "");
  if (via === "tiktok") return 3;
  if (via === "app_review") return 2;
  if (via === "app_guest") return 0;
  return 1;
}

function issueTikTokSession(deviceId, userId, displayName, opts = {}) {
  const now = nowMs();
  clearDeviceSessions(deviceId);
  const token = newSessionToken();
  const uid = normalizeUser(userId);
  state.sessions[token] = {
    token,
    deviceId: String(deviceId || "").trim().slice(0, 200),
    userId: uid,
    displayName: String(displayName || uid),
    linkedVia: "tiktok",
    issuedAt: now,
    linkedAt: Number(opts.linkedAt) || now,
    lastSeenAt: now,
    expiresAt: now + SESSION_TTL_MS,
  };
  saveState();
  return token;
}

function appUserIdFromDevice(deviceId) {
  const hash = crypto.createHash("sha256").update(String(deviceId || "")).digest("hex").slice(0, 16);
  return hash ? `appuser_${hash}` : "";
}

function isAppGuestUserId(userId) {
  return String(userId || "").toLowerCase().startsWith("appuser_");
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

function sessionPayload(session, token, now) {
  return {
    token,
    userId: normalizeUser(session.userId),
    displayName: String(session.displayName || session.userId || ""),
    deviceId: String(session.deviceId || ""),
    linkedVia: String(session.linkedVia || ""),
    issuedAt: Number(session.issuedAt) || 0,
    linkedAt: Number(session.linkedAt) || 0,
    lastSeenAt: Number(session.lastSeenAt) || now,
    expiresAt: Number(session.expiresAt) || 0,
  };
}

function findValidSessionForDevice(deviceId) {
  const now = nowMs();
  let guest = null;
  let linked = null;
  let fallback = null;
  for (const [token, rec] of Object.entries(state.sessions)) {
    if (String(rec.deviceId || "") !== deviceId) continue;
    if ((Number(rec.expiresAt) || 0) <= now) continue;
    const via = String(rec.linkedVia || "");
    const entry = { token, rec };
    if (via === "tiktok") linked = entry;
    else if (via === "app_guest" || isAppGuestUserId(rec.userId)) guest = entry;
    else if (!fallback) fallback = entry;
  }
  return linked || guest || fallback;
}

function deviceLinkFor(deviceId) {
  const id = String(deviceId || "").trim();
  if (!id) return null;
  const rec = state.deviceLinks[id];
  if (!rec || String(rec.linkedVia || "") !== "tiktok") return null;
  const userId = normalizeUser(rec.userId);
  if (!userId || isAppGuestUserId(userId)) return null;
  return {
    userId,
    displayName: String(rec.displayName || userId),
    linkedAt: Number(rec.linkedAt) || 0,
  };
}

function displayNameForUser(userId, fallback = "") {
  const uid = normalizeUser(userId);
  if (!uid) return String(fallback || "");
  if (_pointStore && typeof _pointStore.getDisplayName === "function") {
    const fromStore = String(_pointStore.getDisplayName(uid) || "").trim();
    if (fromStore) return fromStore;
  }
  const cleaned = String(fallback || "").trim();
  return cleaned || uid;
}

function issueSession(deviceId, userId, displayName, linkedVia, linkedAt = 0) {
  const now = nowMs();
  const token = newSessionToken();
  const uid = normalizeUser(userId);
  clearDeviceSessions(deviceId);
  state.sessions[token] = {
    token,
    deviceId: String(deviceId || "").trim().slice(0, 200),
    userId: uid,
    displayName: String(displayName || uid),
    linkedVia: String(linkedVia || ""),
    issuedAt: now,
    linkedAt: linkedAt > 0 ? linkedAt : linkedVia === "tiktok" ? now : 0,
    lastSeenAt: now,
    expiresAt: now + SESSION_TTL_MS,
  };
  saveState();
  return { token, userId: uid, displayName: String(displayName || uid), linkedVia: String(linkedVia || "") };
}

function restoreTikTokSessionForDevice(deviceId, claimUserId = "") {
  const binding = deviceLinkFor(deviceId);
  if (!binding) return null;
  const claim = normalizeUser(claimUserId);
  if (claim && claim !== binding.userId) return null;
  const displayName = displayNameForUser(binding.userId, binding.displayName);
  return issueSession(deviceId, binding.userId, displayName, "tiktok", binding.linkedAt || 0);
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
  session.expiresAt = now + SESSION_TTL_MS;
  saveState();
  return {
    ok: true,
    token,
    session: sessionPayload(session, token, now),
  };
}

function mergeGuestIntoTikTok(guestUserId, tiktokUserId, tiktokDisplayName) {
  const guest = normalizeUser(guestUserId);
  const tiktok = normalizeUser(tiktokUserId);
  if (!guest || !tiktok || guest === tiktok) return { ok: false, reason: "invalid_merge" };
  let accountMerge = { ok: false };
  if (_pointStore) {
    accountMerge = _pointStore.mergeUserAccounts(guest, tiktok, "tiktok_link");
    _pointStore.setDisplayName(tiktok, tiktokDisplayName);
    _pointStore.updateRank(tiktok);
  }
  const arcadeMerge = mergeArcadeUserRecords(guest, tiktok, _pointStore);
  for (const [tok, rec] of Object.entries(state.sessions)) {
    if (normalizeUser(rec.userId) === guest) delete state.sessions[tok];
  }
  return { ok: true, accountMerge, arcadeMerge, guest, tiktok };
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

  const deviceId = String(pending.deviceId || "");
  const tiktokDisplayName = String(displayName || normalizedUser);
  let guestUserId = "";
  for (const rec of Object.values(state.sessions)) {
    if (String(rec.deviceId || "") !== deviceId) continue;
    const uid = normalizeUser(rec.userId);
    if (rec.linkedVia === "app_guest" || isAppGuestUserId(uid)) {
      guestUserId = uid;
      break;
    }
  }
  if (!guestUserId && deviceId) {
    guestUserId = appUserIdFromDevice(deviceId);
  }
  let mergeResult = null;
  if (guestUserId && guestUserId !== normalizedUser) {
    mergeResult = mergeGuestIntoTikTok(guestUserId, normalizedUser, tiktokDisplayName);
  } else if (_pointStore) {
    _pointStore.setDisplayName(normalizedUser, tiktokDisplayName);
  }

  const token = newSessionToken();
  const expiresAt = now + SESSION_TTL_MS;
  clearDeviceSessions(deviceId);
  state.sessions[token] = {
    token,
    deviceId,
    userId: normalizedUser,
    displayName: tiktokDisplayName,
    linkedVia: "tiktok",
    issuedAt: now,
    linkedAt: now,
    lastSeenAt: now,
    expiresAt,
  };
  saveDeviceLink(deviceId, normalizedUser, tiktokDisplayName);

  state.pendingLinks[code] = {
    ...pending,
    status: "linked",
    userId: normalizedUser,
    displayName: tiktokDisplayName,
    linkedAt: now,
    token,
    expiresAt: pending.expiresAt,
    merge: mergeResult?.accountMerge?.ok
      ? {
          combinedBalance: mergeResult.accountMerge.mergedBalance,
          mergedLevel: mergeResult.accountMerge.mergedLevel,
        }
      : null,
  };
  saveState();
  const mergedBalance = mergeResult?.accountMerge?.mergedBalance;
  const mergeNote =
    mergedBalance != null
      ? ` Merged app + TikTok progress — balance now ${mergedBalance.toLocaleString()} pts.`
      : "";
  return {
    handled: true,
    linked: true,
    code,
    token,
    userId: normalizedUser,
    merge: mergeResult,
    tiktokChatReply: `Linked successfully for @${normalizedUser}.${mergeNote} Return to your iOS app.`,
  };
}

function registerMobileAuthRoutes(app, ctx = {}) {
  _pointStore = ctx.pointStore || null;
  const getTikTokBridgeStatus =
    typeof ctx.getTikTokBridgeStatus === "function" ? ctx.getTikTokBridgeStatus : null;

  app.get("/api/mobile/link/health", (_req, res) => {
    pruneExpired();
    const bridge = getTikTokBridgeStatus ? getTikTokBridgeStatus() : null;
    res.json({
      ok: true,
      linkStart: true,
      linkStatus: true,
      pendingLinks: Object.keys(state.pendingLinks || {}).length,
      tiktokBridge: bridge
        ? {
            enabled: bridge.enabled !== false,
            state: String(bridge.state || "unknown"),
            uniqueId: String(bridge.uniqueId || "y666.suf"),
            isLive: bridge.state === "live",
          }
        : { enabled: false, state: "unknown", uniqueId: "y666.suf", isLive: false },
      message: "TikTok link routes are active. Comment !link CODE on live to complete linking.",
    });
  });

  app.post("/api/mobile/auth/app-review", (req, res) => {
    pruneExpired();
    const body = req.body && typeof req.body === "object" ? req.body : {};
    const deviceId = String(body.deviceId || "").trim().slice(0, 200);
    const code = String(body.code || "").trim();

    if (!deviceId) {
      return res.status(400).json({ ok: false, error: "deviceId required" });
    }
    if (!code) {
      return res.status(400).json({
        ok: false,
        error: "code required",
        message: "Enter the review password.",
      });
    }
    if (code !== expectedAppReviewCode()) {
      return res.status(401).json({
        ok: false,
        error: "invalid_code",
        message: "Invalid review password.",
      });
    }

    const userId = APP_REVIEW_USER_ID;
    if (_pointStore) {
      if (typeof _pointStore.ensureAccount === "function") _pointStore.ensureAccount(userId);
      if (typeof _pointStore.setBalance === "function") {
        _pointStore.setBalance(userId, APP_REVIEW_BALANCE);
      }
      if (typeof _pointStore.setDisplayName === "function") {
        _pointStore.setDisplayName(userId, APP_REVIEW_DISPLAY_NAME);
      }
    }

    const token = registerAppReviewSession(deviceId);
    const balance =
      _pointStore && typeof _pointStore.getBalance === "function"
        ? _pointStore.getBalance(userId)
        : APP_REVIEW_BALANCE;

    return res.json({
      ok: true,
      token,
      userId: APP_REVIEW_USER_ID,
      displayName: APP_REVIEW_DISPLAY_NAME,
      balance,
      purpose: "app_review",
      linkedVia: "app_review",
      message: "Signed in to the App Review test account.",
    });
  });

  app.post("/api/mobile/auth/app-guest", (req, res) => {
    pruneExpired();
    const body = req.body && typeof req.body === "object" ? req.body : {};
    const deviceId = String(body.deviceId || req.headers["x-device-id"] || "")
      .trim()
      .slice(0, 200);
    if (!deviceId) return res.status(400).json({ ok: false, error: "deviceId required" });

    const claimUserId = body.claimUserId ? normalizeUser(body.claimUserId) : "";
    const existing = findValidSessionForDevice(deviceId);
    if (existing) {
      const rec = existing.rec;
      const userId = normalizeUser(rec.userId);
      const balance = _pointStore ? _pointStore.getBalance(userId) : 0;
      return res.json({
        ok: true,
        token: existing.token,
        userId,
        displayName: String(rec.displayName || APP_GUEST_DISPLAY_NAME),
        linkedVia: String(rec.linkedVia || (isAppGuestUserId(userId) ? "app_guest" : "tiktok")),
        starterGranted: false,
        balance,
        restored: false,
      });
    }

    const restored = restoreTikTokSessionForDevice(deviceId, claimUserId);
    if (restored) {
      const balance = _pointStore ? _pointStore.getBalance(restored.userId) : 0;
      return res.json({
        ok: true,
        token: restored.token,
        userId: restored.userId,
        displayName: restored.displayName,
        linkedVia: "tiktok",
        starterGranted: false,
        balance,
        restored: true,
      });
    }

    if (claimUserId) {
      const binding = deviceLinkFor(deviceId);
      if (binding && binding.userId === claimUserId) {
        const again = restoreTikTokSessionForDevice(deviceId, claimUserId);
        if (again) {
          const balance = _pointStore ? _pointStore.getBalance(again.userId) : 0;
          return res.json({
            ok: true,
            token: again.token,
            userId: again.userId,
            displayName: again.displayName,
            linkedVia: "tiktok",
            starterGranted: false,
            balance,
            restored: true,
          });
        }
      }
    }

    const userId = appUserIdFromDevice(deviceId);
    if (!userId) return res.status(400).json({ ok: false, error: "invalid deviceId" });

    let starterGranted = false;
    let balance = 0;
    if (_pointStore) {
      const wasNew = _pointStore.points.balances[userId] == null;
      balance = _pointStore.ensureAppGuestAccount(userId);
      starterGranted = wasNew;
    }

    clearDeviceSessions(deviceId);
    const token = newSessionToken();
    clearDeviceSessions(deviceId);
    state.sessions[token] = {
      token,
      deviceId,
      userId,
      displayName: APP_GUEST_DISPLAY_NAME,
      linkedVia: "app_guest",
      issuedAt: now,
      linkedAt: 0,
      lastSeenAt: now,
      expiresAt: now + SESSION_TTL_MS,
    };
    saveState();

    res.json({
      ok: true,
      token,
      userId,
      displayName: APP_GUEST_DISPLAY_NAME,
      linkedVia: "app_guest",
      starterGranted,
      balance,
      restored: false,
    });
  });

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
        displayName: String(rec.displayName || rec.userId || ""),
        merge: rec.merge || null,
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
    const body = req.body && typeof req.body === "object" ? req.body : {};
    const explicitUnlink = body.unlink === true || body.unlink === "true";
    const deviceId = String(
      (auth.ok && auth.session && auth.session.deviceId) ||
        body.deviceId ||
        req.headers["x-device-id"] ||
        ""
    ).trim();
    if (auth.ok) {
      delete state.sessions[auth.token];
    }
    if (deviceId) {
      clearDeviceSessions(deviceId);
      if (explicitUnlink) {
        clearDeviceLink(deviceId);
      }
    } else if (auth.ok) {
      saveState();
    }
    res.json({ ok: true, loggedOut: true, unlinked: explicitUnlink });
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
