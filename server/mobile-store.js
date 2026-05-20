/**
 * In-app store (test purchases until Apple StoreKit is wired).
 * Copy to Windows next to mobile-api.js.
 */
const PRODUCTS = {
  points_10k: { points: 10_000, priceLabel: "£1.99", title: "10,000 points" },
  points_50k: { points: 50_000, priceLabel: "£7.99", title: "50,000 points" },
  points_100k: { points: 100_000, priceLabel: "£12.99", title: "100,000 points" },
};

function registerMobileStoreRoutes(app, ctx) {
  const { pointStore, validateBearer, broadcast } = ctx;

  app.get("/api/mobile/store/products", (_req, res) => {
    const products = Object.entries(PRODUCTS).map(([id, p]) => ({
      id,
      points: p.points,
      priceLabel: p.priceLabel,
      title: p.title,
    }));
    res.json({
      ok: true,
      testMode: true,
      message: "Test store — no real payment. Use StoreKit + App Store for production.",
      products,
    });
  });

  app.post("/api/mobile/store/test-purchase", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }

    const productId = String(req.body?.productId || "").trim();
    const product = PRODUCTS[productId];
    if (!product) {
      return res.status(400).json({
        ok: false,
        error: "invalid_product",
        message: "Unknown product.",
      });
    }

    const user = session.userId;
    pointStore.ensureAccount(user);
    pointStore.credit(user, product.points, { countAsEarned: true });

    const balance = pointStore.getBalance(user);
    if (typeof broadcast === "function") {
      broadcast({
        type: "balance_toast",
        payload: {
          user,
          balance,
          gained: product.points,
          source: "test_purchase",
          productId,
        },
      });
    }

    res.json({
      ok: true,
      testMode: true,
      productId,
      gained: product.points,
      balance,
      priceLabel: product.priceLabel,
    });
  });
}

module.exports = { registerMobileStoreRoutes, PRODUCTS };
