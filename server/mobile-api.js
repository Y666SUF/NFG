/**
 * Mobile / iOS companion endpoints.
 * Copy this file + mobile-presence.js (+ other mobile-*.js) to Windows server/.
 */
const { registerMobileAuthRoutes, validateBearer } = require("./mobile-auth");
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

function registerMobileApi(app, ctx) {
  const { game, pointStore, isLocalhost, broadcast } = ctx;

  registerMobileAuthRoutes(app, { isLocalhost });
  if (typeof broadcast === "function") {
    registerMobileChatRoutes(app, { broadcast, validateBearer, pointStore });
  }
  registerMobileRewardedAdRoutes(app, { pointStore, validateBearer, broadcast });
  registerMobileStoreRoutes(app, { pointStore, validateBearer, broadcast });
  registerMobilePresenceRoutes(app, { validateBearer, pointStore });

  app.get("/api/mobile/status", (_req, res) => {
    const state = game.getState();
    const tiktok = getTikTokBridgeStatus();
    const playerCount = pointStore.listBalances ? pointStore.listBalances(999999).length : 0;
    res.json({
      ok: true,
      service: "nfg-crash",
      version: "1.0.0",
      phase: state.phase,
      roundId: state.roundId,
      multiplier: state.multiplier,
      playerCount,
      activeAppUsers: getActiveAppUserCount(),
      activeAppUserList: getActiveAppUserList(pointStore),
      sharedData: true,
      tiktokLive: {
        ...tiktok,
        isLive: tiktok.state === "live",
      },
      message:
        "Connect iOS to this server. Bets and balances use the same points file as TikTok live.",
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

module.exports = { registerMobileApi, buildWalletPayload };
