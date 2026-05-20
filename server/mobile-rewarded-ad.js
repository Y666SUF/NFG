/**
 * Rewarded video claims from the iOS app (watch ad → points on server).
 */
const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");

const REWARD_AMOUNT = 10_000;
const COOLDOWN_MS = 0;

const CLAIMS_FILE = path.join(getAppRoot(), "data", "mobile-ad-claims.json");

function loadClaims() {
  try {
    const raw = fs.readFileSync(CLAIMS_FILE, "utf8");
    const data = JSON.parse(raw);
    return data && typeof data === "object" ? data : {};
  } catch {
    return {};
  }
}

function saveClaims(data) {
  fs.mkdirSync(path.dirname(CLAIMS_FILE), { recursive: true });
  fs.writeFileSync(CLAIMS_FILE, JSON.stringify(data, null, 2));
}

function dayKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function userRecord(all, userId) {
  if (!all[userId]) {
    all[userId] = { lastClaimAt: 0, byDay: {} };
  }
  return all[userId];
}

function claimsToday(rec) {
  return Math.floor(Number(rec.byDay[dayKey()]) || 0);
}

function getStatus(userId) {
  const all = loadClaims();
  const rec = userRecord(all, userId);
  const today = claimsToday(rec);
  const now = Date.now();
  const last = Math.max(0, Number(rec.lastClaimAt) || 0);
  const cooldownLeftMs = Math.max(0, COOLDOWN_MS - (now - last));
  const canClaim = cooldownLeftMs === 0;

  return {
    rewardAmount: REWARD_AMOUNT,
    claimsToday: today,
    maxClaimsPerDay: null,
    unlimited: true,
    cooldownSecondsLeft: Math.ceil(cooldownLeftMs / 1000),
    canClaim,
    reason: cooldownLeftMs > 0 ? "cooldown" : null,
    nextClaimAt: canClaim ? null : last + COOLDOWN_MS,
  };
}

function recordClaim(userId) {
  const all = loadClaims();
  const rec = userRecord(all, userId);
  const dk = dayKey();
  rec.lastClaimAt = Date.now();
  rec.byDay[dk] = claimsToday(rec) + 1;
  saveClaims(all);
}

function registerMobileRewardedAdRoutes(app, ctx) {
  const { pointStore, validateBearer, broadcast } = ctx;

  app.get("/api/mobile/rewarded-ad/status", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    res.json({ ok: true, ...getStatus(session.userId) });
  });

  app.post("/api/mobile/rewarded-ad/claim", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }

    const user = session.userId;
    const status = getStatus(user);
    if (!status.canClaim) {
      return res.status(429).json({
        ok: false,
        error: status.reason,
        message: `Wait ${status.cooldownSecondsLeft}s before the next ad reward.`,
        ...status,
      });
    }

    pointStore.ensureAccount(user);
    pointStore.credit(user, REWARD_AMOUNT, { countAsEarned: true });
    recordClaim(user);

    const balance = pointStore.getBalance(user);
    if (typeof broadcast === "function") {
      broadcast({
        type: "balance_toast",
        payload: {
          user,
          balance,
          gained: REWARD_AMOUNT,
          source: "rewarded_ad",
        },
      });
    }

    const after = getStatus(user);
    res.json({
      ok: true,
      gained: REWARD_AMOUNT,
      balance,
      claimsToday: after.claimsToday,
      maxClaimsPerDay: null,
      unlimited: true,
      cooldownSecondsLeft: after.cooldownSecondsLeft,
      canClaim: after.canClaim,
    });
  });
}

module.exports = { registerMobileRewardedAdRoutes, REWARD_AMOUNT };
