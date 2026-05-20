/**
 * Parse chat bet amounts: 100, 30k, 3m, 1.5m, 2b (commas optional).
 * @returns {number} floored points, or NaN if invalid
 */
function parseBetAmount(raw) {
  if (raw == null || raw === "") return NaN;
  const s = String(raw)
    .trim()
    .replace(/,/g, "")
    .replace(/\s+/g, "")
    .toLowerCase();
  if (!s) return NaN;

  const m = s.match(/^(\d+(?:\.\d+)?)([kmb])?$/i);
  if (!m) return NaN;

  let n = parseFloat(m[1]);
  if (!Number.isFinite(n) || n < 0) return NaN;

  const suffix = (m[2] || "").toLowerCase();
  if (suffix === "k") n *= 1_000;
  else if (suffix === "m") n *= 1_000_000;
  else if (suffix === "b") n *= 1_000_000_000;

  if (!Number.isFinite(n)) return NaN;
  return Math.floor(n);
}

/** @returns {{ amount: number, cashout: number, allIn?: boolean } | null} */
function parseBetCommand(text) {
  // TikTok comments may include full-width punctuation or zero-width chars.
  // Normalize first so valid bet commands are not silently ignored.
  const src = String(text || "")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/\uFF01/g, "!")
    .replace(/[×✕✖]/g, "x")
    .trim();
  if (!src.startsWith("!")) return null;

  const allIn = src.match(/^!all(?:\s+in)?\s+(?:at\s+)?([\d.]+)\s*x?\s*$/i);
  if (allIn) {
    const cashout = Number(allIn[1]);
    if (!Number.isFinite(cashout)) return null;
    return { amount: 0, cashout, allIn: true };
  }

  // Supported amount commands:
  // - !b 30k 2.5 (legacy)
  // - !b 30k at 2.5x
  // - !bet 30k at 2.5x
  // - !30k 2.5
  // - !30k at 2.5x
  // - !100 2
  let m = src.match(/^!b(?:et)?\s+(\S+)\s+(?:at\s+)?([\d.]+)\s*x?\s*$/i);
  if (!m) m = src.match(/^!(\S+)\s+(?:at\s+)?([\d.]+)\s*x?\s*$/i);
  if (!m) return null;

  const amount = parseBetAmount(m[1]);
  const cashout = Number(m[2]);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  if (!Number.isFinite(cashout)) return null;
  return { amount, cashout };
}

module.exports = { parseBetAmount, parseBetCommand };
