/**
 * Mobile / iOS companion endpoints.
 */
const fs = require("fs");
const path = require("path");
const { registerMobileAuthRoutes, validateBearer: validateBearerResult } = require("./mobile-auth");
const { getPlayerAvatar } = require("./tiktok-avatar");
const { getAppRoot } = require("./paths");
const { getTikTokBridgeStatus } = require("./tiktok-bridge");
const { registerMobileChatRoutes, deleteMessageById } = require("./mobile-chat");
const { registerMobileChatModerationRoutes } = require("./mobile-chat-moderation");
const { registerMobileRewardedAdRoutes } = require("./mobile-rewarded-ad");
const { registerMobileStoreRoutes } = require("./mobile-store");
const { registerMobileCosmeticsRoutes } = require("./mobile-cosmetics");
const {
  registerMobilePresenceRoutes,
  getActiveAppUserCount,
  getActiveAppUserList,
} = require("./mobile-presence");
const { buildWalletPayload } = require("./mobile-wallet");
const { buildPlatformStatus, registerMobilePlatformRoutes } = require("./mobile-platform");
const { registerHangmanMobileRoutes } = require("./mobile-hangman");
const { registerMobileProfileRoutes } = require("./mobile-profile");
const { registerMobileArcadeRoutes } = require("./mobile-arcade");
const { registerTikTokAvatarRoutes } = require("./tiktok-profile-avatar");
const { registerMobileGameAdminRoutes } = require("./mobile-game-admin");
const { isGameHost } = require("./host-config");
const { registerTowerWorldRoutes } = require("./tower-world");
const { registerJumpVsRoutes } = require("./jump-vs-lobby");

/** Session object for route handlers (validateBearer in auth returns { ok, session }). */
function validateBearer(req) {
  const auth = validateBearerResult(req);
  return auth && auth.ok ? auth.session : null;
}

const BETA_SIGNUPS_FILE = path.join(getAppRoot(), "data", "beta-signups.json");
const betaSignupLastByIp = new Map();
const BETA_SIGNUP_RATE_MS = 60 * 1000;

function appendBetaSignup(entry) {
  const dir = path.dirname(BETA_SIGNUPS_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  let list = [];
  if (fs.existsSync(BETA_SIGNUPS_FILE)) {
    try {
      const parsed = JSON.parse(fs.readFileSync(BETA_SIGNUPS_FILE, "utf8"));
      if (Array.isArray(parsed)) list = parsed;
    } catch {
      list = [];
    }
  }
  const email = String(entry.email || "")
    .trim()
    .toLowerCase();
  if (list.some((r) => String(r.email || "").toLowerCase() === email)) {
    return { duplicate: true };
  }
  list.push(entry);
  fs.writeFileSync(BETA_SIGNUPS_FILE, JSON.stringify(list, null, 2), "utf8");
  return { duplicate: false };
}

function registerMobileApi(app, ctx) {
  const { game, pointStore, isLocalhost, broadcast, pushState } = ctx;

  registerMobileAuthRoutes(app, { isLocalhost, pointStore });
  if (typeof broadcast === "function") {
    registerMobileChatRoutes(app, { broadcast, validateBearer, pointStore });
    registerMobileChatModerationRoutes(app, {
      broadcast,
      validateBearer,
      deleteMessageById,
    });
  }
  registerMobileRewardedAdRoutes(app, { pointStore, validateBearer, broadcast });
  registerMobileStoreRoutes(app, { pointStore, validateBearer, broadcast });
  registerMobileCosmeticsRoutes(app, { game, pointStore, validateBearer, broadcast });
  registerMobilePresenceRoutes(app, { validateBearer, pointStore, broadcast });
  registerMobilePlatformRoutes(app, { game, pointStore, validateBearer, broadcast });
  registerHangmanMobileRoutes(app, { validateBearer });
  registerMobileProfileRoutes(app, { validateBearer, pointStore, game });
  registerMobileArcadeRoutes(app, { validateBearer, pointStore, game });
  registerTikTokAvatarRoutes(app, { validateBearer });
  registerMobileGameAdminRoutes(app, { validateBearer, pointStore, game, broadcast, pushState });
  registerTowerWorldRoutes(app, { validateBearer, pointStore, game });
  registerJumpVsRoutes(app, { validateBearer, pointStore, game });

  app.get("/api/mobile/status", async (_req, res) => {
    const platform = await buildPlatformStatus(game, pointStore);
    const state = game.getState();
    const tiktok = getTikTokBridgeStatus();
    const playerCount = pointStore.listBalances ? pointStore.listBalances(999999).length : 0;
    res.json({
      ...platform,
      service: "nfg-crash",
      phase: state.phase,
      roundId: state.roundId,
      multiplier: state.multiplier,
      playerCount,
      activeAppUsers: platform.activeAppUsers ?? getActiveAppUserCount(),
      activeAppUserList: platform.activeAppUserList ?? getActiveAppUserList(pointStore),
      sharedData: true,
      tiktokLive: platform.tiktokLive || { ...tiktok, isLive: tiktok.state === "live" },
      message:
        "Shared app chat across NFG apps. Crash bets use this server's points; Hangman uses its own all-time board.",
    });
  });

  app.get("/api/mobile/debug/session", (req, res) => {
    if (typeof isLocalhost === "function" && !isLocalhost(req)) {
      return res.status(403).json({ ok: false, error: "local only" });
    }
    const auth = validateBearerResult(req);
    if (!auth.ok) return res.status(401).json({ ok: false, error: "auth_required" });
    const profile = pointStore.getUserPresentation(auth.session.userId);
    return res.json({
      ok: true,
      session: auth.session,
      profile,
      state: game.getState(),
    });
  });

  app.get("/api/mobile/me", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    res.json({
      ...buildWalletPayload(session.userId, pointStore, game),
      isGameHost: isGameHost(session.userId),
    });
  });

  app.get("/api/mobile/player-avatar", async (req, res) => {
    const user = String(req.query.user || req.query.key || "").trim();
    if (!user) {
      return res.status(400).json({ ok: false, message: "user required" });
    }
    try {
      const av = await getPlayerAvatar(user);
      res.setHeader("Cache-Control", "public, max-age=1800");
      res.type(av.mime).send(av.bytes);
    } catch {
      res.status(502).json({ ok: false, message: "avatar_unavailable" });
    }
  });

  app.post("/api/mobile/beta-signup", (req, res) => {
    const email = String(req.body?.email || "").trim();
    const source = String(req.body?.source || "web").trim().slice(0, 64);
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ ok: false, message: "Enter a valid email address." });
    }
    const ip = String(req.headers["cf-connecting-ip"] || req.ip || req.socket.remoteAddress || "").trim();
    const now = Date.now();
    const last = Number(betaSignupLastByIp.get(ip) || 0);
    if (last > 0 && now - last < BETA_SIGNUP_RATE_MS) {
      return res.status(429).json({ ok: false, message: "Please wait a moment before trying again." });
    }
    try {
      const { duplicate } = appendBetaSignup({
        email,
        source,
        ip,
        at: new Date().toISOString(),
      });
      betaSignupLastByIp.set(ip, now);
      return res.json({
        ok: true,
        duplicate,
        message: duplicate
          ? "You are already on the beta waitlist — we will email you when a slot opens."
          : "Thanks! You are on the NFG Crash beta waitlist. We will email you when TestFlight opens.",
      });
    } catch (err) {
      console.warn("[beta-signup] save failed:", err && err.message ? err.message : err);
      return res.status(500).json({ ok: false, message: "Could not save your email. Try again later." });
    }
  });
}

module.exports = { registerMobileApi, buildWalletPayload, validateBearer };
