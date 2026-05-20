/** In-memory rolling window of successful cash-out wins for the public website. */

const MS_24H = 24 * 60 * 60 * 1000;
const cashoutWins = [];

function pruneCashoutWins(now = Date.now()) {
  const cutoff = now - MS_24H;
  while (cashoutWins.length && cashoutWins[0].at < cutoff) {
    cashoutWins.shift();
  }
}

function recordCashoutWin(row = {}) {
  const payout = Math.floor(Number(row.payout) || 0);
  const cashout = Math.round(Number(row.cashout) * 100) / 100;
  if (payout <= 0 || !Number.isFinite(cashout) || cashout < 1) return;
  const at = Number(row.at) || Date.now();
  const user = String(row.user || "").trim();
  const displayName = String(row.displayName || row.user || "").trim() || user;
  cashoutWins.push({ at, cashout, payout, user, displayName });
  pruneCashoutWins(at);
}

/** Best win in the last 24h = highest points payout (tie-break: higher multiplier). */
function pickBestWin24h() {
  pruneCashoutWins();
  let best = null;
  for (const row of cashoutWins) {
    if (
      !best ||
      row.payout > best.payout ||
      (row.payout === best.payout && row.cashout > best.cashout)
    ) {
      best = row;
    }
  }
  if (!best) return null;
  return {
    payout: best.payout,
    multiplier: Math.round(best.cashout * 100) / 100,
    username: best.user || null,
    displayName: best.displayName || best.user || null,
    at: best.at,
  };
}

function highestWin24h() {
  const best = pickBestWin24h();
  return best ? best.payout : null;
}

function buildFeaturedPayload(game, tiktok = {}) {
  const state = typeof game.getState === "function" ? game.getState() : {};
  const liveState = String(tiktok.state || "disabled");
  const isLive = liveState === "live";
  const viewerCount =
    Number.isFinite(Number(tiktok.viewerCount)) && Number(tiktok.viewerCount) >= 0
      ? Math.floor(Number(tiktok.viewerCount))
      : null;
  const dayBestWin = pickBestWin24h();

  return {
    ok: true,
    isLive,
    liveStatus: liveState,
    viewerCount,
    appPlayerCount: null,
    highestWin24h: dayBestWin ? dayBestWin.payout : null,
    dayBestWin,
    roundId: Number(state.roundId) || 0,
    phase: String(state.phase || "idle"),
    currentMultiplier:
      state.phase === "running" ? Math.round(Number(state.multiplier || 1) * 100) / 100 : null,
    updatedAt: Date.now(),
  };
}

module.exports = {
  recordCashoutWin,
  highestWin24h,
  pickBestWin24h,
  buildFeaturedPayload,
};
