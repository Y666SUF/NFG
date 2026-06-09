/**
 * Host-only mobile game admin (default: y666.suf) — leaderboard wipe + player inventory edits.
 */
const { isChatAdmin, normChatUser } = require("./mobile-chat-moderation");
const { normalizeUser } = require("./store");
const { buildWalletPayload } = require("./mobile-wallet");
const { GAME_HOST_USER, isGameHost } = require("./host-config");

const PROTECTED_USERS = new Set([GAME_HOST_USER]);
const SHIELD_UNIT_MS = 48 * 60 * 60 * 1000;

function isMobileGameHost(userId) {
  return isGameHost(userId);
}

function requireHostAdmin(session, res) {
  if (!session) {
    res.status(401).json({
      ok: false,
      error: "auth_required",
      message: "Link your TikTok account on live first.",
    });
    return false;
  }
  if (!isMobileGameHost(session.userId)) {
    res.status(403).json({
      ok: false,
      error: "not_host",
      message: "Only the game host can use this panel.",
    });
    return false;
  }
  return true;
}

function targetUserFrom(body) {
  return normalizeUser(String(body?.userId || body?.username || body?.user || "").trim());
}

function registerMobileGameAdminRoutes(app, ctx) {
  const { validateBearer, pointStore, game, broadcast, pushState } = ctx;

  app.get("/api/mobile/admin/player", (req, res) => {
    const session = validateBearer(req);
    if (!requireHostAdmin(session, res)) return;

    const target = normalizeUser(String(req.query?.userId || req.query?.username || "").trim());
    if (!target) {
      return res.status(400).json({ ok: false, error: "user_id_required" });
    }

    pointStore.ensureAccount(target);
    const wallet = buildWalletPayload(target, pointStore, game);
    res.json({ ok: true, ...wallet });
  });

  app.post("/api/mobile/admin/update-player", (req, res) => {
    const session = validateBearer(req);
    if (!requireHostAdmin(session, res)) return;

    const target = targetUserFrom(req.body || {});
    if (!target) {
      return res.status(400).json({ ok: false, error: "user_id_required" });
    }
    if (PROTECTED_USERS.has(normChatUser(target)) && !isMobileGameHost(session.userId)) {
      return res.status(403).json({
        ok: false,
        error: "protected_user",
        message: "Cannot modify a protected account.",
      });
    }

    const changes = [];
    pointStore.ensureAccount(target);

    if (req.body?.balance != null) {
      pointStore.setBalance(target, req.body.balance);
      changes.push("balance");
    }
    if (req.body?.allTime != null) {
      pointStore.setAllTime(target, req.body.allTime);
      changes.push("allTime");
    }

    const inv = req.body?.inventory;
    if (inv && typeof inv === "object") {
      pointStore.setPowerupInventory(target, inv);
      changes.push("inventory");
    } else {
      const patch = {};
      if (req.body?.stealCharges != null) patch.stealCharges = req.body.stealCharges;
      if (req.body?.shieldBreakCharges != null) patch.shieldBreakCharges = req.body.shieldBreakCharges;
      if (req.body?.jetLockCharges != null) patch.jetLockCharges = req.body.jetLockCharges;
      if (Object.keys(patch).length) {
        const current = pointStore.getPowerupInventory(target);
        pointStore.setPowerupInventory(target, { ...current, ...patch });
        changes.push("inventory");
      }
    }

    const shieldAction = String(req.body?.shieldAction || "").toLowerCase();
    if (shieldAction === "clear") {
      pointStore.clearShield(target);
      changes.push("shield_clear");
    } else if (shieldAction === "grant") {
      const hours = Math.max(0, Number(req.body?.shieldHours) || 0);
      const ms =
        req.body?.shieldMs != null
          ? Math.max(0, Math.floor(Number(req.body.shieldMs) || 0))
          : hours > 0
            ? hours * 60 * 60 * 1000
            : SHIELD_UNIT_MS;
      if (ms > 0) {
        pointStore.shieldUser(target, ms, "host_admin");
        changes.push("shield_grant");
      }
    }

    const jetAction = String(req.body?.jetLockAction || "").toLowerCase();
    if (jetAction === "clear" && typeof game?.adminClearJetLock === "function") {
      game.adminClearJetLock(target);
      changes.push("jet_lock_clear");
    } else if (jetAction === "grant" && typeof game?.adminSetJetLock === "function") {
      const minutes = Math.max(0, Number(req.body?.jetLockMinutes) || 0);
      const ms =
        req.body?.jetLockMs != null
          ? Math.max(0, Math.floor(Number(req.body.jetLockMs) || 0))
          : minutes > 0
            ? minutes * 60 * 1000
            : Math.max(1, Math.floor(Number(game.opts?.flyingJetLockMs) || 3600000));
      if (ms > 0) {
        game.adminSetJetLock(target, ms);
        changes.push("jet_lock_grant");
      }
    }

    if (!changes.length) {
      return res.status(400).json({
        ok: false,
        error: "no_changes",
        message: "Send balance, inventory, shieldAction, or jetLockAction.",
      });
    }

    if (typeof pushState === "function") pushState();
    if (typeof broadcast === "function") {
      broadcast({
        type: "admin_player_update",
        payload: { userId: target, by: session.userId, changes, at: Date.now() },
      });
    }

    const wallet = buildWalletPayload(target, pointStore, game);
    console.log(`[Admin] @${session.userId} updated @${target}: ${changes.join(", ")}`);
    res.json({ ok: true, changes, ...wallet });
  });

  app.post("/api/mobile/admin/wipe-player", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    if (!isChatAdmin(session.userId) && !isMobileGameHost(session.userId)) {
      return res.status(403).json({
        ok: false,
        error: "not_admin",
        message: "Only the host can remove players from the leaderboard.",
      });
    }

    const target = targetUserFrom(req.body || {});
    if (!target) {
      return res.status(400).json({ ok: false, error: "user_id_required" });
    }
    if (PROTECTED_USERS.has(normChatUser(target))) {
      return res.status(403).json({
        ok: false,
        error: "protected_user",
        message: "Cannot wipe a protected account.",
      });
    }

    const result = pointStore.wipeLeaderboardUser(target);
    if (!result.ok) {
      const status = result.error === "user_not_found" ? 404 : 400;
      return res.status(status).json(result);
    }

    if (typeof game?.adminClearJetLock === "function") {
      game.adminClearJetLock(target);
    }

    if (typeof pushState === "function") pushState();
    if (typeof broadcast === "function") {
      broadcast({
        type: "leaderboard_wipe",
        payload: { userId: target, by: session.userId, at: Date.now() },
      });
    }

    console.log(`[Admin] @${session.userId} wiped leaderboard player @${target}`);
    res.json({ ok: true, ...result });
  });
}

module.exports = { registerMobileGameAdminRoutes, isMobileGameHost };
