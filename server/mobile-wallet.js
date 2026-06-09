/**
 * Full wallet payload for mobile (balance + inventory from same data as !balance).
 */
function resolvePowerupInventory(user, pointStore, game) {
  if (game && typeof game.getEffectivePowerupInventory === "function") {
    return game.getEffectivePowerupInventory(user);
  }
  if (typeof pointStore.getPowerupInventory === "function") {
    return pointStore.getPowerupInventory(user);
  }
  return { stealCharges: 0, shieldBreakCharges: 0, jetLockCharges: 0 };
}

function buildWalletPayload(user, pointStore, game) {
  pointStore.ensureAccount(user);
  const view = pointStore.getUserPresentation(user);
  const economy = pointStore.getEconomyProfile(user);
  const shield = pointStore.getShieldStatus(user);
  const inventory = resolvePowerupInventory(user, pointStore, game);
  const reset = pointStore.getMissionResetInfo();
  const jetLock = typeof game.getJetLockStatus === "function" ? game.getJetLockStatus(user) : null;

  return {
    ok: true,
    user: view.user,
    displayName: view.displayName,
    nameStyle: view.nameStyle,
    nameBadge: view.nameBadge || "none",
    ownedBadges: Array.isArray(view.ownedBadges) ? view.ownedBadges : [],
    superFan: !!view.superFan,
    superFanLevel: Math.max(0, Math.floor(Number(view.superFanLevel) || 0)),
    level: view.level,
    rank: view.rank,
    balance: pointStore.getBalance(user),
    allTime: pointStore.getAllTime(user),
    xp: economy ? economy.xp : 0,
    dailyStreak: economy ? economy.dailyStreak : 0,
    missions: economy ? economy.missions : [],
    missionResetAtMs: reset.resetAtMs,
    missionResetSeconds: reset.secondsUntilReset,
    missionResetTimezone: reset.timezone,
    shieldActive: shield.active,
    shieldMsLeft: shield.msLeft || 0,
    shieldUntil: shield.shieldUntil || 0,
    jetLockActive: !!(jetLock && jetLock.active),
    jetLockMsLeft: jetLock ? Number(jetLock.msLeft || 0) : 0,
    jetLockSecondsLeft: jetLock ? Number(jetLock.secondsLeft || 0) : 0,
    jetLockUntil: jetLock ? Number(jetLock.blockedUntil || 0) : 0,
    inventory,
  };
}

module.exports = { buildWalletPayload, resolvePowerupInventory };
