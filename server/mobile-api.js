/**
 * Mobile / iOS companion endpoints.
 */
const { registerMobileAuthRoutes, validateBearer: validateBearerResult } = require("./mobile-auth");
const { getTikTokBridgeStatus } = require("./tiktok-bridge");
const { registerMobileChatRoutes } = require("./mobile-chat");
const { registerMobileRewardedAdRoutes } = require("./mobile-rewarded-ad");
const { registerMobileStoreRoutes } = require("./mobile-store");
const {
  registerMobilePresenceRoutes,
  getActiveAppUserCount,
  getActiveAppUserList,
} = require("./mobile-presence");
const { buildWalletPayload } = require("./mobile-wallet");
const { buildPlatformStatus, registerMobilePlatformRoutes } = require("./mobile-platform");

/** Session object for route handlers (validateBearer in auth returns { ok, session }). */
function validateBearer(req) {
  const auth = validateBearerResult(req);
  return auth && auth.ok ? auth.session : null;
}

function registerMobileApi(app, ctx) {
  const { game, pointStore, isLocalhost, broadcast } = ctx;

  registerMobileAuthRoutes(app, { isLocalhost });
  if (typeof broadcast === "function") {
    registerMobileChatRoutes(app, { broadcast, validateBearer, pointStore });
  }
  registerMobileRewardedAdRoutes(app, { pointStore, validateBearer, broadcast });
  registerMobileStoreRoutes(app, { pointStore, validateBearer, broadcast });
  registerMobilePresenceRoutes(app, { validateBearer, pointStore, broadcast });
  registerMobilePlatformRoutes(app, { game, pointStore, validateBearer, broadcast });

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
    res.json(buildWalletPayload(session.userId, pointStore, game));
  });
}

module.exports = { registerMobileApi, buildWalletPayload, validateBearer };
