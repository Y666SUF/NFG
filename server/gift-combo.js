/**
 * TikTok gift combo / streak handling.
 * Pay streak gifts once on repeatEnd (TikTok canonical). Never use fanTicketCount as repeat.
 */

const { giftUnitCoinValue, COIN_PER_DIAMOND } = require("./gift-coins");

const STREAK_FLUSH_MS = Number(process.env.GIFT_STREAK_FLUSH_MS) || 3500;
const COMBO_STATE_TTL_MS = 120_000;
const MAX_REPEAT_PER_EVENT = 99;

function giftNameOf(data) {
  return (
    data.giftDetails?.giftName ||
    data.giftDetails?.gift_name ||
    data.extendedGiftInfo?.name ||
    data.gift?.name ||
    data.giftName ||
    data.gift_name ||
    ""
  );
}

function giftIdOf(data) {
  return String(
    data.giftDetails?.giftId ??
      data.giftDetails?.gift_id ??
      data.extendedGiftInfo?.id ??
      data.gift?.id ??
      data.giftId ??
      data.gift_id ??
      "unknown"
  );
}

function giftComboType(data) {
  return Number(
    data.giftType ??
      data.gift_type ??
      data.giftDetails?.giftType ??
      data.giftDetails?.gift_type ??
      0
  );
}

/** Only true streak counters — NOT fanTicketCount / room totals. */
function giftRepeatCount(data) {
  const rc = Math.floor(Number(data.repeatCount ?? data.repeat_count ?? 0) || 0);
  const cc = Math.floor(Number(data.comboCount ?? data.combo_count ?? 0) || 0);
  let n = rc > 0 ? rc : cc;
  if (n <= 0) n = 1;
  return Math.min(n, MAX_REPEAT_PER_EVENT);
}

function isStreakGift(data) {
  if (giftComboType(data) === 1) return true;
  if (data.giftDetails?.combo === true) return true;
  if (data.extendedGiftInfo?.combo === true) return true;
  if (data.gift?.combo === true) return true;
  return false;
}

function comboStateKey(user, data) {
  const groupId = String(data.groupId ?? data.group_id ?? "").trim() || "0";
  return `${user}|${giftIdOf(data)}|${groupId}`;
}

function giftEventNonce(data) {
  const c = data?.common || {};
  return String(
    data?.msgId ??
      data?.msg_id ??
      c?.msgId ??
      c?.msg_id ??
      data?.logId ??
      data?.log_id ??
      ""
  ).trim();
}

function payoutRow(giftName, giftId, unitCoins, giftCount) {
  const count = Math.max(1, Math.min(MAX_REPEAT_PER_EVENT, Math.floor(Number(giftCount) || 0)));
  return {
    coins: unitCoins * count,
    giftCount: count,
    giftName,
    giftId,
  };
}

/**
 * Streak: track max repeat during combo; pay exactly once on repeatEnd (or flush).
 */
function streakGiftDelta(data, comboState, user, unitCoins, giftName, giftId, repeat, repeatEnd, now) {
  const key = comboStateKey(user, data);
  const prev = comboState.get(key);
  let prevMax = Number(prev?.maxRepeat || 0);

  if (now - Number(prev?.at || 0) > COMBO_STATE_TTL_MS || (repeat < prevMax && !repeatEnd)) {
    prevMax = 0;
  }

  const maxRepeat = Math.max(prevMax, repeat);

  if (!repeatEnd) {
    comboState.set(key, {
      maxRepeat,
      unitCoins,
      at: now,
      giftName,
      giftId,
      user,
    });
    return { coins: 0, giftCount: 0, giftName, giftId, skipped: true, pendingStreak: maxRepeat };
  }

  const totalRepeat = Math.min(MAX_REPEAT_PER_EVENT, Math.max(repeat, maxRepeat));
  comboState.delete(key);

  return {
    ...payoutRow(giftName, giftId, unitCoins, totalRepeat),
    streakFinal: true,
    totalStreak: totalRepeat,
  };
}

function giftDelta(data, comboState, user) {
  const giftName = giftNameOf(data);
  const giftId = giftIdOf(data);
  const repeat = giftRepeatCount(data);
  const unitCoins = giftUnitCoinValue(data, repeat, giftName);
  if (unitCoins <= 0) {
    return { coins: 0, giftCount: 0, giftName, giftId };
  }

  const now = Date.now();
  const repeatEnd = Boolean(data.repeatEnd ?? data.repeat_end);

  if (isStreakGift(data)) {
    return streakGiftDelta(data, comboState, user, unitCoins, giftName, giftId, repeat, repeatEnd, now);
  }

  const key = comboStateKey(user, data);
  const prev = comboState.get(key) || { nonce: "", at: 0 };
  const nonce = giftEventNonce(data);
  const prevNonce = String(prev.nonce || "");
  if (nonce && prevNonce && nonce === prevNonce && now - Number(prev.at || 0) < 2000) {
    return { coins: 0, giftCount: 0, giftName, giftId, skipped: true };
  }
  comboState.set(key, { nonce, at: now });

  return payoutRow(giftName, giftId, unitCoins, repeat);
}

function flushStaleStreakCombos(comboState) {
  const now = Date.now();
  const payouts = [];
  for (const [key, row] of comboState.entries()) {
    if (!row || !row.unitCoins) continue;
    if (now - Number(row.at || 0) < STREAK_FLUSH_MS) continue;
    const giftCount = Math.min(MAX_REPEAT_PER_EVENT, Math.max(1, Math.floor(Number(row.maxRepeat) || 0)));
    if (giftCount <= 0) continue;
    comboState.delete(key);
    payouts.push({
      user: row.user,
      coins: row.unitCoins * giftCount,
      giftCount,
      giftName: row.giftName || "",
      giftId: row.giftId || "unknown",
      flushed: true,
    });
  }
  return payouts;
}

module.exports = {
  giftDelta,
  flushStaleStreakCombos,
  giftRepeatCount,
  giftNameOf,
  giftIdOf,
  isStreakGift,
  comboStateKey,
  STREAK_FLUSH_MS,
  MAX_REPEAT_PER_EVENT,
};
