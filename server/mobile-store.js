/**
 * In-app store: Apple IAP verify + optional dev test purchases.
 */
const fs = require("fs");
const path = require("path");

const PRODUCTS = {
  points_10k: { points: 10_000, priceLabel: "£1.99", title: "10,000 points" },
  points_50k: { points: 50_000, priceLabel: "£7.99", title: "50,000 points" },
  points_100k: { points: 100_000, priceLabel: "£12.99", title: "100,000 points" },
};

const BUNDLE_ID = "com.nfg.crash";
const CONSUMED_PATH = path.join(__dirname, "..", "data", "consumed-iap-transactions.json");

function allowTestStore() {
  return String(process.env.NFG_ALLOW_TEST_STORE || "").trim() === "1";
}

function loadConsumedIds() {
  try {
    const raw = fs.readFileSync(CONSUMED_PATH, "utf8");
    const parsed = JSON.parse(raw);
    return new Set(Array.isArray(parsed) ? parsed.map(String) : []);
  } catch {
    return new Set();
  }
}

function saveConsumedIds(set) {
  try {
    const dir = path.dirname(CONSUMED_PATH);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(CONSUMED_PATH, JSON.stringify([...set].slice(-50_000), null, 0));
  } catch (err) {
    console.warn("[mobile-store] could not persist consumed transactions:", err.message);
  }
}

/** Decode StoreKit 2 JWS payload (middle segment) — not full signature verify. */
function decodeJwsPayload(jws) {
  const parts = String(jws || "").split(".");
  if (parts.length < 2) return null;
  let b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  while (b64.length % 4) b64 += "=";
  try {
    return JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
  } catch {
    return null;
  }
}

function registerMobileStoreRoutes(app, ctx) {
  const { pointStore, validateBearer, broadcast } = ctx;
  const consumed = loadConsumedIds();

  app.get("/api/mobile/store/products", (_req, res) => {
    const products = Object.entries(PRODUCTS).map(([id, p]) => ({
      id,
      points: p.points,
      priceLabel: p.priceLabel,
      title: p.title,
    }));
    res.json({
      ok: true,
      testMode: allowTestStore(),
      appleIAP: true,
      productIds: Object.keys(PRODUCTS),
      message: allowTestStore()
        ? "Dev test store enabled (NFG_ALLOW_TEST_STORE=1). Production uses Apple IAP."
        : "Purchases use Apple In-App Purchase. Create matching consumables in App Store Connect.",
      products,
    });
  });

  app.post("/api/mobile/store/verify-purchase", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }

    const productId = String(req.body?.productId || "").trim();
    const transactionId = String(req.body?.transactionId || "").trim();
    const jws = String(req.body?.signedTransactionInfo || req.body?.jws || "").trim();
    const product = PRODUCTS[productId];

    if (!product) {
      return res.status(400).json({
        ok: false,
        error: "invalid_product",
        message: "Unknown product.",
      });
    }
    if (!transactionId) {
      return res.status(400).json({
        ok: false,
        error: "missing_transaction",
        message: "Missing Apple transaction id.",
      });
    }

    if (consumed.has(transactionId)) {
      const user = session.userId;
      pointStore.ensureAccount(user);
      return res.json({
        ok: true,
        alreadyProcessed: true,
        productId,
        balance: pointStore.getBalance(user),
        message: "Purchase already credited.",
      });
    }

    if (jws) {
      const payload = decodeJwsPayload(jws);
      if (payload) {
        const jwsProduct = String(payload.productId || payload.product_id || "").trim();
        const jwsBundle = String(payload.bundleId || payload.bundle_id || "").trim();
        const jwsTxn = String(payload.transactionId || payload.transaction_id || "").trim();
        if (jwsProduct && jwsProduct !== productId) {
          return res.status(400).json({
            ok: false,
            error: "product_mismatch",
            message: "Transaction product does not match request.",
          });
        }
        if (jwsBundle && jwsBundle !== BUNDLE_ID) {
          return res.status(400).json({
            ok: false,
            error: "bundle_mismatch",
            message: "Transaction bundle id invalid.",
          });
        }
        if (jwsTxn && jwsTxn !== transactionId) {
          return res.status(400).json({
            ok: false,
            error: "transaction_mismatch",
            message: "Transaction id mismatch.",
          });
        }
      }
    }

    const user = session.userId;
    pointStore.ensureAccount(user);
    pointStore.credit(user, product.points, { countAsEarned: true });
    consumed.add(transactionId);
    saveConsumedIds(consumed);

    const balance = pointStore.getBalance(user);
    if (typeof broadcast === "function") {
      broadcast({
        type: "balance_toast",
        payload: {
          user,
          balance,
          gained: product.points,
          source: "apple_iap",
          productId,
          transactionId,
        },
      });
    }

    return res.json({
      ok: true,
      productId,
      gained: product.points,
      balance,
      transactionId,
    });
  });

  app.post("/api/mobile/store/test-purchase", (req, res) => {
    if (!allowTestStore()) {
      return res.status(403).json({
        ok: false,
        error: "test_store_disabled",
        message: "Test store is disabled. Use Apple In-App Purchase.",
      });
    }

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

module.exports = { registerMobileStoreRoutes, PRODUCTS, BUNDLE_ID };
