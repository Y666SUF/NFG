/**
 * Prevent duplicate gift payouts within a short window (TikTok double-events).
 */
const DEDUPE_MS = Number(process.env.GIFT_DEDUPE_MS) || 4000;
const recent = new Map();

function payoutFingerprint(user, giftName, giftCount, coins) {
  const u = String(user || "").toLowerCase();
  const name = String(giftName || "")
    .trim()
    .toLowerCase();
  const count = Math.floor(Number(giftCount) || 0);
  const c = Math.floor(Number(coins) || 0);
  return `${u}|${name}|${count}|${c}`;
}

function isDuplicateGiftPayout(user, giftName, giftCount, coins) {
  const key = payoutFingerprint(user, giftName, giftCount, coins);
  const now = Date.now();
  const prev = recent.get(key);
  if (prev && now - prev < DEDUPE_MS) return true;
  recent.set(key, now);
  pruneRecent(now);
  return false;
}

function isDuplicateStreakSettlement(user, giftId, groupId, giftCount) {
  const u = String(user || "").toLowerCase();
  const id = String(giftId || "unknown");
  const g = String(groupId || "0");
  const n = Math.floor(Number(giftCount) || 0);
  const key = `streak|${u}|${id}|${g}|${n}`;
  const now = Date.now();
  const prev = recent.get(key);
  if (prev && now - prev < DEDUPE_MS * 3) return true;
  recent.set(key, now);
  pruneRecent(now);
  return false;
}

function pruneRecent(now) {
  if (recent.size <= 5000) return;
  for (const [k, t] of recent) {
    if (now - t > DEDUPE_MS * 6) recent.delete(k);
  }
}

module.exports = {
  isDuplicateGiftPayout,
  isDuplicateStreakSettlement,
  payoutFingerprint,
  DEDUPE_MS,
};
