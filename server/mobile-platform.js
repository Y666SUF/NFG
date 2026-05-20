/**
 * Cross-game mobile platform: shared chat/presence status (Crash + Hangman apps).
 */
const { getTikTokBridgeStatus } = require("./tiktok-bridge");
const { presencePayload } = require("./mobile-presence");
const { fetchHangmanJson, HANGMAN_BACKEND_URL } = require("./hangman-proxy");

async function buildPlatformStatus(game, pointStore) {
  const presence = presencePayload(pointStore);
  const tiktokCrash = getTikTokBridgeStatus();
  const crashLive = tiktokCrash.state === "live";

  const hangmanProbe = await fetchHangmanJson("/api/hangman/status", 900);
  const hangmanBody = hangmanProbe.ok && hangmanProbe.body ? hangmanProbe.body : null;
  const hangmanLive =
    hangmanBody &&
    (hangmanBody.tiktok_status === "connected" || hangmanBody.tiktok_status === "connecting");

  const state = game.getState();
  const anyLive = !!(crashLive || hangmanLive);
  const primaryUniqueId =
    (crashLive && tiktokCrash.uniqueId) ||
    (hangmanLive && hangmanBody && hangmanBody.tiktok) ||
    tiktokCrash.uniqueId ||
    hangmanBody?.tiktok ||
    process.env.TIKTOK_UNIQUE_ID ||
    "y666.suf";
  const primaryState = crashLive
    ? tiktokCrash.state
    : hangmanLive
      ? "live"
      : tiktokCrash.state || hangmanBody?.tiktok_status || "offline";

  return {
    ok: true,
    platform: "nfg",
    version: "1.0.0",
    activeAppUsers: presence.activeAppUsers,
    activeAppUserList: presence.activeAppUserList,
    tiktokLive: {
      enabled: true,
      uniqueId: primaryUniqueId,
      state: primaryState,
      isLive: anyLive,
      crash: { ...tiktokCrash, isLive: crashLive },
      hangman: hangmanBody
        ? {
            tiktok: hangmanBody.tiktok,
            tiktok_status: hangmanBody.tiktok_status,
            isLive: !!hangmanLive,
            reachable: true,
          }
        : { reachable: false, isLive: false, tiktok_status: "unreachable" },
    },
    games: {
      crash: {
        service: "nfg-crash",
        phase: state.phase,
        roundId: state.roundId,
        multiplier: state.multiplier,
        playerCount: pointStore.listBalances ? pointStore.listBalances(999999).length : 0,
      },
      hangman: hangmanBody || { service: "nfg-hangman", reachable: false },
    },
    sharedChat: true,
    hangmanBackend: HANGMAN_BACKEND_URL,
    message: "Shared app chat and online list across all NFG companion apps.",
  };
}

function registerMobilePlatformRoutes(app, ctx) {
  const { game, pointStore } = ctx;

  app.get("/api/mobile/platform/status", async (_req, res) => {
    res.json(await buildPlatformStatus(game, pointStore));
  });
}

module.exports = { registerMobilePlatformRoutes, buildPlatformStatus };
