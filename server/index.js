const fs = require("fs");
const http = require("http");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");
const express = require("express");
const nodemailer = require("nodemailer");
const { WebSocketServer } = require("ws");

const { PointStore, normalizeUser } = require("./store");
const { CrashGame, listNameBadgeShop } = require("./game");
const { resolveGiftPayout } = require("./gift-payout");
const { appendGiftLedger } = require("./gift-ledger");
const { isDuplicateGiftPayout, isDuplicateStreakSettlement } = require("./gift-dedupe");
const { startTikTokBridge, getTikTokBridgeStatus } = require("./tiktok-bridge");
const { recordCashoutWin, buildFeaturedPayload } = require("./website-stats");
const { registerMobileApi } = require("./mobile-api");
const { completeLinkFromTikTok, validateBearer } = require("./mobile-auth");
const {
  spotifyConfigured,
  queueTrackBySearch,
  getSpotifyNowPlaying,
  getSpotifyQueueSnapshot,
  getSpotifyStatus,
} = require("./spotify");
const { registerHangmanHttpProxy, attachHangmanWebSocketProxy } = require("./hangman-proxy");
const { startHangmanProcess, waitForHangman, HANGMAN_PORT } = require("./hangman-process");
const { registerIpaDownloads, getIpaDownloadMeta, IPA_CATALOG } = require("./ipa-downloads");

const PORT = Number(process.env.PORT) || 3847;
const STARTER_POINTS = Number(process.env.STARTER_POINTS) || 5000;
const SHARE_BONUS = Number(process.env.SHARE_BONUS_POINTS) || 100;
const GIFT_COIN_MULTIPLIER = Number(process.env.GIFT_COIN_MULTIPLIER) || 100;
const LIKE_POINTS_PER = Number(process.env.LIKE_POINTS) || 25;
const REPOST_BONUS = Number(process.env.REPOST_BONUS_POINTS) || 500;
const SHIELD_DURATION_MS = 48 * 60 * 60 * 1000;
const BALANCE_SHOUT_COOLDOWN_MS = Number(process.env.BALANCE_SHOUT_COOLDOWN_MS) || 60_000;
const ICONS_POPUP_COOLDOWN_MS = Number(process.env.ICONS_POPUP_COOLDOWN_MS) || 120_000;
const ICONS_POPUP_DURATION_MS = Number(process.env.ICONS_POPUP_DURATION_MS) || 10_000;
const SPIN_TICKET_COST = Number(process.env.SPIN_TICKET_COST) || 2000;
const PIN_MESSAGE_COST = Number(process.env.PIN_MESSAGE_COST) || 3000;
const PIN_MESSAGE_DURATION_MS = Number(process.env.PIN_MESSAGE_DURATION_MS) || 180_000;
const BOUNTY_MIN_POINTS = Number(process.env.BOUNTY_MIN_POINTS) || 500;
/** When true, `/api/chat` includes `tiktokChatReply` for successful !balance so the TikTok bridge can post to live chat. */
const TIKTOK_BALANCE_CHAT_REPLY = process.env.TIKTOK_BALANCE_CHAT_REPLY !== "0";
const AUTO_ROUND_MS =
  process.env.AUTO_ROUND_MS === "0" ? 0 : Number(process.env.AUTO_ROUND_MS) || 10_000;
const BETTING_SECONDS = Number(process.env.BETTING_SECONDS) || 15;
const MAX_RUN_SECONDS = Number(process.env.MAX_RUN_SECONDS) || 0;
// Bets are intentionally uncapped; users can bet any amount they currently hold.
const MAX_BET = Number.MAX_SAFE_INTEGER;
const AUTO_BACKUP_INTERVAL_MS = Math.max(60_000, Number(process.env.AUTO_BACKUP_INTERVAL_MS) || 10 * 60 * 1000);
const AUTO_BACKUP_KEEP_LATEST = Math.max(1, Math.floor(Number(process.env.AUTO_BACKUP_KEEP_LATEST) || 12));
const SERVER_HOST = String(process.env.HOST || "0.0.0.0").trim() || "0.0.0.0";

const app = express();
app.disable("x-powered-by");
app.set("trust proxy", true);
app.use(express.json());

const corsOriginsRaw = String(process.env.CORS_ORIGINS || "")
  .split(",")
  .map((v) => v.trim())
  .filter(Boolean);
const corsOrigins = new Set([
  ...corsOriginsRaw,
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "https://y666suf.com",
  "https://www.y666suf.com",
]);

function isAllowedCorsOrigin(origin) {
  if (!origin) return false;
  if (corsOrigins.has("*") || corsOrigins.has(origin)) return true;
  const lower = origin.toLowerCase();
  if (lower.startsWith("capacitor://") || lower.startsWith("ionic://")) return true;
  return false;
}

const corsAllowHeaders =
  "Content-Type, Authorization, X-Device-Id, X-Client-App, X-NFG-Internal, X-NFG-User-Id, X-NFG-Display-Name";

app.use((req, res, next) => {
  const origin = String(req.headers.origin || "").trim();
  if (origin && isAllowedCorsOrigin(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
    res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", corsAllowHeaders);
  }
  if (req.method === "OPTIONS") return res.status(204).end();
  next();
});

process.on("uncaughtException", (err) => {
  console.error("[NFG] uncaughtException (server stays up):", err && err.stack ? err.stack : err);
});
process.on("unhandledRejection", (reason) => {
  console.error("[NFG] unhandledRejection (server stays up):", reason);
});

const publicDir = path.join(__dirname, "..", "public");
const websiteDir = path.join(__dirname, "..", "website");
const reactWebsiteDir = path.join(__dirname, "..", "_import_Y666SUF_website", "frontend", "build");
const reactWebsiteIndex = path.join(reactWebsiteDir, "index.html");
const hasReactWebsiteBuild = fs.existsSync(reactWebsiteIndex);
const websiteAssetsDir = path.join(websiteDir, "assets");
const gameIndexFile = path.join(publicDir, "index.html");
const websiteIndexFile = path.join(websiteDir, "index.html");
const websitePrivacyFile = path.join(websiteDir, "privacy.html");
const websiteLegalFile = path.join(websiteDir, "legal.html");
const websiteContactFile = path.join(websiteDir, "contact.html");
const websiteSideloadFile = path.join(websiteDir, "sideload.html");
const secretContactPathRaw = String(process.env.WEBSITE_CONTACT_PATH || "/contact-9x7k").trim();
const WEBSITE_CONTACT_PATH = secretContactPathRaw.startsWith("/")
  ? secretContactPathRaw
  : `/${secretContactPathRaw}`;
const CONTACT_TO_EMAIL = "support@y666suf.com";
const CONTACT_FROM_EMAIL = String(process.env.CONTACT_FROM_EMAIL || process.env.SMTP_USER || "").trim();
const CONTACT_REPLY_TO_EMAIL = String(process.env.CONTACT_REPLY_TO_EMAIL || CONTACT_TO_EMAIL).trim();
const CONTACT_RATE_LIMIT_MS = 30_000;
const contactLastSentByIp = new Map();
let contactMailer = null;
const websiteGames = {
  "nfg-crash": path.join(websiteDir, "game-nfg-crash.html"),
  "nfg-wordwich": path.join(websiteDir, "game-nfg-wordwich.html"),
  "nfg-wordwheel": path.join(websiteDir, "game-nfg-wordwheel.html"),
  "nfg-hangman": path.join(websiteDir, "game-nfg-hangman.html"),
};

function isPublicWebsiteHost(req) {
  const host = String(req.headers.host || "").trim().toLowerCase();
  return (
    host === "y666suf.com" ||
    host.startsWith("y666suf.com:") ||
    host === "www.y666suf.com" ||
    host.startsWith("www.y666suf.com:")
  );
}

/** React marketing site on port 3847 (public domain = full site; localhost = /games, /privacy, etc.). */
function shouldServeReactWebsite(req) {
  if (!hasReactWebsiteBuild) return false;
  if (isPublicWebsiteHost(req)) return true;
  const p = String(req.path || "");
  if (p.startsWith("/static/")) return true;
  if (p === "/privacy" || p === "/legal" || p === "/sideload") return true;
  if (p.startsWith("/games/")) return true;
  return false;
}

function sendReactWebsite(_req, res) {
  // Avoid stale index.html on iPhone Safari (old JS pointed at localhost APIs).
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.setHeader("Pragma", "no-cache");
  res.setHeader("Expires", "0");
  return res.sendFile(reactWebsiteIndex);
}

function applyPublicSecurityHeaders(res) {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  res.setHeader("Permissions-Policy", "camera=(), microphone=(), geolocation=()");
  res.setHeader("X-Frame-Options", "SAMEORIGIN");
  res.setHeader("Cross-Origin-Opener-Policy", "same-origin-allow-popups");
  res.setHeader(
    "Content-Security-Policy",
    [
      "default-src 'self'",
      "base-uri 'self'",
      "object-src 'none'",
      "script-src 'self'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self' data: https:",
      "connect-src 'self' https: wss: ws:",
      "form-action 'self'",
      "frame-ancestors 'self' https://*.tiktok.com https://*.tiktokv.com https://*.byteoversea.com",
    ].join("; ")
  );
}

app.use((req, res, next) => {
  if (isPublicWebsiteHost(req)) {
    applyPublicSecurityHeaders(res);
  }
  next();
});

function blockPublicDomainGamePage(req, res, next) {
  if (isPublicWebsiteHost(req)) {
    return res.redirect(302, "/");
  }
  next();
}

function getContactMailer() {
  if (contactMailer) return contactMailer;
  const host = String(process.env.SMTP_HOST || "").trim();
  const port = Number(process.env.SMTP_PORT) || 587;
  const user = String(process.env.SMTP_USER || "").trim();
  const pass = String(process.env.SMTP_PASS || "").trim();
  if (!host || !user || !pass || !CONTACT_FROM_EMAIL) return null;
  contactMailer = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });
  return contactMailer;
}

app.get("/privacy", (req, res) => {
  if (shouldServeReactWebsite(req)) return sendReactWebsite(req, res);
  return res.sendFile(websitePrivacyFile);
});
app.get("/legal", (req, res) => {
  if (shouldServeReactWebsite(req)) return sendReactWebsite(req, res);
  return res.sendFile(websiteLegalFile);
});
app.get("/sideload", (req, res) => {
  if (shouldServeReactWebsite(req)) return sendReactWebsite(req, res);
  return res.sendFile(websiteSideloadFile);
});
app.get(WEBSITE_CONTACT_PATH, (req, res) => {
  if (shouldServeReactWebsite(req)) return sendReactWebsite(req, res);
  return res.sendFile(websiteContactFile);
});
app.get("/contact", (_req, res) => res.status(404).send("Not found"));
app.get("/privacy.html", (_req, res) => res.redirect(302, "/privacy"));
app.get("/legal.html", (_req, res) => res.redirect(302, "/legal"));
app.get("/sideload.html", (_req, res) => res.redirect(302, "/sideload"));
app.get("/contact.html", (_req, res) => res.status(404).send("Not found"));
registerIpaDownloads(app);
app.post("/api/contact", async (req, res) => {
  const name = String(req.body?.name || "").trim();
  const email = String(req.body?.email || "").trim();
  const subject = String(req.body?.subject || "").trim();
  const message = String(req.body?.message || "").trim();
  if (!name || !email || !subject || !message) {
    return res.status(400).json({ ok: false, message: "All fields are required." });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ ok: false, message: "Enter a valid email address." });
  }
  const ip = String(req.headers["cf-connecting-ip"] || req.ip || req.socket.remoteAddress || "").trim();
  const now = Date.now();
  const last = Number(contactLastSentByIp.get(ip) || 0);
  if (last > 0 && now - last < CONTACT_RATE_LIMIT_MS) {
    return res.status(429).json({ ok: false, message: "Please wait before sending another message." });
  }

  const mailer = getContactMailer();
  if (!mailer) {
    return res.status(503).json({
      ok: false,
      message: "Contact email is not configured yet. Please set SMTP environment values.",
    });
  }

  try {
    await mailer.sendMail({
      from: CONTACT_FROM_EMAIL,
      to: CONTACT_TO_EMAIL,
      replyTo: email || CONTACT_REPLY_TO_EMAIL,
      subject: `[NFG Contact] ${subject.slice(0, 140)}`,
      text: [
        `Name: ${name}`,
        `Email: ${email}`,
        `IP: ${ip || "unknown"}`,
        "",
        message,
      ].join("\n"),
    });
    contactLastSentByIp.set(ip, now);
    return res.json({ ok: true, sent: true });
  } catch (err) {
    console.warn("[contact] send failed:", err && err.message ? err.message : err);
    return res.status(502).json({ ok: false, message: "Message delivery failed. Try again later." });
  }
});
app.get("/games/:slug", (req, res) => {
  if (shouldServeReactWebsite(req)) {
    return sendReactWebsite(req, res);
  }
  const slug = String(req.params.slug || "").trim().toLowerCase();
  const page = websiteGames[slug];
  if (!page) return res.status(404).send("Not found");
  return res.sendFile(page);
});
app.get(["/", "/index.html"], (req, res) => {
  if (isPublicWebsiteHost(req)) {
    if (hasReactWebsiteBuild) return sendReactWebsite(req, res);
    return res.sendFile(websiteIndexFile);
  }
  return res.sendFile(gameIndexFile);
});

app.get("/portrait.html", blockPublicDomainGamePage, (_req, res) =>
  res.sendFile(path.join(publicDir, "portrait.html"))
);
app.get("/player-lookup.html", blockPublicDomainGamePage, (_req, res) =>
  res.sendFile(path.join(publicDir, "player-lookup.html"))
);
app.get("/app-chat.html", blockPublicDomainGamePage, (_req, res) =>
  res.sendFile(path.join(publicDir, "app-chat.html"))
);
app.get("/badge-preview.html", blockPublicDomainGamePage, (_req, res) =>
  res.sendFile(path.join(publicDir, "badge-preview.html"))
);

app.use("/website-assets", (req, res, next) => {
  if (shouldServeReactWebsite(req)) return next();
  return express.static(websiteAssetsDir, { index: false })(req, res, next);
});
if (hasReactWebsiteBuild) {
  app.use((req, res, next) => {
    if (!shouldServeReactWebsite(req)) return next();
    if (String(req.path || "").startsWith("/static/")) {
      res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
    }
    return express.static(reactWebsiteDir, { index: false, fallthrough: true })(req, res, next);
  });
}
app.use((req, res, next) => {
  if (isPublicWebsiteHost(req) && hasReactWebsiteBuild) return next();
  return express.static(publicDir, { index: false })(req, res, next);
});
if (hasReactWebsiteBuild) {
  app.get("*", (req, res, next) => {
    if (!isPublicWebsiteHost(req) || !hasReactWebsiteBuild) return next();
    if (req.method !== "GET" && req.method !== "HEAD") return next();
    const p = String(req.path || "");
    if (p.startsWith("/api") || p.startsWith("/download/")) return next();
    return sendReactWebsite(req, res);
  });
}

const pointStore = new PointStore(STARTER_POINTS);
// Local preview default: always treat host account as superfan.
const DEFAULT_SUPERFAN_USER = "y666.suf";
if (typeof pointStore.setSuperFan === "function") {
  pointStore.setSuperFan(DEFAULT_SUPERFAN_USER, true, 31);
}

const clients = new Set();

function broadcast(obj) {
  const data = JSON.stringify(obj);
  for (const ws of clients) {
    if (ws.readyState === 1) ws.send(data);
  }
}

function userKeyFrom(body = {}) {
  return normalizeUser(body.userId || body.user || "");
}

function isLocalhost(req) {
  const ip = req.socket.remoteAddress || "";
  return ip === "127.0.0.1" || ip === "::1" || ip === "::ffff:127.0.0.1";
}

const { parseCrashSpotifyQueueCommand } = require("./spotify-commands");

function pushState() {
  broadcast({ type: "state", payload: game.getState() });
}

const game = new CrashGame(pointStore, {
  bettingSeconds: BETTING_SECONDS,
  multiplierPerSecond: Number(process.env.MULT_SPEED) || 0.42,
  maxBet: MAX_BET,
  maxRunSeconds: MAX_RUN_SECONDS,
  autoRestartMs: AUTO_ROUND_MS,
  balanceShoutCooldownMs: BALANCE_SHOUT_COOLDOWN_MS,
  iconsPopupCooldownMs: ICONS_POPUP_COOLDOWN_MS,
  iconsPopupDurationMs: ICONS_POPUP_DURATION_MS,
  spinTicketCost: SPIN_TICKET_COST,
  pinMessageCost: PIN_MESSAGE_COST,
  pinMessageDurationMs: PIN_MESSAGE_DURATION_MS,
  bountyMinPoints: BOUNTY_MIN_POINTS,
  onUpdate: pushState,
  onEvent: (evt) => broadcast({ type: "game_event", payload: evt }),
  onCashoutWin: recordCashoutWin,
});

app.get("/api/website/featured", (_req, res) => {
  res.setHeader("Cache-Control", "no-store, max-age=0");
  res.json(buildFeaturedPayload(game, getTikTokBridgeStatus()));
});

app.get("/api/state", (_req, res) => {
  res.json(game.getState());
});

registerMobileApi(app, { game, pointStore, isLocalhost, broadcast });
registerHangmanHttpProxy(app);

app.post("/api/chat", async (req, res) => {
  const source = String(req.body?.source || "").trim().toLowerCase();
  if (source === "mobile") {
    const auth = validateBearer(req);
    if (!auth.ok || !auth.session || !auth.session.userId) {
      return res.status(401).json({ ok: false, error: "auth_required" });
    }
    const linkedUser = normalizeUser(auth.session.userId);
    req.body = {
      ...(req.body || {}),
      userId: linkedUser,
      user: linkedUser,
      displayName: req.body?.displayName || auth.session.displayName || linkedUser,
    };
  }

  const { message, displayName, superFan, superFanLevel } = req.body || {};
  const user = userKeyFrom(req.body || {});

  if (source !== "mobile") {
    const link = completeLinkFromTikTok(user, displayName, message);
    if (link && link.handled) {
      return res.json({
        ok: true,
        linked: !!link.linked,
        ignored: true,
        tiktokChatReply: link.tiktokChatReply || null,
      });
    }
  }

  if (user && displayName) {
    pointStore.setDisplayName(user, displayName);
  }
  if (user && superFan === true && typeof pointStore.setSuperFan === "function") {
    pointStore.setSuperFan(user, true, superFanLevel);
  }
  if (user) {
    pointStore.ensureAccount(user);
    pointStore.claimDailyBonus(user);
    if (String(message || "").trim()) {
      pointStore.awardXP(user, "CHAT_MESSAGE");
      pointStore.grantAchievement(user, "first_chat");
    }
  }

  const spotifyCmd = parseCrashSpotifyQueueCommand(message);
  if (spotifyCmd) {
    const view = pointStore.getUserPresentation(user);
    let parsed;
    if (spotifyCmd.rejected) {
      parsed = {
        type: "spotify_queue",
        ok: false,
        reason: spotifyCmd.reason || "ambiguous",
        help: spotifyCmd.help,
        user,
        displayName: view.displayName,
        nameStyle: view.nameStyle,
        level: view.level,
        rank: view.rank,
      };
      broadcast({ type: "chat_result", payload: parsed });
      pushState();
      return res.json({
        ok: true,
        parsed,
        tiktokChatReply: spotifyCmd.help || null,
      });
    }
    if (!spotifyCmd.query) {
      parsed = {
        type: "spotify_queue",
        ok: false,
        reason: "empty_query",
        help: "Use !csong artist - track or !cqueue search (Crash). Hangman uses !hsong / !hqueue.",
        user,
        displayName: view.displayName,
        nameStyle: view.nameStyle,
        level: view.level,
        rank: view.rank,
      };
    } else {
      try {
        const queued = await queueTrackBySearch(spotifyCmd.query, view.displayName || user);
        parsed = {
          type: "spotify_queue",
          ...queued,
          command: spotifyCmd.command,
          user,
          displayName: view.displayName,
          nameStyle: view.nameStyle,
          level: view.level,
          rank: view.rank,
          query: spotifyCmd.query,
        };
      } catch (err) {
        parsed = {
          type: "spotify_queue",
          ok: false,
          reason: String(err && err.message ? err.message : err),
          command: spotifyCmd.command,
          user,
          displayName: view.displayName,
          nameStyle: view.nameStyle,
          level: view.level,
          rank: view.rank,
          query: spotifyCmd.query,
        };
      }
    }
    broadcast({ type: "chat_result", payload: parsed });
    pushState();
    return res.json({ ok: true, parsed, tiktokChatReply: null });
  }

  const parsed = game.parseChatMessage(user, message);
  if (!parsed) {
    const raw = String(message || "").trim();
    if (raw.startsWith("!") || raw.startsWith("！")) {
      const view = pointStore.getUserPresentation(user);
      broadcast({
        type: "chat_result",
        payload: {
          type: "unknown_command_line",
          ok: false,
          user,
          displayName: view.displayName,
          nameStyle: view.nameStyle,
          level: view.level,
          rank: view.rank,
          command: raw.slice(0, 80),
        },
      });
    }
    return res.json({ ok: true, ignored: true, tiktokChatReply: null });
  }

  let tiktokChatReply = null;
  if (
    TIKTOK_BALANCE_CHAT_REPLY &&
    parsed.type === "balance_shout" &&
    parsed.ok === true
  ) {
    const s = pointStore.getShieldStatus(parsed.user);
    const shieldText = s.active ? ` | shield ${Math.ceil(s.msLeft / 1000)}s` : "";
    tiktokChatReply = `@${parsed.user} — ${parsed.balance} pts${shieldText}`;
  }

  if (parsed.type === "balance_shout") {
    const shield = pointStore.getShieldStatus(parsed.user);
    const jetLock = typeof game.getJetLockStatus === "function" ? game.getJetLockStatus(parsed.user) : null;
    const economy = pointStore.getEconomyProfile(parsed.user);
    const inventory =
      typeof pointStore.getPowerupInventory === "function"
        ? pointStore.getPowerupInventory(parsed.user)
        : parsed.inventory || { stealCharges: 0, shieldBreakCharges: 0, jetLockCharges: 0 };
    const reset = pointStore.getMissionResetInfo();
    broadcast({
      type: "balance_toast",
      payload: {
        ...parsed,
        shieldActive: shield.active,
        shieldMsLeft: shield.msLeft || 0,
        shieldUntil: shield.shieldUntil || 0,
        missions: economy ? economy.missions : [],
        missionResetAtMs: reset.resetAtMs,
        missionResetSeconds: reset.secondsUntilReset,
        missionResetTimezone: reset.timezone,
        inventory,
        jetLockActive: !!(jetLock && jetLock.active),
        jetLockMsLeft: jetLock ? Number(jetLock.msLeft || 0) : 0,
        jetLockSecondsLeft: jetLock ? Number(jetLock.secondsLeft || 0) : 0,
        jetLockUntil: jetLock ? Number(jetLock.blockedUntil || 0) : 0,
      },
    });
    broadcast({
      type: "chat_result",
      payload: {
        type: "balance_line",
        user: parsed.user,
        displayName: parsed.displayName || pointStore.getDisplayName(parsed.user),
        nameStyle: parsed.nameStyle || pointStore.getNameStyle(parsed.user),
        level: pointStore.getLevel(parsed.user),
        rank: pointStore.getRank(parsed.user),
        balance: parsed.balance,
        allTime: pointStore.getAllTime(parsed.user),
        shieldActive: shield.active,
        shieldMsLeft: shield.msLeft || 0,
        shieldUntil: shield.shieldUntil || 0,
        missions: economy ? economy.missions : [],
        missionResetAtMs: reset.resetAtMs,
        missionResetSeconds: reset.secondsUntilReset,
        missionResetTimezone: reset.timezone,
        inventory,
        jetLockActive: !!(jetLock && jetLock.active),
        jetLockMsLeft: jetLock ? Number(jetLock.msLeft || 0) : 0,
        jetLockSecondsLeft: jetLock ? Number(jetLock.secondsLeft || 0) : 0,
        jetLockUntil: jetLock ? Number(jetLock.blockedUntil || 0) : 0,
        ok: parsed.ok,
        cooldown: parsed.cooldown,
        secondsLeft: parsed.secondsLeft,
      },
    });
  } else if (parsed.type === "bet") {
    if (!parsed.ok || Number(parsed.amount || 0) >= 10_000_000) {
      console.log(
        `[Bet] @${parsed.user} ${parsed.amount} @${parsed.cashout}x -> ${parsed.ok ? "ok" : `fail:${parsed.reason || "unknown"}`}`
      );
    }
    broadcast({ type: "chat_result", payload: parsed });
  } else if (parsed.type === "steal") {
    broadcast({ type: "chat_result", payload: { type: "steal_line", ...parsed } });
  } else if (parsed.type === "shield_break") {
    broadcast({ type: "chat_result", payload: { type: "shield_break_line", ...parsed } });
  } else if (parsed.type === "jet_lock") {
    broadcast({ type: "chat_result", payload: { type: "jet_lock_line", ...parsed } });
  } else if (parsed.type === "command_lock") {
    broadcast({ type: "chat_result", payload: { type: "command_lock_line", ...parsed } });
  } else if (parsed.type === "bounty") {
    broadcast({ type: "chat_result", payload: { type: "bounty_line", ...parsed } });
  } else if (parsed.type === "pin") {
    broadcast({ type: "chat_result", payload: { type: "pin_line", ...parsed } });
  } else if (parsed.type === "spin_ticket") {
    broadcast({ type: "chat_result", payload: { type: "spin_ticket_line", ...parsed } });
  } else if (parsed.type === "namefx") {
    broadcast({ type: "chat_result", payload: { type: "namefx_line", ...parsed } });
  } else if (parsed.type === "buy") {
    broadcast({ type: "chat_result", payload: { type: "buy_line", ...parsed } });
  } else if (parsed.type === "sell_crown") {
    broadcast({ type: "chat_result", payload: { type: "sell_crown_line", ...parsed } });
  } else if (parsed.type === "icons_popup") {
    broadcast({ type: "icons_popup", payload: parsed });
    broadcast({
      type: "chat_result",
      payload: {
        type: "icons_line",
        ok: parsed.ok,
        cooldown: parsed.cooldown,
        user: parsed.user,
        displayName: parsed.displayName,
        nameStyle: parsed.nameStyle,
        level: parsed.level,
        rank: parsed.rank,
        secondsLeft: parsed.secondsLeft,
        durationMs: parsed.durationMs,
      },
    });
  } else if (parsed.type === "superfan") {
    broadcast({ type: "chat_result", payload: { type: "superfan_line", ...parsed } });
  } else if (parsed.type === "addpoints") {
    broadcast({ type: "chat_result", payload: { type: "addpoints_line", ...parsed } });
  } else if (parsed.type === "backupnow") {
    broadcast({ type: "chat_result", payload: { type: "backupnow_line", ...parsed } });
  }
  pushState();
  res.json({ ok: true, parsed, tiktokChatReply });
});

app.get("/api/spotify/now-playing", async (_req, res) => {
  const out = await getSpotifyNowPlaying();
  res.json(out);
});

app.get("/api/spotify/queue-list", async (_req, res) => {
  const out = await getSpotifyQueueSnapshot();
  res.json(out);
});

app.get("/api/spotify/status", async (_req, res) => {
  const out = await getSpotifyStatus();
  res.json(out);
});

app.post("/api/spotify/queue", async (req, res) => {
  const query = String(req.body?.query || "").trim();
  const requestedBy = String(req.body?.requestedBy || "Viewer").trim();
  if (!query) return res.status(400).json({ ok: false, error: "empty_query" });
  const out = await queueTrackBySearch(query, requestedBy || "Viewer");
  res.json(out);
});

/** TikTok bridge only: user metadata updates (localhost). */
app.post("/api/tiktok/user-meta", (req, res) => {
  if (!isLocalhost(req)) {
    return res.status(403).json({ ok: false, error: "local only" });
  }
  const { displayName, superFan, superFanLevel } = req.body || {};
  const u = userKeyFrom(req.body || {});
  if (!u) return res.status(400).json({ ok: false, error: "user required" });
  if (displayName) pointStore.setDisplayName(u, displayName);
  if (superFan === true && typeof pointStore.setSuperFan === "function") {
    pointStore.setSuperFan(u, true, superFanLevel);
  }
  pushState();
  return res.json({
    ok: true,
    user: u,
    superFan: typeof pointStore.isSuperFan === "function" ? pointStore.isSuperFan(u) : false,
    superFanLevel: typeof pointStore.getSuperFanLevel === "function" ? pointStore.getSuperFanLevel(u) : 0,
  });
});

/** TikTok bridge only: share / gift rewards (localhost). */
app.post("/api/tiktok/reward", (req, res) => {
  if (!isLocalhost(req)) {
    return res.status(403).json({ ok: false, error: "local only" });
  }
  const {
    type,
    coins,
    giftName,
    giftCount,
    giftId,
    groupId,
    displayName,
    superFan,
    superFanLevel,
    streakFinal,
  } = req.body || {};
  const u = userKeyFrom(req.body || {});
  if (!u) return res.status(400).json({ ok: false, error: "user required" });
  if (displayName) pointStore.setDisplayName(u, displayName);
  if (superFan === true && typeof pointStore.setSuperFan === "function") {
    pointStore.setSuperFan(u, true, superFanLevel);
  }

  pointStore.ensureAccount(u);
  let gained = 0;
  let rewardMeta = null;

  if (type === "share") {
    gained = SHARE_BONUS;
    pointStore.add(u, gained, { countAsEarned: true });
    pointStore.awardXP(u, "CHAT_MESSAGE", 0.6);
  } else if (type === "gift") {
    const superFanActive =
      superFan === true ||
      (typeof pointStore.isSuperFan === "function" && pointStore.isSuperFan(u));
    const payout = resolveGiftPayout({
      reportedCoins: coins,
      giftCount,
      giftName,
      superFan: superFanActive,
      giftCoinMultiplier: GIFT_COIN_MULTIPLIER,
    });
    const c = payout.coins;
    const giftUnits = payout.giftCount;
    if (c <= 0) {
      return res.json({ ok: true, ignored: true, balance: pointStore.getBalance(u) });
    }
    if (isDuplicateGiftPayout(u, giftName, giftUnits, c)) {
      return res.json({
        ok: true,
        ignored: true,
        duplicate: true,
        balance: pointStore.getBalance(u),
      });
    }
    if (
      streakFinal &&
      isDuplicateStreakSettlement(u, giftId || giftName, groupId, giftUnits)
    ) {
      return res.json({
        ok: true,
        ignored: true,
        duplicateStreak: true,
        balance: pointStore.getBalance(u),
      });
    }
    if (payout.adjusted) {
      console.warn(
        `[gift] auto-corrected ${u}: ${payout.reportedCoins} coins / count ${giftCount} -> ${c} coins x${giftUnits} (${giftName || "gift"})`
      );
    }
    gained = payout.points;
    pointStore.add(u, gained, { countAsEarned: true });
    appendGiftLedger({
      user: u,
      giftName: giftName || "",
      giftCount: giftUnits,
      reportedCoins: payout.reportedCoins,
      creditedCoins: c,
      points: gained,
      superFan: superFanActive,
      adjusted: payout.adjusted,
    });
    pointStore.awardXP(u, "GIFT_RECEIVED", Math.max(1, c / 20));
    pointStore.recordMissionProgress(u, "GIFT_COINS", c);
    pointStore.grantAchievement(u, "first_gift");

    const giftNameNorm = String(giftName || "").trim();
    const giftNameLower = giftNameNorm.toLowerCase();
    if (giftNameLower.includes("galaxy")) {
      const charges = giftUnits;
      const armed = game.armSteal(u, charges);
      rewardMeta = { special: "galaxy_arm", stealsReady: armed.stealsReady || charges };
    } else if (giftNameLower.includes("interstellar")) {
      const claim = pointStore.claimTaxPot(u, "interstellar_gift");
      rewardMeta = {
        special: "interstellar_tax_claim",
        claimed: !!claim.ok,
        claimedAmount: claim.ok ? claim.claimedAmount : 0,
        potNow: claim && claim.potAmount != null ? claim.potAmount : 0,
      };
      if (claim.ok) {
        gained += Number(claim.claimedAmount || 0);
      }
    } else if (giftNameLower.includes("car drifting")) {
      const charges = giftUnits;
      const armedBreak = game.armShieldBreak(u, charges);
      rewardMeta = {
        special: "car_drifting_break_arm",
        shieldBreaksReady: armedBreak.shieldBreaksReady || charges,
      };
    } else if (giftNameLower.includes("flying jet")) {
      const charges = giftUnits;
      const armedJet = game.armJetLock(u, charges);
      rewardMeta = {
        special: "flying_jet_lock_arm",
        jetLocksReady: armedJet.jetLocksReady || charges,
      };
    } else if (giftNameLower.includes("racing debut")) {
      const stacks = giftUnits;
      const shield = game.applyShield(u, SHIELD_DURATION_MS * stacks);
      rewardMeta = {
        special: "shield_applied",
        shieldUntil: shield.shieldUntil,
        shieldHours: 48 * stacks,
        shieldStacks: stacks,
      };
    }
    if (superFanActive) {
      rewardMeta = {
        ...(rewardMeta || {}),
        superfanGiftBoost: true,
        multiplier: 2,
        baseGiftCoinMultiplier: GIFT_COIN_MULTIPLIER,
      };
    }
    rewardMeta = {
      ...(rewardMeta || {}),
      giftCount: giftUnits,
      giftCoins: c,
      points: gained,
      autoCorrected: payout.adjusted,
    };
  } else if (type === "like") {
    const n = Math.max(1, Math.floor(Number(req.body.count) || 1));
    const likeMultiplier = typeof pointStore.isSuperFan === "function" && pointStore.isSuperFan(u) ? 3 : 1;
    gained = n * LIKE_POINTS_PER * likeMultiplier;
    pointStore.add(u, gained, { countAsEarned: true });
    pointStore.awardXP(u, "CHAT_MESSAGE", 0.3);
    pointStore.recordMissionProgress(u, "LIKE_EVENT", n);
    if (likeMultiplier > 1) {
      rewardMeta = {
        special: "superfan_like_boost",
        multiplier: likeMultiplier,
        baseLikePoints: LIKE_POINTS_PER,
      };
    }
  } else if (type === "repost") {
    gained = REPOST_BONUS;
    pointStore.add(u, gained, { countAsEarned: true });
    pointStore.awardXP(u, "CHAT_MESSAGE", 0.8);
  } else {
    return res.status(400).json({ ok: false, error: "bad type" });
  }

  const balance = pointStore.getBalance(u);
  broadcast({
    type: "reward",
    payload: {
      user: u,
      displayName: pointStore.getDisplayName(u),
      nameStyle: pointStore.getNameStyle(u),
      nameBadge: typeof pointStore.getNameBadge === "function" ? pointStore.getNameBadge(u) : "none",
      superFan: typeof pointStore.isSuperFan === "function" ? pointStore.isSuperFan(u) : false,
      superFanLevel: typeof pointStore.getSuperFanLevel === "function" ? pointStore.getSuperFanLevel(u) : 0,
      superFanIcon: typeof pointStore.getSuperFanIcon === "function" ? pointStore.getSuperFanIcon(u) : -1,
      level: pointStore.getLevel(u),
      rank: pointStore.getRank(u),
      kind: type,
      giftName: giftName || null,
      gained,
      balance,
      allTime: pointStore.getAllTime(u),
      rewardMeta,
    },
  });
  pushState();
  res.json({ ok: true, user: u, gained, balance, allTime: pointStore.getAllTime(u), rewardMeta });
});

app.post("/api/economy/daily-bonus", (req, res) => {
  const user = userKeyFrom(req.body || {});
  if (!user) return res.status(400).json({ ok: false, error: "user required" });
  const out = pointStore.claimDailyBonus(user);
  pushState();
  res.json(out);
});

app.post("/api/economy/rakeback", (req, res) => {
  const user = userKeyFrom(req.body || {});
  const period = String(req.body?.period || "daily").toLowerCase() === "weekly" ? "weekly" : "daily";
  if (!user) return res.status(400).json({ ok: false, error: "user required" });
  const out = pointStore.computeRakeback(user, period);
  pushState();
  res.json(out);
});

app.get("/api/economy/profile/:user", (req, res) => {
  const user = userKeyFrom({ user: req.params.user });
  if (!user) return res.status(400).json({ ok: false, error: "user required" });
  const view = pointStore.getUserPresentation(user);
  const economy = pointStore.getEconomyProfile(user);
  res.json({
    ok: true,
    user: view.user,
    displayName: view.displayName,
    nameStyle: view.nameStyle,
    nameBadge: view.nameBadge || "none",
    ownedBadges: Array.isArray(view.ownedBadges) ? view.ownedBadges : [],
    superFan: !!view.superFan,
    superFanLevel: Math.max(0, Math.floor(Number(view.superFanLevel) || 0)),
    superFanIcon: Math.max(-1, Math.floor(Number(view.superFanIcon) || -1)),
    level: view.level,
    rank: view.rank,
    balance: pointStore.getBalance(user),
    allTime: pointStore.getAllTime(user),
    xp: economy ? economy.xp : 0,
    dailyStreak: economy ? economy.dailyStreak : 0,
    missions: economy ? economy.missions : [],
  });
});

app.get("/api/economy/lookup/:user", (req, res) => {
  const user = userKeyFrom({ user: req.params.user });
  if (!user) return res.status(400).json({ ok: false, error: "user required" });
  pointStore.ensureAccount(user);
  const view = pointStore.getUserPresentation(user);
  const economy = pointStore.getEconomyProfile(user);
  const shield = pointStore.getShieldStatus(user);
  const inventory =
    typeof pointStore.getPowerupInventory === "function"
      ? pointStore.getPowerupInventory(user)
      : { stealCharges: 0, shieldBreakCharges: 0, jetLockCharges: 0 };
  const reset = pointStore.getMissionResetInfo();
  const jetLock = typeof game.getJetLockStatus === "function" ? game.getJetLockStatus(user) : null;
  res.json({
    ok: true,
    user: view.user,
    displayName: view.displayName,
    nameStyle: view.nameStyle,
    nameBadge: view.nameBadge || "none",
    ownedBadges: Array.isArray(view.ownedBadges) ? view.ownedBadges : [],
    superFan: !!view.superFan,
    superFanLevel: Math.max(0, Math.floor(Number(view.superFanLevel) || 0)),
    superFanIcon: Math.max(-1, Math.floor(Number(view.superFanIcon) || -1)),
    level: view.level,
    rank: view.rank,
    balance: pointStore.getBalance(user),
    allTime: pointStore.getAllTime(user),
    xp: economy ? economy.xp : 0,
    dailyStreak: economy ? economy.dailyStreak : 0,
    missions: economy ? economy.missions : [],
    missionResetAtMs: reset.resetAtMs,
    missionResetSeconds: reset.secondsUntilReset,
    missionResetTimezone: reset.timezone,
    shieldActive: shield.active,
    shieldMsLeft: shield.msLeft || 0,
    shieldUntil: shield.shieldUntil || 0,
    jetLockActive: !!(jetLock && jetLock.active),
    jetLockMsLeft: jetLock ? Number(jetLock.msLeft || 0) : 0,
    jetLockSecondsLeft: jetLock ? Number(jetLock.secondsLeft || 0) : 0,
    jetLockUntil: jetLock ? Number(jetLock.blockedUntil || 0) : 0,
    inventory,
  });
});

app.get("/api/economy/notifications", (req, res) => {
  const limit = Number(req.query.limit) || 40;
  res.json({ ok: true, notifications: pointStore.getNotifications(limit) });
});

app.get("/api/economy/missions", (_req, res) => {
  res.json({ ok: true, missions: pointStore.getMissionDefinitions(), ...pointStore.getMissionResetInfo() });
});

app.post("/api/admin/points", (req, res) => {
  if (!isLocalhost(req)) {
    return res.status(403).json({ ok: false, error: "local only" });
  }
  const { user, set, add, notify } = req.body || {};
  const u = String(user || "").trim().replace(/^@+/, "").slice(0, 40);
  if (!u) return res.status(400).json({ ok: false, error: "user required" });
  pointStore.ensureAccount(u);
  if (req.body?.displayName) pointStore.setDisplayName(u, req.body.displayName);
  const before = pointStore.getBalance(u);
  if (set != null) {
    pointStore.setBalance(u, set);
  } else if (add != null) {
    pointStore.add(u, add);
  } else {
    return res.status(400).json({ ok: false, error: "set or add required" });
  }
  if (notify && typeof pointStore.sendInGameNotification === "function") {
    pointStore.sendInGameNotification(u, "gift_adjustment", String(notify));
  }
  pushState();
  res.json({
    ok: true,
    user: u,
    before,
    balance: pointStore.getBalance(u),
    allTime: pointStore.getAllTime(u),
  });
});

app.post("/api/admin/reload-points", (req, res) => {
  if (!isLocalhost(req)) {
    return res.status(403).json({ ok: false, error: "local only" });
  }
  pointStore.reloadFromDisk();
  pushState();
  res.json({ ok: true, reloaded: true });
});

app.get("/api/leaderboard", (req, res) => {
  const limit = Math.max(1, Math.min(100, Number(req.query?.limit) || 15));
  res.setHeader("Cache-Control", "no-store, max-age=0");
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.json({ top: pointStore.snapshotTop(limit) });
});

app.get("/api/balances", (req, res) => {
  const total = pointStore.listBalances(999999).length;
  const rawLimit = String(req.query.limit || "50").trim().toLowerCase();
  let limit = 50;
  if (rawLimit === "all" || rawLimit === "0") limit = 999999;
  else {
    const n = parseInt(rawLimit, 10);
    if (Number.isFinite(n) && n > 0) limit = Math.min(999999, n);
  }
  const rows = pointStore.listBalances(limit).map((row) => {
    const lock = typeof game.getJetLockStatus === "function" ? game.getJetLockStatus(row.user) : null;
    return {
      ...row,
      jetLockActive: !!(lock && lock.active),
      jetLockMsLeft: lock ? Number(lock.msLeft || 0) : 0,
      jetLockSecondsLeft: lock ? Number(lock.secondsLeft || 0) : 0,
      jetLockUntil: lock ? Number(lock.blockedUntil || 0) : 0,
    };
  });
  res.json({ balances: rows, total, shown: rows.length });
});

app.post("/api/round/start", (_req, res) => {
  game.startRound();
  res.json({ ok: true, state: game.getState() });
});

app.post("/api/config/starter", (req, res) => {
  const v = Number(req.body?.starterPoints);
  if (!Number.isFinite(v) || v < 0) {
    return res.status(400).json({ ok: false });
  }
  pointStore.defaultStarter = Math.floor(v);
  res.json({ ok: true, starterPoints: pointStore.defaultStarter });
});

app.get("/api/config/starter", (_req, res) => {
  res.json({ starterPoints: pointStore.defaultStarter });
});

/** Full status-icon shop (50M–500M tiers). */
app.get("/api/config/badges", (_req, res) => {
  res.json({ ok: true, badges: listNameBadgeShop() });
});

/** Values shown on the stream overlay “how to earn points” panel (matches env defaults). */
app.get("/api/config/rewards", (_req, res) => {
  res.json({
    starterPoints: pointStore.defaultStarter,
    shareBonus: SHARE_BONUS,
    giftCoinMultiplier: GIFT_COIN_MULTIPLIER,
    likePointsPer: LIKE_POINTS_PER,
    repostBonus: REPOST_BONUS,
    galaxyGift: "Galaxy",
    interstellarGift: "Interstellar",
    carDriftingGift: "Car Drifting",
    flyingJetGift: "Flying Jet",
    spotifyConfigured: spotifyConfigured(),
    shieldGift: "Racing Debut",
    betTaxPercent: 5,
    shieldHours: 48,
    balanceCooldownSeconds: Math.floor(BALANCE_SHOUT_COOLDOWN_MS / 1000),
    iconsPopupCooldownSeconds: Math.floor(ICONS_POPUP_COOLDOWN_MS / 1000),
    iconsPopupDurationSeconds: Math.floor(ICONS_POPUP_DURATION_MS / 1000),
    spinTicketCost: SPIN_TICKET_COST,
    pinMessageCost: PIN_MESSAGE_COST,
    pinMessageDurationSeconds: Math.floor(PIN_MESSAGE_DURATION_MS / 1000),
    bountyMinPoints: BOUNTY_MIN_POINTS,
    nameStyleShop: [
      { id: "neon", icon: "✨", cost: 2_000_000 },
      { id: "royal", icon: "👑", cost: 3_000_000 },
      { id: "fire", icon: "🔥", cost: 4_000_000 },
      { id: "ice", icon: "❄️", cost: 4_000_000 },
      { id: "shadow", icon: "🌑", cost: 5_000_000 },
      { id: "rainbow", icon: "🌈", cost: 7_000_000 },
      { id: "pulse", icon: "💫", cost: 6_000_000 },
      { id: "glitch", icon: "⚡", cost: 8_000_000 },
    ],
    nameBadgeShop: listNameBadgeShop().map((b) => ({
      id: b.id,
      label: b.label,
      short: b.short,
      tier: b.tier,
      cost: b.cost,
    })),
  });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });

wss.on("connection", (ws) => {
  clients.add(ws);
  ws.send(JSON.stringify({ type: "state", payload: game.getState() }));
  ws.on("close", () => clients.delete(ws));
});

attachHangmanWebSocketProxy(server, wss);

function openBrowser(url) {
  if (process.env.NO_BROWSER === "1") return;
  try {
    if (process.platform === "win32") {
      const chromeCandidates = [
        "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
        "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
      ];
      for (const chrome of chromeCandidates) {
        if (fs.existsSync(chrome)) {
          spawn(chrome, [url], { detached: true, stdio: "ignore", windowsHide: true }).unref();
          return;
        }
      }
      spawn("cmd", ["/c", "start", "", url], {
        detached: true,
        stdio: "ignore",
        windowsHide: true,
      }).unref();
      return;
    }
    if (process.platform === "darwin") {
      spawn("open", [url], { detached: true, stdio: "ignore" }).unref();
      return;
    }
    spawn("xdg-open", [url], { detached: true, stdio: "ignore" }).unref();
  } catch (e) {
    console.warn("Could not open browser:", e.message);
  }
}

function getLanUrls(port) {
  const out = [];
  const ifaces = os.networkInterfaces();
  for (const rows of Object.values(ifaces)) {
    if (!Array.isArray(rows)) continue;
    for (const row of rows) {
      if (!row || row.family !== "IPv4" || row.internal) continue;
      out.push(`http://${row.address}:${port}/`);
    }
  }
  return [...new Set(out)];
}

server.listen(PORT, SERVER_HOST, () => {
  const url = `http://127.0.0.1:${PORT}/`;
  const lanUrls = getLanUrls(PORT);
  console.log("");
  console.log("============================================================");
  console.log("  NFG CRASH — open this address in Chrome (or any browser):");
  console.log("");
  console.log("   ", url);
  console.log("");
  console.log("  Keep this window open while you play. Close it to stop.");
  console.log("  If no tab opened, copy the link above into the address bar.");
  console.log("============================================================");
  console.log("");
  console.log(`Starter points for new names: ${STARTER_POINTS}`);
  console.log(
    `Bet cap: ${MAX_BET >= Number.MAX_SAFE_INTEGER ? "unlimited (no practical cap)" : MAX_BET.toLocaleString()}`
  );
  console.log(`Listening on: ${SERVER_HOST}:${PORT}`);
  if (hasReactWebsiteBuild) {
    console.log(`Marketing website: https://y666suf.com (same port ${PORT}, React build)`);
    console.log(`  Local pages: http://127.0.0.1:${PORT}/games/nfg-crash  /privacy  /sideload`);
  } else {
    console.log("Marketing website: run frontend build (corepack yarn build in _import_Y666SUF_website/frontend)");
  }
  for (const appId of ["crash", "hangman"]) {
    const ipaMeta = getIpaDownloadMeta(appId);
    const catalog = IPA_CATALOG[appId];
    if (ipaMeta.ok) {
      const mb = (ipaMeta.size / (1024 * 1024)).toFixed(1);
      console.log(`iOS download [${appId}]: ${catalog.downloadPath} ← ${ipaMeta.path} (${mb} MB)`);
    } else {
      console.log(`iOS download [${appId}]: ${catalog.downloadPath} — no .ipa (set ${catalog.envVar})`);
    }
  }
  if (lanUrls.length) {
    console.log("LAN URLs for iPhone/Mac:");
    for (const lan of lanUrls) console.log("  ", lan);
  }
  console.log(`Hangman backend port: ${HANGMAN_PORT} (WebSocket proxy: /hangman/ws)`);
  startHangmanProcess();
  waitForHangman()
    .then(() => console.log("[Hangman] Ready (proxied through this server)."))
    .catch((e) => console.warn("[Hangman] Not ready yet:", e.message));

  openBrowser(url);
  startTikTokBridge({ port: PORT });

  const runScheduledBackup = () => {
    try {
      const out = pointStore.createDataBackup({ keepLatest: AUTO_BACKUP_KEEP_LATEST });
      if (out && out.ok) {
        console.log(`[Backup] Saved snapshot: ${out.backupDir}`);
      }
    } catch (e) {
      console.warn("[Backup] Snapshot failed:", e.message);
    }
  };
  runScheduledBackup();
  setInterval(runScheduledBackup, AUTO_BACKUP_INTERVAL_MS);

  if (AUTO_ROUND_MS > 0) {
    setTimeout(() => {
      try {
        game.startRound();
      } catch (e) {
        console.warn("Auto start round:", e.message);
      }
    }, 2500);
  }
});
