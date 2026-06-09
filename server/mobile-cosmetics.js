/**
 * Display shop — Name FX (!namefx) and status icons (!buy) for mobile app.
 */
const { NAME_STYLE_SHOP, listNameBadgeShop } = require("./game");
const { buildWalletPayload } = require("./mobile-wallet");

function listNameStyles() {
  return Object.values(NAME_STYLE_SHOP).map((s) => ({
    id: s.id,
    icon: s.icon || "",
    cost: Number(s.cost) || 0,
  }));
}

function listNameBadges() {
  return listNameBadgeShop().map((b) => ({
    id: b.id,
    label: b.label,
    short: b.short,
    tier: b.tier,
    cost: b.cost,
  }));
}

function registerMobileCosmeticsRoutes(app, ctx) {
  const { game, pointStore, validateBearer, broadcast } = ctx;

  app.get("/api/mobile/shop/catalog", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    const user = session.userId;
    pointStore.ensureAccount(user);
    const wallet = buildWalletPayload(user, pointStore, game);
    res.json({
      ok: true,
      nameStyles: listNameStyles(),
      nameBadges: listNameBadges(),
      balance: wallet.balance,
      nameStyle: wallet.nameStyle,
      nameBadge: wallet.nameBadge,
      ownedBadges: wallet.ownedBadges,
    });
  });

  app.post("/api/mobile/shop/namefx", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    const styleId = String(req.body?.styleId || "").trim().toLowerCase();
    if (!styleId) {
      return res.status(400).json({ ok: false, error: "style_id_required" });
    }
    const result = game._buyNameStyle(session.userId, styleId);
    const wallet = buildWalletPayload(session.userId, pointStore, game);
    if (!result.ok) {
      return res.status(400).json({
        ok: false,
        error: result.reason || "purchase_failed",
        ...result,
        ...wallet,
      });
    }
    if (typeof broadcast === "function") {
      broadcast({ type: "state", payload: game.getState() });
    }
    res.json({
      ok: true,
      ...result,
      ...wallet,
    });
  });

  app.post("/api/mobile/shop/badge", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    const badgeId = String(req.body?.badgeId || "").trim().toLowerCase();
    if (!badgeId) {
      return res.status(400).json({ ok: false, error: "badge_id_required" });
    }
    const result = game._buyNameBadge(session.userId, badgeId);
    const wallet = buildWalletPayload(session.userId, pointStore, game);
    if (!result.ok) {
      return res.status(400).json({
        ok: false,
        error: result.reason || "purchase_failed",
        ...result,
        ...wallet,
      });
    }
    if (typeof broadcast === "function") {
      broadcast({ type: "state", payload: game.getState() });
    }
    res.json({
      ok: true,
      ...result,
      ...wallet,
    });
  });
}

module.exports = { registerMobileCosmeticsRoutes, listNameStyles, listNameBadges };
