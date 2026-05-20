/**
 * Central gift payout resolution — coins, gift count, points, auto-correction.
 */
const {
  lookupGiftCoinOverride,
  reconcileGiftCoins,
  expectedGiftPoints,
} = require("./gift-coins");

const MAX_GIFT_UNITS = 99;

/**
 * Never trust absurd giftCount from TikTok fan-ticket / room fields.
 */
function inferGiftCount(reportedCoins, giftCount, giftName) {
  let count = Math.max(1, Math.floor(Number(giftCount) || 0));
  let coins = Math.max(0, Math.floor(Number(reportedCoins) || 0));
  const unit = lookupGiftCoinOverride(giftName);

  if (unit > 0) {
    if (coins > 0) {
      const fromCoins = Math.floor(coins / unit);
      if (fromCoins > 0) count = Math.min(count, fromCoins);
    }
    if (count > MAX_GIFT_UNITS) count = MAX_GIFT_UNITS;
    const expected = unit * count;
    if (coins > expected * 3) coins = expected;
  } else if (count > MAX_GIFT_UNITS) {
    count = MAX_GIFT_UNITS;
  }

  return { count: Math.max(1, count), coins };
}

function resolveGiftPayout({
  reportedCoins,
  giftCount,
  giftName,
  superFan,
  giftCoinMultiplier = 100,
}) {
  const inferred = inferGiftCount(reportedCoins, giftCount, giftName);
  const reconciled = reconcileGiftCoins(inferred.coins, inferred.count, giftName);
  const coins = reconciled.coins;
  const units = Math.min(MAX_GIFT_UNITS, reconciled.giftCount);
  const points = expectedGiftPoints(coins, {
    giftCoinMultiplier,
    superFan: superFan === true,
  });

  const rawCount = Math.max(1, Math.floor(Number(giftCount) || 1));
  return {
    coins,
    giftCount: units,
    points,
    adjusted:
      reconciled.adjusted ||
      units !== rawCount ||
      inferred.coins !== Math.max(0, Math.floor(Number(reportedCoins) || 0)),
    expectedCoins: lookupGiftCoinOverride(giftName) > 0 ? lookupGiftCoinOverride(giftName) * units : coins,
    reportedCoins: Math.max(0, Math.floor(Number(reportedCoins) || 0)),
  };
}

module.exports = {
  inferGiftCount,
  resolveGiftPayout,
  MAX_GIFT_UNITS,
};
