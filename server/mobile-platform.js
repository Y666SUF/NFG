/**
 * Cross-game mobile platform: shared chat/presence status + Hangman app actions.
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");
const { getTikTokBridgeStatus } = require("./tiktok-bridge");
const { presencePayload } = require("./mobile-presence");
const { fetchHangmanJson, HANGMAN_BACKEND_URL } = require("./hangman-proxy");

const NFG_INTERNAL_SECRET = String(process.env.NFG_INTERNAL_SECRET || "nfg-dev-internal").trim();

function hangmanGuessRequest(body, headers) {
  const url = `${HANGMAN_BACKEND_URL}/api/hangman/app/guess`;
  const parsed = new URL(url);
  const lib = parsed.protocol === "https:" ? https : http;
  const payload = JSON.stringify(body || {});
  return new Promise((resolve) => {
    const req = lib.request(
      {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === "https:" ? 443 : 80),
        path: parsed.pathname,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
          ...headers,
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          try {
            resolve({
              status: res.statusCode,
              body: JSON.parse(Buffer.concat(chunks).toString("utf8")),
            });
          } catch {
            resolve({ status: res.statusCode, body: { ok: false, error: "bad_hangman_response" } });
          }
        });
      }
    );
    req.on("error", (err) => resolve({ status: 502, body: { ok: false, error: "hangman_unreachable", message: err.message } }));
    req.write(payload);
    req.end();
  });
}

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

  return {
    ok: true,
    platform: "nfg",
    version: "1.0.0",
    activeAppUsers: presence.activeAppUsers,
    activeAppUserList: presence.activeAppUserList,
    tiktokLive: {
      isLive: !!(crashLive || hangmanLive),
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
  const { game, pointStore, validateBearer, broadcast } = ctx;

  app.get("/api/mobile/platform/status", async (_req, res) => {
    res.json(await buildPlatformStatus(game, pointStore));
  });

  app.post("/api/mobile/hangman/guess", async (req, res) => {
    const session = typeof validateBearer === "function" ? validateBearer(req) : null;
    if (!session || !session.userId) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first (!link CODE).",
      });
    }

    const letter = String(req.body?.letter || "")
      .trim()
      .toUpperCase()
      .replace(/[^A-Z]/g, "");
    if (letter.length !== 1) {
      return res.status(400).json({ ok: false, error: "invalid_letter", message: "Send one letter A–Z." });
    }

    const word = String(req.body?.word || "").trim();
    const body = word.length >= 2 ? { word } : { letter };

    const out = await hangmanGuessRequest(body, {
      "X-NFG-Internal": NFG_INTERNAL_SECRET,
      "X-NFG-User-Id": String(session.userId).toLowerCase(),
      "X-NFG-Display-Name": String(session.displayName || session.userId),
    });

    res.status(out.status || 502).json(out.body || { ok: false, error: "hangman_error" });
  });
}

module.exports = { registerMobilePlatformRoutes, buildPlatformStatus, NFG_INTERNAL_SECRET };
