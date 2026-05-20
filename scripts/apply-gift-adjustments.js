/**
 * Apply pending gift point corrections via live server (preferred) or points file.
 * Usage: node scripts/apply-gift-adjustments.js
 */
const http = require("http");
const { PointStore } = require("../server/store");

const PORT = Number(process.env.PORT) || 3847;

/** Manual top-ups only — normal gifts auto-correct via gift-payout.js + gift-combo.js */
const ADJUSTMENTS = [];

function postJson(path, body) {
  const payload = JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: "127.0.0.1",
        port: PORT,
        path,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          const text = Buffer.concat(chunks).toString("utf8");
          let json = null;
          try {
            json = text ? JSON.parse(text) : null;
          } catch {
            json = { raw: text };
          }
          resolve({ status: res.statusCode, json });
        });
      }
    );
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

async function applyViaServer() {
  for (const row of ADJUSTMENTS) {
    const { status, json } = await postJson("/api/admin/points", {
      user: row.user,
      add: row.add,
      notify: row.notify,
    });
    if (status !== 200 || !json?.ok) {
      throw new Error(`${row.user}: HTTP ${status} ${JSON.stringify(json)}`);
    }
    console.log(
      `[ok] ${row.user}: ${json.before?.toLocaleString?.() ?? json.before} -> ${json.balance?.toLocaleString?.() ?? json.balance}`
    );
  }
}

function applyViaFile() {
  const store = new PointStore(5000);
  for (const row of ADJUSTMENTS) {
    store.ensureAccount(row.user);
    const before = store.getBalance(row.user);
    store.add(row.user, row.add, { countAsEarned: true });
    if (typeof store.sendInGameNotification === "function") {
      store.sendInGameNotification(row.user, "gift_adjustment", row.notify);
    }
    console.log(`[ok] ${row.user}: ${before.toLocaleString()} -> ${store.getBalance(row.user).toLocaleString()}`);
  }
  store._savePoints();
  console.log("\nServer was offline — saved to points file. Restart NFG Crash to load.");
}

async function main() {
  try {
    await applyViaServer();
    console.log("\nApplied via live server — overlay should update immediately.");
  } catch (err) {
    console.warn(`Live server not reachable (${err.message}) — writing to disk instead.`);
    applyViaFile();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
