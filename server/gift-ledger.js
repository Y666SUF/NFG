/**
 * Append-only gift payout log for audit and debugging.
 */
const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");

const LEDGER_FILE = path.join(getAppRoot(), "data", "gift-ledger.jsonl");

function ensureLedgerDir() {
  const dir = path.dirname(LEDGER_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function appendGiftLedger(entry) {
  try {
    ensureLedgerDir();
    const row = {
      ts: Date.now(),
      ...entry,
    };
    fs.appendFileSync(LEDGER_FILE, `${JSON.stringify(row)}\n`, "utf8");
  } catch (err) {
    console.warn("[gift-ledger] write failed:", err.message);
  }
}

module.exports = { appendGiftLedger, LEDGER_FILE };
