/**
 * In-app chat between mobile players (separate from TikTok !commands).
 */
const crypto = require("crypto");
const { playerBadgesFromStore } = require("./mobile-player-badges");

const MAX_MESSAGES = 120;
const MAX_MESSAGE_LEN = 240;
const RATE_LIMIT_MS = 1200;

/** @type {Array<object>} */
const messages = [];
/** @type {Map<string, number>} */
const lastSentAt = new Map();

function enrichChatRow(row, pointStore) {
  if (!row || !row.userId) return row;
  return { ...row, ...playerBadgesFromStore(pointStore, row.userId) };
}

function listMessages(limit = 50, pointStore) {
  const n = Math.min(MAX_MESSAGES, Math.max(1, Math.floor(Number(limit) || 50)));
  return messages.slice(-n).map((row) => enrichChatRow(row, pointStore));
}

function appendMessage(row) {
  messages.push(row);
  while (messages.length > MAX_MESSAGES) messages.shift();
}

function registerMobileChatRoutes(app, ctx) {
  const { broadcast, validateBearer, pointStore } = ctx;

  app.get("/api/mobile/chat", (req, res) => {
    const limit = Number(req.query.limit) || 50;
    res.json({ ok: true, messages: listMessages(limit, pointStore) });
  });

  app.post("/api/mobile/chat", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }

    const raw = String(req.body?.message || "").trim();
    if (!raw) {
      return res.status(400).json({ ok: false, error: "empty_message" });
    }
    if (raw.length > MAX_MESSAGE_LEN) {
      return res.status(400).json({ ok: false, error: "message_too_long", max: MAX_MESSAGE_LEN });
    }
    if (raw.startsWith("!")) {
      return res.status(400).json({
        ok: false,
        error: "commands_not_allowed",
        message: "Use the bet box for !commands. App chat is for messages only.",
      });
    }

    const now = Date.now();
    const last = lastSentAt.get(session.userId) || 0;
    if (now - last < RATE_LIMIT_MS) {
      const wait = Math.ceil((RATE_LIMIT_MS - (now - last)) / 1000);
      return res.status(429).json({ ok: false, error: "rate_limited", secondsLeft: wait });
    }
    lastSentAt.set(session.userId, now);

    const row = enrichChatRow(
      {
        id: crypto.randomBytes(8).toString("hex"),
        userId: session.userId,
        displayName: session.displayName || session.userId,
        message: raw,
        at: now,
      },
      pointStore
    );
    appendMessage(row);

    const badge = row.superFan ? " ★" : "";
    console.log(`[App chat] ${row.displayName}${badge} (@${row.userId}): ${row.message}`);

    if (typeof broadcast === "function") {
      broadcast({ type: "app_chat", payload: row });
    }
    res.json({ ok: true, message: row });
  });
}

module.exports = { registerMobileChatRoutes, listMessages };
