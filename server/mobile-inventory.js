/**
 * Offline inventory sync — applies powerup spends queued on iOS while the server was down.
 * Steal spends with a target attempt a live steal (charge consumed only on success).
 * Bare charge spends (no target) burn charges idempotently so app + server stay aligned.
 */
const { buildWalletPayload } = require("./mobile-wallet");

const ALLOWED_KINDS = new Set(["steal", "shield_break", "jet_lock", "shield"]);

function ensureSyncedSpendSet(pointStore, user) {
  pointStore.ensureAccount(user);
  const profile = pointStore._ensureProfileShape
    ? pointStore._ensureProfileShape(user)
    : pointStore.points.profiles[user];
  if (!profile.syncedInventorySpendIds || typeof profile.syncedInventorySpendIds !== "object") {
    profile.syncedInventorySpendIds = {};
  }
  // Cap growth — keep newest ~200 ids
  const ids = Object.keys(profile.syncedInventorySpendIds);
  if (ids.length > 220) {
    ids
      .sort((a, b) => Number(profile.syncedInventorySpendIds[a] || 0) - Number(profile.syncedInventorySpendIds[b] || 0))
      .slice(0, ids.length - 200)
      .forEach((id) => {
        delete profile.syncedInventorySpendIds[id];
      });
  }
  pointStore.points.profiles[user] = profile;
  return profile.syncedInventorySpendIds;
}

function markSpendSynced(pointStore, user, spendId) {
  const set = ensureSyncedSpendSet(pointStore, user);
  set[String(spendId)] = Date.now();
  if (typeof pointStore._savePoints === "function") pointStore._savePoints();
}

function registerMobileInventoryRoutes(app, ctx) {
  const { validateBearer, pointStore, game } = ctx;

  app.post("/api/mobile/inventory/sync", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    const user = String(session.userId || "").trim();
    if (!user) return res.status(401).json({ ok: false, error: "auth_required" });

    const body = req.body && typeof req.body === "object" ? req.body : {};
    const spends = Array.isArray(body.spends) ? body.spends : [];
    if (!spends.length) {
      return res.json({
        ok: true,
        applied: 0,
        remaining: [],
        wallet: buildWalletPayload(user, pointStore, game),
      });
    }

    const synced = ensureSyncedSpendSet(pointStore, user);
    const remaining = [];
    let applied = 0;
    const results = [];

    for (const raw of spends.slice(0, 40)) {
      if (!raw || typeof raw !== "object") continue;
      const id = String(raw.id || "").trim().slice(0, 80);
      const kind = String(raw.kind || "").trim().toLowerCase();
      const count = Math.max(1, Math.min(20, Math.floor(Number(raw.count) || 1)));
      const target = raw.target != null ? String(raw.target).trim().replace(/^@/, "") : "";

      if (!id || !ALLOWED_KINDS.has(kind)) {
        remaining.push(raw);
        continue;
      }

      if (synced[id]) {
        applied += 1;
        results.push({ id, ok: true, alreadySynced: true });
        continue;
      }

      // Steal with target — full steal attempt (consumes charge only on success).
      if (kind === "steal" && target && game && typeof game._trySteal === "function") {
        const out = game._trySteal(user, target);
        if (out && out.ok) {
          markSpendSynced(pointStore, user, id);
          applied += 1;
          results.push({
            id,
            ok: true,
            kind,
            stolen: out.stolen,
            stealsReady: out.stealsReady,
            balance: out.balance,
          });
          continue;
        }
        // Transient / target issues — keep queued for retry. Charge NOT burned.
        const reason = out && out.reason ? String(out.reason) : "steal_failed";
        if (reason === "steal_not_armed" || reason === "no_charges") {
          // App already spent locally but server has no charges — drop to avoid infinite retry.
          markSpendSynced(pointStore, user, id);
          applied += 1;
          results.push({ id, ok: false, kind, reason, dropped: true });
          continue;
        }
        remaining.push({ id, kind, count, target });
        results.push({ id, ok: false, kind, reason, retry: true });
        continue;
      }

      // Bare charge burn (no target) — align server inventory with offline app use.
      const type =
        kind === "steal"
          ? "steal"
          : kind === "shield_break" || kind === "shield"
            ? "shield_break"
            : kind === "jet_lock"
              ? "jet_lock"
              : null;
      if (!type || typeof pointStore.consumePowerupCharge !== "function") {
        remaining.push({ id, kind, count, target: target || undefined });
        continue;
      }

      const consumed = pointStore.consumePowerupCharge(user, type, count);
      if (consumed && consumed.ok) {
        markSpendSynced(pointStore, user, id);
        applied += 1;
        results.push({ id, ok: true, kind, count: consumed.count });
      } else if (consumed && consumed.reason === "no_charges") {
        markSpendSynced(pointStore, user, id);
        applied += 1;
        results.push({ id, ok: false, kind, reason: "no_charges", dropped: true });
      } else {
        remaining.push({ id, kind, count, target: target || undefined });
        results.push({ id, ok: false, kind, reason: consumed?.reason || "consume_failed", retry: true });
      }
    }

    return res.json({
      ok: true,
      applied,
      remaining,
      results,
      wallet: buildWalletPayload(user, pointStore, game),
    });
  });
}

module.exports = { registerMobileInventoryRoutes };
