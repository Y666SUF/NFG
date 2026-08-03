/**
 * Sync on-device (solo) crash round balance deltas to the live wallet.
 * iOS runs crash locally; this only applies netDelta when the server is online.
 */
const { buildWalletPayload } = require("./mobile-wallet");

const MAX_ABS_DELTA = 50_000_000;
const MAX_STAKE = 50_000_000;

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

function registerMobileCrashSoloRoutes(app, ctx) {
  const { validateBearer, pointStore, game } = ctx;

  app.post("/api/mobile/crash/solo/sync", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    const user = String(session.userId || "").trim();
    if (!user) return res.status(401).json({ ok: false, error: "auth_required" });

    const body = req.body && typeof req.body === "object" ? req.body : {};
    const rounds = Array.isArray(body.rounds) ? body.rounds : [];
    if (!rounds.length) {
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

      pointStore.add(user, netDelta, { countAsEarned: netDelta > 0 });
      if (tax > 0 && typeof pointStore.addTaxToPot === "function") {
        pointStore.addTaxToPot(tax);
        taxTotal += tax;
      }
      synced[id] = Date.now();
      applied += 1;
    }

    if (typeof pointStore._savePoints === "function") pointStore._savePoints();

    return res.json({
      ok: true,
      applied,
      remaining,
      taxTotal,
      wallet: buildWalletPayload(user, pointStore, game),
    });
  });
}

module.exports = { registerMobileCrashSoloRoutes };
