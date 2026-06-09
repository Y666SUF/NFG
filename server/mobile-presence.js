/**
 * Tracks iOS app users currently active (heartbeat within TTL).
 */
const { playerBadgesFromStore } = require("./mobile-player-badges");
const { appLabelFromClientApp, chatDisplayName } = require("./mobile-app-labels");

const PRESENCE_TTL_MS = 90_000;
const presenceByKey = new Map();

function presenceKey(userId, deviceId) {
  if (userId) return `user:${String(userId).toLowerCase()}`;
  if (deviceId) return `device:${String(deviceId).trim()}`;
  return null;
}

function guestDisplayName(deviceId) {
  const id = String(deviceId || "").trim();
  if (!id) return "Guest (not linked)";
  return `Guest ···${id.slice(-4)}`;
}

function pruneStale() {
  const cutoff = Date.now() - PRESENCE_TTL_MS;
  for (const [key, row] of presenceByKey) {
    if (!row.lastSeen || row.lastSeen < cutoff) presenceByKey.delete(key);
  }
}

function touchPresence(key, meta = {}) {
  if (!key) return;
  const prev = presenceByKey.get(key) || {};
  const clientApp = String(meta.clientApp || prev.clientApp || "nfg").trim().slice(0, 32) || "nfg";
  presenceByKey.set(key, {
    userId: meta.userId || prev.userId || null,
    displayName: meta.displayName || prev.displayName || null,
    deviceId: meta.deviceId || prev.deviceId || null,
    clientApp,
    appLabel: appLabelFromClientApp(clientApp),
    lastSeen: Date.now(),
  });
  pruneStale();
}

function getActiveAppUserCount() {
  pruneStale();
  return presenceByKey.size;
}

function getActiveAppUserList(pointStore) {
  pruneStale();
  const rows = [];
  for (const [key, row] of presenceByKey) {
    const linked = !!row.userId;
    const deviceId = row.deviceId || (key.startsWith("device:") ? key.slice(7) : null);
    const userId = linked ? String(row.userId).toLowerCase() : `guest:${deviceId || key}`;
    const displayName = linked
      ? chatDisplayName(pointStore, row.userId, row.displayName)
      : guestDisplayName(deviceId);
    const clientApp = row.clientApp || "nfg";
    const entry = {
      userId,
      displayName,
      username: linked ? String(row.userId).toLowerCase() : null,
      isGuest: !linked,
      clientApp,
      appLabel: row.appLabel || appLabelFromClientApp(clientApp),
    };
    if (linked) {
      Object.assign(entry, playerBadgesFromStore(pointStore, row.userId));
    } else {
      Object.assign(entry, {
        superFan: false,
        superFanLevel: 0,
        nameStyle: "none",
        nameBadge: "none",
      });
    }
    rows.push(entry);
  }
  rows.sort((a, b) =>
    String(a.displayName || "").localeCompare(String(b.displayName || ""), undefined, {
      sensitivity: "base",
    })
  );
  return rows;
}

function presencePayload(pointStore) {
  const users = getActiveAppUserList(pointStore);
  return {
    activeAppUsers: users.length,
    activeAppUserList: users,
  };
}

function registerMobilePresenceRoutes(app, ctx) {
  const { validateBearer, pointStore, broadcast } = ctx;

  app.get("/api/mobile/presence/active", (_req, res) => {
    res.json({ ok: true, ...presencePayload(pointStore) });
  });

  app.post("/api/mobile/presence/heartbeat", (req, res) => {
    const session = typeof validateBearer === "function" ? validateBearer(req) : null;
    const deviceId = String(req.headers["x-device-id"] || req.body?.deviceId || "").trim();
    const clientApp = String(req.headers["x-client-app"] || req.body?.clientApp || "nfg").trim().slice(0, 32);
    const key = presenceKey(session?.userId, deviceId);
    if (!key) {
      return res.status(400).json({
        ok: false,
        error: "device_required",
        message: "Send X-Device-Id header or deviceId in body.",
      });
    }
    touchPresence(key, {
      userId: session?.userId || null,
      displayName: session?.userId
        ? chatDisplayName(pointStore, session.userId, session.displayName)
        : null,
      deviceId: deviceId || null,
      clientApp: clientApp || "nfg",
    });
    const payload = presencePayload(pointStore);
    if (typeof broadcast === "function") {
      broadcast({ type: "presence_update", payload });
    }
    res.json({ ok: true, ...payload });
  });
}

module.exports = {
  registerMobilePresenceRoutes,
  getActiveAppUserCount,
  getActiveAppUserList,
  presencePayload,
};
