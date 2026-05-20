/**
 * Super Fan / name badges from the same pointStore data as TikTok live + wallet.
 */
function playerBadgesFromStore(pointStore, userId) {
  if (!pointStore || !userId) {
    return {
      superFan: false,
      superFanLevel: 0,
      nameStyle: "none",
      nameBadge: "none",
    };
  }
  try {
    pointStore.ensureAccount(userId);
    const view = pointStore.getUserPresentation(userId);
    return {
      superFan: !!view.superFan,
      superFanLevel: Math.max(0, Math.floor(Number(view.superFanLevel) || 0)),
      nameStyle: view.nameStyle || "none",
      nameBadge: view.nameBadge || "none",
    };
  } catch {
    return {
      superFan: false,
      superFanLevel: 0,
      nameStyle: "none",
      nameBadge: "none",
    };
  }
}

module.exports = { playerBadgesFromStore };
