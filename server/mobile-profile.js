const { buildWalletPayload } = require("./mobile-wallet");

function registerMobileProfileRoutes(app, ctx) {
  const { validateBearer, pointStore, game } = ctx;

  app.post("/api/mobile/profile/display-name", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    const displayName = String((req.body && req.body.displayName) || "").trim();
    if (!displayName) {
      return res.status(400).json({ ok: false, reason: "invalid_display_name", message: "Enter a display name." });
    }

    try {
      pointStore.setDisplayName(session.userId, displayName);
    } catch (e) {
      return res.status(400).json({
        ok: false,
        reason: "invalid_display_name",
        message: e?.message || "This display name is not allowed.",
      });
    }

    return res.json({ ok: true, wallet: buildWalletPayload(session.userId, pointStore, game) });
  });
}

module.exports = { registerMobileProfileRoutes };
