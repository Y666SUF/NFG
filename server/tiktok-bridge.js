const http = require("http");
const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");
const { giftDelta, flushStaleStreakCombos } = require("./gift-combo");

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

const BRIDGE_TARGET_OPTIONS = ["y666.suf", "y666sxf"];
const bridgeRuntime = {
  desiredUniqueId: null,
  activeConnection: null,
  targetVersion: 0,
};

function normalizeBridgeTarget(raw) {
  const next = String(raw || "")
    .replace(/^@/, "")
    .trim()
    .toLowerCase();
  if (!next) return null;
  return BRIDGE_TARGET_OPTIONS.includes(next) ? next : null;
}

function saveTikTokConfig(patch = {}) {
  const file = path.join(getAppRoot(), "tiktok.config.json");
  const current = loadTikTokConfig();
  const next = { ...current, ...patch };
  try {
    fs.writeFileSync(file, JSON.stringify(next, null, 2), "utf8");
    return true;
  } catch {
    return false;
  }
}

function getTikTokBridgeTarget() {
  return (
    normalizeBridgeTarget(bridgeRuntime.desiredUniqueId) ||
    normalizeBridgeTarget(loadTikTokConfig().uniqueId) ||
    BRIDGE_TARGET_OPTIONS[0]
  );
}

function setTikTokBridgeTarget(rawUniqueId, options = {}) {
  const persist = options.persist !== false;
  const next = normalizeBridgeTarget(rawUniqueId);
  if (!next) {
    return {
      ok: false,
      error: "invalid_unique_id",
      options: [...BRIDGE_TARGET_OPTIONS],
      uniqueId: getTikTokBridgeTarget(),
    };
  }

  bridgeRuntime.desiredUniqueId = next;
  bridgeRuntime.targetVersion += 1;
  setBridgeStatus({ uniqueId: next, state: "waiting", roomId: null });
  if (persist) {
    saveTikTokConfig({ uniqueId: next });
  }

  if (bridgeRuntime.activeConnection) {
    try {
      bridgeRuntime.activeConnection.disconnect();
    } catch {
      /* ignore */
    }
  }

  return { ok: true, uniqueId: next, options: [...BRIDGE_TARGET_OPTIONS] };
}

function loadTikTokConfig() {
  const defaults = { uniqueId: "y666.suf", enabled: true, sendBalanceChatReply: true };
  const file = path.join(getAppRoot(), "tiktok.config.json");
  if (!fs.existsSync(file)) {
    return { ...defaults };
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    const merged = { ...defaults, ...parsed };
    // Keep y666.suf as the startup default even if older config saved y666sxf.
    if (normalizeBridgeTarget(merged.uniqueId) === "y666sxf") {
      merged.uniqueId = "y666.suf";
      try {
        fs.writeFileSync(file, JSON.stringify(merged, null, 2), "utf8");
      } catch {
        /* ignore */
      }
    }
    return merged;
  } catch {
    return { ...defaults };
  }
}

function resolveSignApiKey(cfg = loadTikTokConfig()) {
  const raw =
    process.env.TIKTOK_SIGN_API_KEY ||
    process.env.SIGN_API_KEY ||
    process.env.EULER_API_KEY ||
    cfg.signApiKey ||
    cfg.eulerApiKey ||
    "";
  const key = String(raw || "").trim();
  return key || null;
}

function maskSignApiKey(key) {
  const s = String(key || "");
  if (s.length <= 12) return "(set)";
  return `${s.slice(0, 10)}…${s.slice(-4)}`;
}

/** Stable TikTok viewer id for rewards (matches chat command keys). */
function normTikTokUser(raw) {
  return String(raw || "")
    .trim()
    .replace(/^@+/, "")
    .toLowerCase()
    .slice(0, 40);
}

function extractEventUser(data) {
  const user = data?.user || data?.userInfo || data?.sender || {};
  const uniqueId =
    user.uniqueId ||
    user.unique_id ||
    user.username ||
    user.displayId ||
    user.nickname ||
    user.nickName ||
    data?.uniqueId;
  const displayName =
    user.nickname ||
    user.nickName ||
    user.displayName ||
    uniqueId ||
    "viewer";
  const userId = normTikTokUser(uniqueId || displayName);
  if (!userId || userId === "viewer") return { userId: null, displayName: null };
  return { userId, displayName };
}

function socialDisplayType(data) {
  const dt =
    data?.common?.displayText?.displayType ??
    data?.common?.displayType ??
    data?.displayType ??
    data?.actionType ??
    "";
  return String(dt || "").toLowerCase();
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
  const dt = socialDisplayType(data);
  if (dt.includes("repost") || dt.includes("re-post")) return true;
  try {
    const j = JSON.stringify(data).toLowerCase();
    if (j.includes("repost") || j.includes("re-post")) return true;
  } catch {
    /* ignore */
  }
  return false;
}

/** Best-effort: detect live follow events (payloads vary by TikTok version). */
function looksLikeFollow(data) {
  if (looksLikeRepost(data)) return false;
  const dt = socialDisplayType(data);
  if (dt.includes("follow") && !dt.includes("unfollow")) return true;
  const label = data.label ?? data.event?.eventDetails?.label ?? data.common?.label;
  if (label != null && String(label).toLowerCase().includes("follow")) return true;
  const action = String(data.action ?? "").toLowerCase();
  if (action.includes("follow") && !action.includes("unfollow")) return true;
  try {
    const j = JSON.stringify(data).toLowerCase();
    if (j.includes("unfollow")) return false;
    if (j.includes("pm_main_follow") || j.includes("follow_message")) return true;
  } catch {
    /* ignore */
  }
  return false;
}

/** One LIKE event = one or a small batch of likes (capped). */
function likeDeltaCount(data) {
  const raw = Number(
    data.count ?? data.comboCount ?? data.likeCount ?? data.totalLikeCount ?? data.like_count
  );
  if (Number.isFinite(raw) && raw >= 1) return Math.min(10, Math.floor(raw));
  return 1;
}

const BRIDGE_DEBUG = process.env.TIKTOK_BRIDGE_DEBUG === "1";

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

  const initialUniqueId =
    normalizeBridgeTarget(process.env.TIKTOK_USERNAME || cfg.uniqueId || "y666.suf") ||
    BRIDGE_TARGET_OPTIONS[0];
  bridgeRuntime.desiredUniqueId = initialUniqueId;
  const uniqueId = initialUniqueId;
  setBridgeStatus({ enabled: true, uniqueId, state: "waiting", roomId: null });

  let TikTokLiveConnection;
  let WebcastEvent;
  let SignConfig;
  try {
    const pkg = require("tiktok-live-connector");
    TikTokLiveConnection = pkg.TikTokLiveConnection;
    WebcastEvent = pkg.WebcastEvent;
    SignConfig = pkg.SignConfig;
  } catch (e) {
    console.error("[TikTok] Missing package. Run: npm install", e.message);
    return;
  }

  const signApiKey = resolveSignApiKey(cfg);
  if (signApiKey && SignConfig) {
    SignConfig.apiKey = signApiKey;
  } else {
    console.warn(
      "[TikTok] No Euler sign API key — chat/likes may not connect. Set signApiKey in tiktok.config.json or TIKTOK_SIGN_API_KEY."
    );
  }

  const evChat = WebcastEvent.CHAT || "chat";
  const evEnd = WebcastEvent.STREAM_END || "streamEnd";
  const evShare = WebcastEvent.SHARE || "share";
  const evGift = WebcastEvent.GIFT || "gift";
  const evLike = WebcastEvent.LIKE || "like";
  const evSocial = WebcastEvent.SOCIAL || "social";
  const evFollow = WebcastEvent.FOLLOW || "follow";
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
    console.log(`[TikTok] Bridge on — @${getTikTokBridgeTarget()} → http://127.0.0.1:${port}/`);
    if (signApiKey) {
      console.log(`[TikTok] Euler sign key: ${maskSignApiKey(signApiKey)}`);
    }

    while (true) {
      let retryDelayMs = 5000;
      const activeUniqueId = getTikTokBridgeTarget();
      const targetVersionAtStart = bridgeRuntime.targetVersion;
      const repostPaidThisLive = new Set();
      const followPaidThisLive = new Set();
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
      if (signApiKey) {
        connectionOpts.signApiKey = signApiKey;
        // Do NOT use connectWithUniqueId — Euler /webcast/fetch returns 404 and breaks WS.
      }
      if (hasChatSendCreds) {
        connectionOpts.sessionId = sessionId;
        connectionOpts.ttTargetIdc = ttTargetIdc;
      }

      const connection = new TikTokLiveConnection(activeUniqueId, connectionOpts);
      bridgeRuntime.activeConnection = connection;
      const rewardCtx = { sourceUniqueId: activeUniqueId };

      function payFollowBonus(userId, displayName, superFan, superFanLevel) {
        if (!userId || followPaidThisLive.has(userId)) return;
        followPaidThisLive.add(userId);
        postReward(port, {
          type: "follow",
          userId,
          displayName,
          superFan,
          superFanLevel,
          ...rewardCtx,
        }).catch((err) => {
          console.error("[TikTok] Follow reward:", err.message);
        });
      }

      const markSuperFan = (data) => {
        const { userId, displayName } = extractEventUser(data);
        const superFanLevel = extractSuperFanLevel(data);
        if (!userId) return;
        postUserMeta(port, { userId, displayName, superFan: true, superFanLevel }).catch((err) => {
          console.error("[TikTok] Superfan meta forward:", err.message);
        });
      };

      connection.on(evChat, (data) => {
        const { userId: uid, displayName: dn } = extractEventUser(data);
        const userId = uid || "viewer";
        const displayName = dn || userId;
        const message = String(data.comment || "").trim();
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!message) return;
        if (/^!link\s+[A-Fa-f0-9]{6}\s*$/i.test(message)) {
          console.log(`[TikTok] Link attempt from @${userId}: ${message}`);
        }
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
        const { userId, displayName } = extractEventUser(data);
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!userId) return;
        if (looksLikeRepost(data)) {
          if (repostPaidThisLive.has(userId)) return;
          repostPaidThisLive.add(userId);
          postReward(port, { type: "repost", userId, displayName, superFan, superFanLevel, ...rewardCtx }).catch((err) => {
            console.error("[TikTok] Repost reward:", err.message);
          });
          return;
        }
        postReward(port, { type: "share", userId, displayName, superFan, superFanLevel, ...rewardCtx }).catch((err) => {
          console.error("[TikTok] Share reward:", err.message);
        });
      });

      connection.on(evGift, (data) => {
        const { userId, displayName } = extractEventUser(data);
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
          ...rewardCtx,
        }).catch((err) => {
          console.error("[TikTok] Gift reward:", err.message);
        });
      });

      connection.on(evLike, (data) => {
        const { userId, displayName } = extractEventUser(data);
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!userId) return;
        const count = likeDeltaCount(data);
        if (BRIDGE_DEBUG) console.log(`[TikTok] like @${userId} x${count}`);
        postReward(port, {
          type: "like",
          userId,
          displayName,
          superFan,
          superFanLevel,
          count,
          ...rewardCtx,
        }).catch((err) => {
          console.error("[TikTok] Like reward:", err.message);
        });
      });

      connection.on(evFollow, (data) => {
        const { userId, displayName } = extractEventUser(data);
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!userId) return;
        if (BRIDGE_DEBUG) console.log(`[TikTok] follow @${userId}`);
        payFollowBonus(userId, displayName, superFan, superFanLevel);
      });

      connection.on(evSocial, (data) => {
        const { userId, displayName } = extractEventUser(data);
        const superFan = detectSuperFan(data);
        const superFanLevel = superFan ? extractSuperFanLevel(data) : 0;
        if (!userId) return;
        if (looksLikeRepost(data)) {
          if (repostPaidThisLive.has(userId)) return;
          repostPaidThisLive.add(userId);
          if (BRIDGE_DEBUG) console.log(`[TikTok] repost @${userId}`);
          postReward(port, { type: "repost", userId, displayName, superFan, superFanLevel, ...rewardCtx }).catch((err) => {
            console.error("[TikTok] Repost (social) reward:", err.message);
          });
          return;
        }
        if (looksLikeFollow(data)) {
          if (BRIDGE_DEBUG) console.log(`[TikTok] follow (social) @${userId}`);
          payFollowBonus(userId, displayName, superFan, superFanLevel);
        }
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
        console.log(`[TikTok] Waiting until @${activeUniqueId} is LIVE...`);
        setBridgeStatus({ uniqueId: activeUniqueId, state: "waiting", roomId: null });
        const waitOutcome = await Promise.race([
          connection.waitUntilLive().then(() => "live"),
          (async () => {
            while (true) {
              await sleep(250);
              if (
                bridgeRuntime.targetVersion !== targetVersionAtStart ||
                getTikTokBridgeTarget() !== activeUniqueId
              ) {
                return "switched";
              }
            }
          })(),
        ]);
        if (waitOutcome === "switched") {
          retryDelayMs = 100;
          setBridgeStatus({ uniqueId: getTikTokBridgeTarget(), state: "waiting", roomId: null });
          try {
            connection.disconnect();
          } catch {
            /* ignore */
          }
          continue;
        }
        setBridgeStatus({ uniqueId: activeUniqueId, state: "live" });
        console.log("[TikTok] Live — connecting...");
        const state = await connection.connect();
        const roomId = state?.roomId ? String(state.roomId) : null;
        setBridgeStatus({ uniqueId: activeUniqueId, state: "live", roomId });
        console.log("[TikTok] Connected.", state && state.roomId ? `roomId=${state.roomId}` : "");

        await new Promise((resolve) => {
          const done = () => resolve();
          connection.once(evEnd, done);
          connection.once("disconnected", done);
          connection.once("error", done);
        });
      } catch (err) {
        setBridgeStatus({ uniqueId: activeUniqueId, state: "offline", roomId: null });
        const msg = err && err.message ? String(err.message) : String(err);
        console.error("[TikTok]", msg);
        if (msg.includes("Sign Error") || msg.includes("webcast/fetch")) {
          console.error(
            "[TikTok] Euler sign failed — keep signApiKey in tiktok.config.json and do NOT use connectWithUniqueId."
          );
        }
      } finally {
        if (bridgeRuntime.activeConnection === connection) {
          bridgeRuntime.activeConnection = null;
        }
        setBridgeStatus({ uniqueId: getTikTokBridgeTarget(), state: "waiting", roomId: null });
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

      const retrySeconds = Math.max(0, Math.round(retryDelayMs / 1000));
      console.log(`[TikTok] Stream ended or lost connection; retrying in ${retrySeconds}s...`);
      await sleep(retryDelayMs);
    }
  })().catch((e) => console.error("[TikTok] Fatal:", e));
}

module.exports = {
  startTikTokBridge,
  loadTikTokConfig,
  getTikTokBridgeStatus,
  getTikTokBridgeTarget,
  setTikTokBridgeTarget,
  BRIDGE_TARGET_OPTIONS,
};
