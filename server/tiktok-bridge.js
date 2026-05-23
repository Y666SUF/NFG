const http = require("http");
const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");
const { giftDelta, flushStaleStreakCombos } = require("./gift-combo");
const { forwardTikTokCommentToHangman } = require("./hangman-tiktok-forward");

/** Exposed to mobile app via /api/mobile/status */
let bridgeStatus = {
  enabled: false,
  uniqueId: "y666.suf",
  state: "disabled", // disabled | waiting | live | offline
  roomId: null,
  viewerCount: null,
  updatedAt: 0,
};

function setBridgeStatus(patch) {
  Object.assign(bridgeStatus, patch, { updatedAt: Date.now() });
}

function getTikTokBridgeStatus() {
  return { ...bridgeStatus };
}

function loadTikTokConfig() {
  const defaults = { uniqueId: "y666.suf", enabled: true, sendBalanceChatReply: true };
  const file = path.join(getAppRoot(), "tiktok.config.json");
  if (!fs.existsSync(file)) {
    return { ...defaults };
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    return { ...defaults, ...parsed };
  } catch {
    return { ...defaults };
  }
}

function postChat(port, payload) {
  const body = JSON.stringify(payload || {});
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: "127.0.0.1",
        port,
        path: "/api/chat",
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body, "utf8"),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          try {
            const text = Buffer.concat(chunks).toString("utf8");
            resolve(text ? JSON.parse(text) : null);
          } catch {
            resolve(null);
          }
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function isTruthyFlag(v) {
  if (v === true) return true;
  if (typeof v === "number") return v > 0;
  if (typeof v === "string") {
    const t = v.trim().toLowerCase();
    return t === "1" || t === "true" || t === "yes" || t === "superfan" || t === "super fan";
  }
  return false;
}

function detectSuperFan(data) {
  const user = (data && data.user) || {};
  const direct = [
    data?.isSuperFan,
    data?.superFan,
    data?.super_fan,
    data?.isFansClubMember,
    data?.isFanClubMember,
    user?.isSuperFan,
    user?.superFan,
    user?.super_fan,
    user?.isFansClubMember,
    user?.isFanClubMember,
    user?.fanClubMember,
    user?.fansClubMember,
  ];
  if (direct.some(isTruthyFlag)) return true;
  try {
    const raw = JSON.stringify({ user, badges: data?.badges, userBadges: user?.badges }).toLowerCase();
    if (raw.includes("superfan") || raw.includes("super fan")) return true;
    if (raw.includes("fans club") || raw.includes("fan club")) return true;
  } catch {
    /* ignore */
  }
  return false;
}

function collectPossibleSuperFanLevels(root, out, depth = 0) {
  if (!root || depth > 5) return;
  if (Array.isArray(root)) {
    for (const item of root) collectPossibleSuperFanLevels(item, out, depth + 1);
    return;
  }
  if (typeof root !== "object") return;
  for (const [k, v] of Object.entries(root)) {
    const key = String(k || "").toLowerCase();
    if (
      (key.includes("fan") || key.includes("heart") || key.includes("badge") || key.includes("club")) &&
      (key.includes("level") || key.includes("grade") || key.includes("tier"))
    ) {
      const n = Math.floor(Number(v) || 0);
      if (n > 0) out.push(n);
    }
    if (v && typeof v === "object") collectPossibleSuperFanLevels(v, out, depth + 1);
  }
}

function extractSuperFanLevel(data) {
  const candidates = [];
  collectPossibleSuperFanLevels(data?.user, candidates);
  collectPossibleSuperFanLevels(data?.badges, candidates);
  collectPossibleSuperFanLevels(data?.userBadges, candidates);
  collectPossibleSuperFanLevels(data, candidates);
  if (!candidates.length) return 0;
  return Math.max(0, Math.floor(Math.max(...candidates)));
}

function postReward(port, payload) {
  const body = JSON.stringify(payload);
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: "127.0.0.1",
        port,
        path: "/api/tiktok/reward",
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body, "utf8"),
        },
      },
      (res) => {
        res.resume();
        res.on("end", resolve);
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function postUserMeta(port, payload) {
  const body = JSON.stringify(payload);
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: "127.0.0.1",
        port,
        path: "/api/tiktok/user-meta",
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body, "utf8"),
        },
      },
      (res) => {
        res.resume();
        res.on("end", resolve);
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

/** Best-effort: detect live “repost” style events (payloads vary by TikTok version). */
function looksLikeRepost(data) {
  try {
    const j = JSON.stringify(data).toLowerCase();
    if (j.includes("repost") || j.includes("re-post")) return true;
  } catch {
    /* ignore */
  }
  const dt = data.common?.displayType ?? data.displayType ?? data.actionType;
  if (dt != null && String(dt).toLowerCase().includes("repost")) return true;
  return false;
}

/** One LIKE event = one or a small batch of likes (capped). */
function likeDeltaCount(data) {
  const raw = Number(data.count ?? data.comboCount ?? data.likeCount);
  if (Number.isFinite(raw) && raw >= 1) return Math.min(10, Math.floor(raw));
  return 1;
}

/**
 * Forwards TikTok LIVE chat + rewards to localhost HTTP.
 * Repost bonus: once per user per live connection (in-memory Set).
 */
function startTikTokBridge(options) {
  const port = options.port || 3847;

  if (process.env.TIKTOK_BRIDGE === "0") {
    setBridgeStatus({ enabled: false, state: "disabled", roomId: null });
    console.log("[TikTok] Bridge off (TIKTOK_BRIDGE=0).");
    return;
  }

  const cfg = loadTikTokConfig();
  if (cfg.enabled === false) {
    setBridgeStatus({ enabled: false, state: "disabled", roomId: null });
    console.log("[TikTok] Bridge off (tiktok.config.json enabled:false).");
    return;
  }

  const uniqueId = String(process.env.TIKTOK_USERNAME || cfg.uniqueId || "y666.suf")
    .replace(/^@/, "")
    .trim();
  setBridgeStatus({ enabled: true, uniqueId, state: "waiting", roomId: null });

  let TikTokLiveConnection;
  let WebcastEvent;
  try {
    ({ TikTokLiveConnection, WebcastEvent } = require("tiktok-live-connector"));
  } catch (e) {
    console.error("[TikTok] Missing package. Run: npm install", e.message);
    return;
  }

  const evChat = WebcastEvent.CHAT || "chat";
  const evEnd = WebcastEvent.STREAM_END || "streamEnd";
  const evShare = WebcastEvent.SHARE || "share";
  const evGift = WebcastEvent.GIFT || "gift";
  const evLike = WebcastEvent.LIKE || "like";
  const evSocial = WebcastEvent.SOCIAL || "social";
  const evBarrage = WebcastEvent.BARRAGE || "barrage";
  const evSuperFan = WebcastEvent.SUPER_FAN || "superFan";
  const evRoomUser = WebcastEvent.ROOM_USER || "roomUser";

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  const sendBalanceReply =
    cfg.sendBalanceChatReply !== false && process.env.TIKTOK_SEND_BALANCE_REPLY !== "0";

  const sessionId = process.env.TIKTOK_SESSION_ID || cfg.sessionId;
  const ttTargetIdc = process.env.TIKTOK_TT_TARGET_IDC || cfg.ttTargetIdc;
  const hasChatSendCreds = Boolean(sessionId && ttTargetIdc);

  if (sendBalanceReply && !hasChatSendCreds) {
    console.log(
      "[TikTok] Balance replies to live chat need sessionId + ttTargetIdc (env or tiktok.config.json). See tiktok-live-connector sendMessage docs."
    );
  }

  let sendBalanceHintLogged = false;

  (async function loop() {
    console.log(`[TikTok] Bridge on — @${uniqueId} → http://127.0.0.1:${port}/`);

    while (true) {
      const repostPaidThisLive = new Set();
      const giftComboState = new Map();
      const streakFlushTimer = setInterval(() => {
        const flushed = flushStaleStreakCombos(giftComboState);
        for (const row of flushed) {
          if (!row.user || row.coins <= 0) continue;
          postReward(port, {
            type: "gift",
            userId: row.user,
            coins: row.coins,
            giftCount: row.giftCount,
            giftName: row.giftName,
            giftId: row.giftId,
            streakFlushed: true,
          }).catch((err) => {
            console.error("[TikTok] Streak flush reward:", err.message);
          });
        }
      }, 2000);

      const connectionOpts = {
        processInitialData: false,
        // Fetching the gift catalog often returns 403 from TikTok and can drop the connection.
        // Gift events still include coin/diamond values without this.
        enableExtendedGiftInfo: false,
        // Avoid proxy/intercepted websocket routes that can return HTTP 200
        // instead of the expected WS upgrade (101).
        wsClientOptions: { agent: false },
        webClientOptions: { proxy: false },
      };
      if (hasChatSendCreds) {
        connectionOpts.sessionId = sessionId;
        connectionOpts.ttTargetIdc = ttTargetIdc;
      }

      const connection = new TikTokLiveConnection(uniqueId, connectionOpts);

      const markSuperFan = (data) => {
        const userId = data?.user && (data.user.uniqueId || data.user.nickname);
        const displayName = data?.user && (data.user.nickname || data.user.uniqueId || userId);
        const superFanLevel = extractSuperFanLevel(data);
        if (!userId) return;
        postUserMeta(port, { userId, displayName, superFan: true, superFanLevel }).catch((err) => {
          console.error("[TikTok] Superfan meta forward:", err.message);
        });
      };

      connection.on(evChat, (data) => {
        const userId = (data.user && (data.user.uniqueId || data.user.nickname)) || "viewer";
        const displayName = (data.user && (data.user.nickname || data.user.uniqueId)) || userId;
        const message = String(data.comment || "").trim();
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!message) return;
        if (/^!link\s+[A-Fa-f0-9]{6}\s*$/i.test(message)) {
          console.log(`[TikTok] Link attempt from @${userId}: ${message}`);
        }
        forwardTikTokCommentToHangman({ userId, displayName, message, superFan }).catch((err) => {
          console.error("[TikTok] Hangman comment forward:", err.message);
        });
        postChat(port, { userId, displayName, message, superFan, superFanLevel })
          .then(async (j) => {
            const reply = j && j.tiktokChatReply;
            if (!reply || !sendBalanceReply || !hasChatSendCreds) return;
            try {
              await connection.sendMessage(reply);
            } catch (err) {
              if (!sendBalanceHintLogged) {
                console.error(
                  "[TikTok] Could not post balance to live chat:",
                  err && err.message ? err.message : err
                );
                sendBalanceHintLogged = true;
              }
            }
          })
          .catch((err) => {
            console.error("[TikTok] Forward error:", err.message);
          });
      });

      connection.on(evShare, (data) => {
        const userId = data.user && (data.user.uniqueId || data.user.nickname);
        const displayName = data.user && (data.user.nickname || data.user.uniqueId || userId);
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!userId) return;
        if (looksLikeRepost(data)) {
          if (repostPaidThisLive.has(userId)) return;
          repostPaidThisLive.add(userId);
          postReward(port, { type: "repost", userId, displayName, superFan, superFanLevel }).catch((err) => {
            console.error("[TikTok] Repost reward:", err.message);
          });
          return;
        }
        postReward(port, { type: "share", userId, displayName, superFan, superFanLevel }).catch((err) => {
          console.error("[TikTok] Share reward:", err.message);
        });
      });

      connection.on(evGift, (data) => {
        const userId = data.user && (data.user.uniqueId || data.user.nickname);
        const displayName = data.user && (data.user.nickname || data.user.uniqueId || userId);
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!userId) return;
        const gift = giftDelta(data, giftComboState, userId);
        const coins = gift.coins;
        if (coins <= 0) return;
        postReward(port, {
          type: "gift",
          userId,
          displayName,
          superFan,
          superFanLevel,
          coins,
          giftCount: gift.giftCount,
          giftName: gift.giftName,
          giftId: gift.giftId,
          groupId: data.groupId ?? data.group_id ?? "0",
          streakFinal: gift.streakFinal === true,
        }).catch((err) => {
          console.error("[TikTok] Gift reward:", err.message);
        });
      });

      connection.on(evLike, (data) => {
        const userId = data.user && (data.user.uniqueId || data.user.nickname);
        const displayName = data.user && (data.user.nickname || data.user.uniqueId || userId);
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!userId) return;
        const count = likeDeltaCount(data);
        postReward(port, { type: "like", userId, displayName, superFan, superFanLevel, count }).catch((err) => {
          console.error("[TikTok] Like reward:", err.message);
        });
      });

      connection.on(evSocial, (data) => {
        const userId = data.user && (data.user.uniqueId || data.user.nickname);
        const displayName = data.user && (data.user.nickname || data.user.uniqueId || userId);
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!userId || !looksLikeRepost(data)) return;
        if (repostPaidThisLive.has(userId)) return;
        repostPaidThisLive.add(userId);
        postReward(port, { type: "repost", userId, displayName, superFan, superFanLevel }).catch((err) => {
          console.error("[TikTok] Repost (social) reward:", err.message);
        });
      });

      connection.on(evSuperFan, (data) => {
        markSuperFan(data);
      });

      connection.on(evBarrage, (data) => {
        if (detectSuperFan(data)) {
          markSuperFan(data);
        }
      });

      connection.on(evRoomUser, (data) => {
        const raw = Number(data?.viewerCount ?? data?.viewer_count ?? data?.totalUser ?? 0);
        if (!Number.isFinite(raw) || raw < 0) return;
        setBridgeStatus({ viewerCount: Math.floor(raw) });
      });

      try {
        console.log(`[TikTok] Waiting until @${uniqueId} is LIVE...`);
        setBridgeStatus({ state: "waiting", roomId: null });
        await connection.waitUntilLive();
        setBridgeStatus({ state: "live" });
        console.log("[TikTok] Live — connecting...");
        const state = await connection.connect();
        const roomId = state?.roomId ? String(state.roomId) : null;
        setBridgeStatus({ state: "live", roomId });
        console.log("[TikTok] Connected.", state && state.roomId ? `roomId=${state.roomId}` : "");

        await new Promise((resolve) => {
          const done = () => resolve();
          connection.once(evEnd, done);
          connection.once("disconnected", done);
          connection.once("error", done);
        });
      } catch (err) {
        setBridgeStatus({ state: "offline", roomId: null });
        console.error("[TikTok]", err.message || err);
      } finally {
        setBridgeStatus({ state: "waiting", roomId: null });
        clearInterval(streakFlushTimer);
        const flushed = flushStaleStreakCombos(giftComboState);
        for (const row of flushed) {
          if (!row.user || row.coins <= 0) continue;
          postReward(port, {
            type: "gift",
            userId: row.user,
            coins: row.coins,
            giftCount: row.giftCount,
            giftName: row.giftName,
            giftId: row.giftId,
            streakFlushed: true,
          }).catch(() => {});
        }
        try {
          connection.disconnect();
        } catch (_) {
          /* ignore */
        }
      }

      console.log("[TikTok] Stream ended or lost connection; retrying in 5s...");
      await sleep(5000);
    }
  })().catch((e) => console.error("[TikTok] Fatal:", e));
}

module.exports = { startTikTokBridge, loadTikTokConfig, getTikTokBridgeStatus };
