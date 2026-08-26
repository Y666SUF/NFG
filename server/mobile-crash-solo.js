/**
 * Sync on-device (solo) crash round balance deltas to the live wallet.
 * iOS runs crash locally; this applies netDelta when online.
 *
 * App/offline wallet is authority: optional absolute balance fields override the
 * server after marking rounds synced, so a stale starter balance cannot wipe phone progress.
 */
const { buildWalletPayload } = require("./mobile-wallet");

const MAX_ABS_DELTA = 50_000_000;
const MAX_STAKE = 50_000_000;
const MAX_ABS_BALANCE = 500_000_000;

function ensureSyncedSet(pointStore, user) {
  pointStore.ensureAccount(user);
  const profile = pointStore._ensureProfileShape
    ? pointStore._ensureProfileShape(user)
    : pointStore.points.profiles[user];
  if (!profile.syncedCrashSoloIds || typeof profile.syncedCrashSoloIds !== "object") {
    profile.syncedCrashSoloIds = {};
  }
  const ids = Object.keys(profile.syncedCrashSoloIds);
  if (ids.length > 300) {
    ids
      .sort((a, b) => Number(profile.syncedCrashSoloIds[a] || 0) - Number(profile.syncedCrashSoloIds[b] || 0))
      .slice(0, ids.length - 250)
      .forEach((id) => {
        delete profile.syncedCrashSoloIds[id];
      });
  }
  pointStore.points.profiles[user] = profile;
  return profile.syncedCrashSoloIds;
}

function pickFiniteInt(value) {
  if (value == null || value === "") return null;
  const n = Math.floor(Number(value));
  return Number.isFinite(n) ? n : null;
}

/**
 * Absolute app wallet from body or last round row.
 * Keys: balance, clientBalance, appBalance, walletBalance, localBalance,
 * wallet.balance, per-round balanceAfter / clientBalance / appBalance.
 */
function pickAbsoluteBalance(body, rounds) {
  const bodyKeys = ["clientBalance", "appBalance", "walletBalance", "localBalance", "balance"];
  for (const k of bodyKeys) {
    const n = pickFiniteInt(body[k]);
    if (n != null && n >= 0 && n <= MAX_ABS_BALANCE) return n;
  }
  if (body.wallet && typeof body.wallet === "object") {
    const n = pickFiniteInt(body.wallet.balance);
    if (n != null && n >= 0 && n <= MAX_ABS_BALANCE) return n;
  }
  for (let i = rounds.length - 1; i >= 0; i -= 1) {
    const raw = rounds[i];
    if (!raw || typeof raw !== "object") continue;
    for (const k of ["balanceAfter", "clientBalance", "appBalance"]) {
      const n = pickFiniteInt(raw[k]);
      if (n != null && n >= 0 && n <= MAX_ABS_BALANCE) return n;
    }
  }
  return null;
}

function pickAbsoluteAllTime(body) {
  for (const k of ["clientAllTime", "allTime", "appAllTime"]) {
    const n = pickFiniteInt(body[k]);
    if (n != null && n >= 0 && n <= MAX_ABS_BALANCE) return n;
  }
  if (body.wallet && typeof body.wallet === "object") {
    const n = pickFiniteInt(body.wallet.allTime);
    if (n != null && n >= 0 && n <= MAX_ABS_BALANCE) return n;
  }
  return null;
}

function registerMobileCrashSoloRoutes(app, ctx) {
  const { validateBearer, pointStore, game } = ctx;

  app.post("/api/mobile/crash/solo/sync", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    const user = String(session.userId || "").trim();
    if (!user) return res.status(401).json({ ok: false, error: "auth_required" });

    const body = req.body && typeof req.body === "object" ? req.body : {};
    const rounds = Array.isArray(body.rounds) ? body.rounds : [];
    const absoluteBalance = pickAbsoluteBalance(body, rounds);
    const absoluteAllTime = pickAbsoluteAllTime(body);

    if (!rounds.length && absoluteBalance == null) {
      return res.json({
        ok: true,
        applied: 0,
        remaining: [],
        wallet: buildWalletPayload(user, pointStore, game),
      });
    }

    const synced = ensureSyncedSet(pointStore, user);
    const remaining = [];
    let applied = 0;
    let taxTotal = 0;

    for (const raw of rounds.slice(0, 60)) {
      if (!raw || typeof raw !== "object") continue;
      const id = String(raw.id || "").trim().slice(0, 80);
      const result = String(raw.result || "").trim().toLowerCase();
      const stake = Math.max(0, Math.floor(Number(raw.stake) || 0));
      let netDelta = Math.floor(Number(raw.netDelta) || 0);
      const tax = Math.max(0, Math.floor(Number(raw.tax) || 0));

      if (!id || (result !== "win" && result !== "lose")) {
        remaining.push(raw);
        continue;
      }
      if (synced[id]) {
        applied += 1;
        continue;
      }
      if (stake > MAX_STAKE || Math.abs(netDelta) > MAX_ABS_DELTA) {
        // Drop abusive / corrupt rows so the queue unblocks.
        synced[id] = Date.now();
        applied += 1;
        continue;
      }

      // Losses should be negative stake; wins are payout - stake.
      if (result === "lose" && netDelta > 0) netDelta = -stake;
      if (result === "lose" && netDelta === 0 && stake > 0) netDelta = -stake;

      // When absolute app balance is present it is the authority — only mark ids
      // synced here so we do not double-apply deltas on top of clientBalance.
      if (absoluteBalance == null) {
        pointStore.add(user, netDelta, { countAsEarned: netDelta > 0 });
      }
      if (tax > 0 && typeof pointStore.addTaxToPot === "function") {
        pointStore.addTaxToPot(tax);
        taxTotal += tax;
      }
      synced[id] = Date.now();
      applied += 1;
    }

    if (absoluteBalance != null && typeof pointStore.setBalance === "function") {
      pointStore.setBalance(user, absoluteBalance);
    }
    if (absoluteAllTime != null) {
      const cur =
        typeof pointStore.getAllTime === "function" ? pointStore.getAllTime(user) : 0;
      const next = Math.max(0, cur || 0, absoluteAllTime);
      if (typeof pointStore.setAllTime === "function") {
        pointStore.setAllTime(user, next);
      } else if (pointStore.points && pointStore.points.allTime) {
        const u = String(user || "").trim().toLowerCase();
        pointStore.points.allTime[u] = next;
      }
    }

    if (typeof pointStore._savePoints === "function") pointStore._savePoints();

    return res.json({
      ok: true,
      applied,
      remaining,
      taxTotal,
      appBalanceApplied: absoluteBalance != null,
      wallet: buildWalletPayload(user, pointStore, game),
    });
  });
}

module.exports = { registerMobileCrashSoloRoutes };
