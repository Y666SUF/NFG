/**
 * Resolve TikTok gift events to viewer coin value for points (not raw diamonds).
 * Hand Hearts = 100 coins each; diamonds are converted with COIN_PER_DIAMOND (default 2).
 */

const COIN_PER_DIAMOND = Math.max(1, Number(process.env.COIN_PER_DIAMOND) || 2);

/** Per-gift viewer coin cost when API diamondCount is wrong or ambiguous. */
const GIFT_NAME_COIN_OVERRIDES = [
  { match: /hand\s*heart/i, unitCoins: 100 },
  /** TikTok Heart / Hearts (not Hand Hearts) — 200 viewer coins each */
  { match: /^(?!.*\bhand\b).*hearts?$/i, unitCoins: 200 },
  { match: /\bheart\b/i, unitCoins: 200 },
  { match: /\brose\b/i, unitCoins: 1 },
];

function normalizeGiftName(name) {
  return String(name || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function lookupGiftCoinOverride(giftName) {
  const n = normalizeGiftName(giftName);
  if (!n) return 0;
  for (const row of GIFT_NAME_COIN_OVERRIDES) {
    if (row.match.test(n)) return Math.max(0, Math.floor(Number(row.unitCoins) || 0));
  }
  return 0;
}

/** Points for a gift batch (coins × multiplier × optional superfan 2×). */
function expectedGiftPoints(coinTotal, options = {}) {
  const coins = Math.max(0, Math.floor(Number(coinTotal) || 0));
  const mult = Math.max(1, Math.floor(Number(options.giftCoinMultiplier) || 100));
  const superfan = options.superFan === true ? 2 : 1;
  return coins * mult * superfan;
}

function diamondsToCoins(diamonds) {
  const d = Math.floor(Number(diamonds) || 0);
  if (d <= 0) return 0;
  return d * COIN_PER_DIAMOND;
}

function collectDiamondCandidates(data, repeat) {
  const gd = data.giftDetails || {};
  const ext = data.extendedGiftInfo || {};
  const shim = data.gift || {};
  const rawCandidates = [
    ext.diamondCount,
    ext.diamond_count,
    gd.diamondCount,
    gd.diamond_count,
    shim.diamondCount,
    shim.diamond_count,
    data.diamondCount,
    data.diamond_count,
  ];
  const out = [];
  for (const c of rawCandidates) {
    let n = c;
    if (typeof n === "string") n = parseInt(n, 10);
    n = Math.floor(Number(n) || 0);
    if (n <= 0) continue;
    out.push(n);
    if (repeat > 1 && n >= repeat && n % repeat === 0) {
      const unit = Math.floor(n / repeat);
      if (unit > 0) out.push(unit);
    }
  }
  return out;
}

/** fanTicketCount is a room/session total — never use for per-gift coin value. */
function collectFanTicketCoinCandidates() {
  return [];
}

/**
 * Pick per-gift coin value from multiple payload fields.
 * Prefer per-unit over combo totals; avoid Math.min() under-counting (e.g. 5 vs 100).
 */
function pickUnitCoin(coinCandidates, repeat) {
  const unique = [...new Set(coinCandidates.filter((n) => n > 0))].sort((a, b) => a - b);
  if (!unique.length) return 0;
  if (unique.length === 1) return unique[0];

  const smallest = unique[0];
  const largest = unique[unique.length - 1];

  if (repeat > 1) {
    if (largest === smallest * repeat) return smallest;
    if (largest === repeat && smallest < repeat) return smallest;
  }

  return smallest;
}

/**
 * @param {object} data TikTok gift event payload
 * @param {number} repeat combo repeat count
 * @param {string} giftName resolved gift display name
 */
function giftUnitCoinValue(data, repeat, giftName) {
  const override = lookupGiftCoinOverride(giftName);
  if (override > 0) return override;

  const coinCandidates = [];
  for (const d of collectDiamondCandidates(data, repeat)) {
    const coins = diamondsToCoins(d);
    if (coins > 0) coinCandidates.push(coins);
  }
  for (const t of collectFanTicketCoinCandidates()) {
    if (t > 0) coinCandidates.push(t);
  }

  return pickUnitCoin(coinCandidates, repeat);
}

/**
 * Server-side floor: if bridge under-reports coins but giftCount is known, fix payout.
 */
function reconcileGiftCoins(reportedCoins, giftCount, giftName) {
  let count = Math.max(1, Math.floor(Number(giftCount) || 0));
  let coins = Math.max(0, Math.floor(Number(reportedCoins) || 0));
  const unit = lookupGiftCoinOverride(giftName);
  const MAX = 99;

  if (unit > 0) {
    if (coins > 0) {
      const fromCoins = Math.floor(coins / unit);
      if (fromCoins > 0) count = Math.min(count, fromCoins);
    }
    if (count > MAX) count = MAX;
    const expected = unit * count;
    if (coins < expected) {
      return { coins: expected, adjusted: true, expected, reported: coins, giftCount: count };
    }
    if (coins > expected) {
      return { coins: expected, adjusted: true, expected, reported: coins, giftCount: count };
    }
  } else if (count > MAX) {
    count = MAX;
  }

  return { coins: unit > 0 ? unit * count : coins, adjusted: false, giftCount: count };
}

module.exports = {
  COIN_PER_DIAMOND,
  GIFT_NAME_COIN_OVERRIDES,
  lookupGiftCoinOverride,
  giftUnitCoinValue,
  diamondsToCoins,
  pickUnitCoin,
  reconcileGiftCoins,
  expectedGiftPoints,
};
