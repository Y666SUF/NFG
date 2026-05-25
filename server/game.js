const { nextCrashMultiplier } = require("./crash");
const { parseBetCommand } = require("./bet-amount");
const { resolveBadgeId } = require("./badge-ids");

const PHASE = {
  IDLE: "idle",
  BETTING: "betting",
  RUNNING: "running",
  ENDED: "ended",
};

const DEFAULTS = {
  bettingSeconds: 15,
  tickMs: 50,
  multiplierPerSecond: 0.42,
  /** Prevent immediate post-lock crashes; keeps early round dramatic. */
  minRunBeforeCrashMs: 1400,
  minBet: 1,
  // No hard max by default; users can bet any amount they hold.
  maxBet: null,
  minCashout: 1.05,
  maxCashout: 500,
  maxRunSeconds: 0,
  autoRestartMs: 10_000,
  balanceShoutCooldownMs: 30_000,
  iconsPopupCooldownMs: 120_000,
  iconsPopupDurationMs: 10_000,
  spinTicketCost: 2_000,
  spinAnimationMs: 7000,
  pinMessageCost: 3_000,
  pinMessageDurationMs: 180_000,
  bountyMinPoints: 500,
  shieldBreakLockMs: 5 * 60 * 1000,
  flyingJetLockMs: 60 * 60 * 1000,
};

const SPIN_SEGMENTS = [
  { id: "miss", label: "MISS", multiplier: 0, weight: 30 },
  { id: "half", label: "0.5x", multiplier: 0.5, weight: 24 },
  { id: "refund", label: "1x", multiplier: 1, weight: 20 },
  { id: "boost", label: "1.5x", multiplier: 1.5, weight: 14 },
  { id: "double", label: "2x", multiplier: 2, weight: 8 },
  { id: "mega", label: "3x", multiplier: 3, weight: 4 },
];

const NAME_STYLE_SHOP = {
  none: { id: "none", icon: "", cost: 0 },
  neon: { id: "neon", icon: "✨", cost: 2_000_000 },
  royal: { id: "royal", icon: "👑", cost: 3_000_000 },
  fire: { id: "fire", icon: "🔥", cost: 4_000_000 },
  ice: { id: "ice", icon: "❄️", cost: 4_000_000 },
  shadow: { id: "shadow", icon: "🌑", cost: 5_000_000 },
  rainbow: { id: "rainbow", icon: "🌈", cost: 7_000_000 },
  pulse: { id: "pulse", icon: "💫", cost: 6_000_000 },
  glitch: { id: "glitch", icon: "⚡", cost: 8_000_000 },
};

const NAME_BADGE_SHOP = {
  acespades: { id: "acespades", label: "Ace of Spades", short: "A♠", tier: 1, cost: 50_000_000 },
  chip: { id: "chip", label: "Vault Chip", short: "CH", tier: 2, cost: 100_000_000 },
  dice: { id: "dice", label: "High Roller", short: "DI", tier: 3, cost: 150_000_000 },
  bullion: { id: "bullion", label: "Gold Bullion", short: "AU", tier: 4, cost: 200_000_000 },
  lucky7: { id: "lucky7", label: "Lucky Seven", short: "7", tier: 5, cost: 250_000_000 },
  ltc: { id: "ltc", label: "Litecoin", short: "Ł", tier: 6, cost: 300_000_000 },
  bitcoin: { id: "bitcoin", label: "Bitcoin", short: "₿", tier: 7, cost: 350_000_000 },
  ethereum: { id: "ethereum", label: "Ether Gem", short: "Ξ", tier: 8, cost: 400_000_000 },
  whale: { id: "whale", label: "Whale Vault", short: "WV", tier: 9, cost: 450_000_000 },
  imperial: { id: "imperial", label: "NFG Imperial", short: "NFG", tier: 10, cost: 500_000_000 },
};

function listNameBadgeShop() {
  return Object.values(NAME_BADGE_SHOP).sort((a, b) => a.cost - b.cost);
}

const SUPERFAN_COMMAND_HOST = "y666.suf";
const ADMIN_POINTS_COMMAND_HOST = "y666.suf";
const BACKUP_COMMAND_HOST = "y666.suf";
const HOST_UNLIMITED_BET_USER = "y666.suf";
const HOST_UNLIMITED_STEAL_USER = "y666.suf";
const HOST_STEAL_PROTECTED_USER = "y666.suf";
const HOST_UNLIMITED_STEAL_VISIBLE = 999999;
const CROWN_SELL_REFUND = 12_500_000;

class CrashGame {
  constructor(pointStore, options = {}) {
    this.store = pointStore;
    this.opts = { ...DEFAULTS, ...options };
    this.onUpdate = typeof options.onUpdate === "function" ? options.onUpdate : () => {};
    this.onEvent = typeof options.onEvent === "function" ? options.onEvent : () => {};
    this.onCashoutWin = typeof options.onCashoutWin === "function" ? options.onCashoutWin : () => {};
    this.phase = PHASE.IDLE;
    this.roundId = 0;
    this.crashPoint = null;
    this.multiplier = 1;
    this.bets = new Map();
    this.queuedBets = new Map();
    this.bettingEndsAt = 0;
    this.nextRoundStartsAt = null;
    this.lastResult = null;
    this.recentCrashes = [];
    this.pendingSpins = [];
    this.spinPauseEndsAt = null;
    this.activeBounty = null;
    this.pinnedMessage = null;

    this._tickTimer = null;
    this._bettingTimer = null;
    this._betweenRoundTimer = null;
    this._spinQueueActive = false;
    this._runStartedAt = 0;
    this._winsThisRound = [];

    this._balanceShoutAt = new Map();
    this._iconsPopupLastAt = 0;
    this._armedSteals = new Map();
    this._armedShieldBreaks = new Map();
    this._armedJetLocks = new Map();
    this._shieldBreakLocks = new Map();
    this._jetLocks = new Map();
  }

  _normUser(user) {
    return String(user || "").trim().replace(/^@+/, "").slice(0, 40);
  }

  _userView(user) {
    if (this.store && typeof this.store.getUserPresentation === "function") {
      return this.store.getUserPresentation(user);
    }
    const u = this._normUser(user);
    return { user: u, displayName: u, nameStyle: "none", level: 1, rank: "Rookie", nameBadge: "none" };
  }

  _isHostUnlimitedBetUser(user) {
    return this._normUser(user).toLowerCase() === HOST_UNLIMITED_BET_USER;
  }

  _isHostUnlimitedStealUser(user) {
    return this._normUser(user).toLowerCase() === HOST_UNLIMITED_STEAL_USER;
  }

  _getShieldBreakLock(user) {
    const u = this._normUser(user);
    const until = Number(this._shieldBreakLocks.get(u) || 0);
    if (!until || until <= Date.now()) {
      this._shieldBreakLocks.delete(u);
      return null;
    }
    return { user: u, blockedUntil: until, secondsLeft: Math.max(1, Math.ceil((until - Date.now()) / 1000)) };
  }

  _setShieldBreakLock(user, ms) {
    const u = this._normUser(user);
    const until = Date.now() + Math.max(1, Math.floor(Number(ms) || 0));
    this._shieldBreakLocks.set(u, until);
    return { user: u, blockedUntil: until };
  }

  _clearShieldBreakLock(user) {
    const u = this._normUser(user);
    this._shieldBreakLocks.delete(u);
  }

  _getJetLock(user) {
    const u = this._normUser(user);
    const until = Number(this._jetLocks.get(u) || 0);
    if (!until || until <= Date.now()) {
      this._jetLocks.delete(u);
      return null;
    }
    return {
      user: u,
      blockedUntil: until,
      msLeft: Math.max(0, until - Date.now()),
      secondsLeft: Math.max(1, Math.ceil((until - Date.now()) / 1000)),
    };
  }

  _setJetLock(user, ms) {
    const u = this._normUser(user);
    const add = Math.max(1, Math.floor(Number(ms) || 0));
    const now = Date.now();
    const cur = Math.max(0, Number(this._jetLocks.get(u) || 0));
    const until = Math.max(now, cur) + add;
    this._jetLocks.set(u, until);
    return { user: u, blockedUntil: until, msLeft: until - now, secondsLeft: Math.max(1, Math.ceil((until - now) / 1000)) };
  }

  getJetLockStatus(user) {
    const lock = this._getJetLock(user);
    if (!lock) return { active: false, msLeft: 0, secondsLeft: 0, blockedUntil: 0 };
    return { active: true, msLeft: lock.msLeft, secondsLeft: lock.secondsLeft, blockedUntil: lock.blockedUntil };
  }

  listOpenBets() {
    const out = [];
    for (const [user, bet] of this.bets) {
      const v = this._userView(user);
      out.push({
        user,
        displayName: v.displayName,
        nameStyle: v.nameStyle,
        level: v.level,
        rank: v.rank,
        amount: Number(bet.amount || 0),
        cashout: bet.cashout,
      });
    }
    return out;
  }

  listQueuedBets() {
    const out = [];
    for (const [user, bet] of this.queuedBets) {
      const v = this._userView(user);
      out.push({
        user,
        displayName: v.displayName,
        nameStyle: v.nameStyle,
        level: v.level,
        rank: v.rank,
        amount: Number(bet.amount || 0),
        cashout: bet.cashout,
      });
    }
    return out;
  }

  _prunePinnedMessage() {
    if (!this.pinnedMessage) return;
    if (Number(this.pinnedMessage.expiresAt) <= Date.now()) this.pinnedMessage = null;
  }

  getState() {
    this._prunePinnedMessage();
    return {
      phase: this.phase,
      roundId: this.roundId,
      multiplier: Math.floor(this.multiplier * 100) / 100,
      crashPoint: this.phase === PHASE.ENDED ? this.crashPoint : null,
      bettingEndsAt: this.bettingEndsAt,
      nextRoundStartsAt: this.nextRoundStartsAt,
      opts: { ...this.opts },
      lastResult: this.lastResult,
      openBets: this.bets.size > 0 ? this.listOpenBets() : [],
      queuedBets: this.listQueuedBets(),
      activeBounty: this.activeBounty,
      pinnedMessage: this.pinnedMessage,
      pendingSpinCount: this.pendingSpins.length,
      spinPauseEndsAt: this.spinPauseEndsAt,
      taxPot: this.store.getTaxPotStatus ? this.store.getTaxPotStatus() : null,
      recentCrashes: [...this.recentCrashes],
    };
  }

  _clearTimers() {
    if (this._tickTimer) clearTimeout(this._tickTimer);
    if (this._bettingTimer) clearTimeout(this._bettingTimer);
    this._tickTimer = null;
    this._bettingTimer = null;
  }

  startRound() {
    if (this.phase === PHASE.BETTING || this.phase === PHASE.RUNNING) return;
    if (this._betweenRoundTimer) {
      clearTimeout(this._betweenRoundTimer);
      this._betweenRoundTimer = null;
    }
    this.nextRoundStartsAt = null;
    this._clearTimers();

    this.roundId += 1;
    this.crashPoint = nextCrashMultiplier();
    this.multiplier = 1;
    this.bets.clear();
    for (const [user, bet] of this.queuedBets) this.bets.set(user, { amount: bet.amount, cashout: bet.cashout });
    this.queuedBets.clear();
    this.phase = PHASE.BETTING;
    this.bettingEndsAt = Date.now() + this.opts.bettingSeconds * 1000;
    this.lastResult = null;
    this._bettingTimer = setTimeout(() => this._lockAndRun(), this.opts.bettingSeconds * 1000);
    this.onUpdate();
  }

  placeBet(user, amount, cashout) {
    if (this.phase !== PHASE.BETTING) return { ok: false, reason: "not_betting" };
    const u = this._normUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    const jet = this._getJetLock(u);
    if (jet) return { ok: false, reason: "jet_lock_active", user: u, secondsLeft: jet.secondsLeft, blockedUntil: jet.blockedUntil };
    const lock = this._getShieldBreakLock(u);
    if (lock) return { ok: false, reason: "shield_break_lock", user: u, secondsLeft: lock.secondsLeft, blockedUntil: lock.blockedUntil };

    const amt = Math.floor(Number(amount));
    const mult = Math.round(Number(cashout) * 100) / 100;
    const hostUnlimited = this._isHostUnlimitedBetUser(u);
    const maxBet = Number(this.opts.maxBet);
    const hasMaxBetCap = Number.isFinite(maxBet) && maxBet >= this.opts.minBet;
    if (amt < this.opts.minBet || (!hostUnlimited && hasMaxBetCap && amt > maxBet)) return { ok: false, reason: "bad_bet_amount" };
    if (mult < this.opts.minCashout || mult > this.opts.maxCashout) return { ok: false, reason: "bad_cashout" };
    if (this.bets.has(u)) return { ok: false, reason: "already_bet" };

    this.store.ensureAccount(u);
    this.store.claimDailyBonus(u);
    let debit = this.store.tryDebit(u, amt);
    if (!debit.ok && hostUnlimited && debit.reason === "insufficient") {
      const shortfall = Math.max(0, amt - this.store.getBalance(u));
      if (shortfall > 0) this.store.add(u, shortfall, { countAsEarned: false });
      debit = this.store.tryDebit(u, amt);
    }
    if (!debit.ok) return { ok: false, reason: debit.reason, balance: debit.balance };

    this.bets.set(u, { amount: amt, cashout: mult });
    this.store.addWagerVolume(u, amt);
    if (typeof this.store.trackHighStakeBet === "function") this.store.trackHighStakeBet(u, amt);
    this.store.awardXP(u, "BET_PLACED");
    this.store.recordMissionProgress(u, "PLAY_EVENT", 1);
    this.onUpdate();
    return { ok: true, balance: debit.balance };
  }

  queueBet(user, amount, cashout) {
    if (this.phase === PHASE.BETTING) return { ok: false, reason: "not_queue_phase" };
    const u = this._normUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    const jet = this._getJetLock(u);
    if (jet) return { ok: false, reason: "jet_lock_active", user: u, secondsLeft: jet.secondsLeft, blockedUntil: jet.blockedUntil };
    const lock = this._getShieldBreakLock(u);
    if (lock) return { ok: false, reason: "shield_break_lock", user: u, secondsLeft: lock.secondsLeft, blockedUntil: lock.blockedUntil };

    const amt = Math.floor(Number(amount));
    const mult = Math.round(Number(cashout) * 100) / 100;
    const hostUnlimited = this._isHostUnlimitedBetUser(u);
    const maxBet = Number(this.opts.maxBet);
    const hasMaxBetCap = Number.isFinite(maxBet) && maxBet >= this.opts.minBet;
    if (amt < this.opts.minBet || (!hostUnlimited && hasMaxBetCap && amt > maxBet)) return { ok: false, reason: "bad_bet_amount" };
    if (mult < this.opts.minCashout || mult > this.opts.maxCashout) return { ok: false, reason: "bad_cashout" };
    if (this.bets.has(u)) return { ok: false, reason: "still_in_round" };

    this.store.ensureAccount(u);
    if (this.queuedBets.has(u)) {
      const prev = this.queuedBets.get(u);
      this.store.credit(u, prev.amount);
    }
    let debit = this.store.tryDebit(u, amt);
    if (!debit.ok && hostUnlimited && debit.reason === "insufficient") {
      const shortfall = Math.max(0, amt - this.store.getBalance(u));
      if (shortfall > 0) this.store.add(u, shortfall, { countAsEarned: false });
      debit = this.store.tryDebit(u, amt);
    }
    if (!debit.ok) return { ok: false, reason: debit.reason, balance: debit.balance };
    this.queuedBets.set(u, { amount: amt, cashout: mult });
    this.onUpdate();
    return { ok: true, balance: debit.balance, queued: true };
  }

  _lockAndRun() {
    if (this.phase !== PHASE.BETTING) return;
    this.phase = PHASE.RUNNING;
    this.multiplier = 1;
    this._runStartedAt = Date.now();
    this._winsThisRound = [];
    this.onUpdate();
    this._tick();
  }

  _finishRound(resultCrash) {
    const lost = [];
    for (const [user, bet] of this.bets) {
      const v = this._userView(user);
      lost.push({
        user,
        displayName: v.displayName,
        nameStyle: v.nameStyle,
        level: v.level,
        rank: v.rank,
        result: "lose",
        bet: Number(bet.amount || 0),
        cashout: bet.cashout,
      });
    }
    this.bets.clear();
    this.phase = PHASE.ENDED;
    this.crashPoint = resultCrash;
    this.multiplier = resultCrash;
    const crashVal = Math.floor(resultCrash * 100) / 100;
    this.recentCrashes.push(crashVal);
    if (this.recentCrashes.length > 5) this.recentCrashes = this.recentCrashes.slice(-5);
    this.lastResult = { roundId: this.roundId, crashPoint: resultCrash, wins: [...this._winsThisRound], losses: lost };
    this._clearTimers();
    this.onUpdate();
    this._runPostRoundFlow();
  }

  _tick() {
    if (this.phase !== PHASE.RUNNING) return;
    if (this.bets.size === 0) return this._finishRound(this.crashPoint);

    const dt = this.opts.tickMs / 1000;
    const elapsedMs = this._runStartedAt > 0 ? Math.max(0, Date.now() - this._runStartedAt) : 0;
    const minRunBeforeCrashMs = Math.max(0, Math.floor(Number(this.opts.minRunBeforeCrashMs) || 0));
    const crashGraceActive = elapsedMs < minRunBeforeCrashMs;

    // Adaptive pacing:
    // - early section intentionally slower for suspense
    // - high-target rounds speed up progressively after ~5x
    const highestCashoutTarget = (() => {
      let top = 1;
      for (const [, bet] of this.bets) {
        const c = Math.max(1, Number(bet && bet.cashout) || 1);
        if (c > top) top = c;
      }
      return top;
    })();
    const earlyPaceFactor = (() => {
      if (this.multiplier <= 1) return 0.56;
      if (this.multiplier >= 5) return 1;
      const t = (this.multiplier - 1) / 4;
      return 0.56 + t * 0.44;
    })();
    const adaptiveSpeedBoost = Math.max(1, Math.min(8, Math.sqrt(highestCashoutTarget)));
    const postFiveRamp = Math.max(0, Math.min(1, (this.multiplier - 5) / 8));
    const adaptiveFactor = 1 + (adaptiveSpeedBoost - 1) * postFiveRamp;
    const perSecond = this.opts.multiplierPerSecond * earlyPaceFactor * adaptiveFactor;

    const next = this.multiplier + perSecond * dt;
    const rounded = Math.floor(next * 100) / 100;
    const crashPoint = Number(this.crashPoint) || rounded;
    const graceCap = crashGraceActive ? Math.max(1, crashPoint - 0.01) : crashPoint;
    const settleAt = Math.min(rounded, graceCap);

    const resolved = [];
    for (const [user, bet] of this.bets) {
      if (settleAt >= bet.cashout) {
        const grossPayout = Math.floor(bet.amount * bet.cashout);
        const profit = Math.max(0, grossPayout - bet.amount);
        const tax = Math.max(0, Math.floor(profit * 0.05));
        const payout = Math.max(0, grossPayout - tax);
        this.store.credit(user, payout);
        if (tax > 0 && this.store.addTaxToPot) this.store.addTaxToPot(tax);
        const v = this._userView(user);
        const row = {
          user,
          displayName: v.displayName,
          nameStyle: v.nameStyle,
          level: v.level,
          rank: v.rank,
          result: "win",
          grossPayout,
          payout,
          profit,
          tax,
          cashout: bet.cashout,
          bet: Number(bet.amount || 0),
        };
        this.store.awardXP(user, "CASHOUT_SUCCESS", Math.max(1, bet.cashout / 2));
        this._winsThisRound.push(row);
        try {
          this.onCashoutWin({
            user,
            displayName: v.displayName,
            cashout: bet.cashout,
            payout,
            grossPayout,
            roundId: this.roundId,
            at: Date.now(),
          });
        } catch (_) {
          /* ignore website stats hook errors */
        }
        resolved.push(user);
      }
    }
    for (const user of resolved) this.bets.delete(user);
    if (resolved.length) this.onUpdate();
    if (this.bets.size === 0) return this._finishRound(this.crashPoint);

    const maxRunMs = Math.max(0, Number(this.opts.maxRunSeconds) || 0) * 1000;
    if (maxRunMs > 0 && this._runStartedAt > 0 && Date.now() - this._runStartedAt >= maxRunMs) {
      return this._finishRound(settleAt);
    }
    if (!crashGraceActive && rounded >= this.crashPoint) return this._finishRound(this.crashPoint);

    this.multiplier = settleAt;
    this.onUpdate();
    this._tickTimer = setTimeout(() => this._tick(), this.opts.tickMs);
  }

  _queueNextRound() {
    const ms = Number(this.opts.autoRestartMs) || 0;
    if (ms < 500) return;
    if (this._betweenRoundTimer) clearTimeout(this._betweenRoundTimer);
    this.nextRoundStartsAt = Date.now() + ms;
    this._betweenRoundTimer = setTimeout(() => {
      this._betweenRoundTimer = null;
      this.nextRoundStartsAt = null;
      this.startRound();
    }, ms);
    this.onUpdate();
  }

  _pickSpinSegment() {
    const total = SPIN_SEGMENTS.reduce((sum, s) => sum + s.weight, 0);
    let r = Math.random() * total;
    for (const s of SPIN_SEGMENTS) {
      r -= s.weight;
      if (r <= 0) return s;
    }
    return SPIN_SEGMENTS[SPIN_SEGMENTS.length - 1];
  }

  _runSpinQueueThenNextRound() {
    if (this._spinQueueActive) return;
    this._spinQueueActive = true;
    const runOne = () => {
      if (!this.pendingSpins.length) {
        this.spinPauseEndsAt = null;
        this._spinQueueActive = false;
        this.onUpdate();
        this._queueNextRound();
        return;
      }
      const ticket = this.pendingSpins.shift();
      const seg = this._pickSpinSegment();
      const payout = Math.max(0, Math.floor(Number(ticket.cost || 0) * Number(seg.multiplier || 0)));
      if (payout > 0) this.store.credit(ticket.user, payout);
      const durationMs = Math.max(1200, Math.floor(Number(this.opts.spinAnimationMs) || 7000));
      this.spinPauseEndsAt = Date.now() + durationMs;
      this.onEvent({
        type: "spin_play",
        user: ticket.user,
        displayName: ticket.displayName,
        nameStyle: ticket.nameStyle,
        level: ticket.level,
        rank: ticket.rank,
        cost: ticket.cost,
        payout,
        net: payout - ticket.cost,
        balance: this.store.getBalance(ticket.user),
        resultId: seg.id,
        resultLabel: seg.label,
        segments: SPIN_SEGMENTS.map((s) => ({ id: s.id, label: s.label })),
        durationMs,
      });
      this.onUpdate();
      setTimeout(runOne, durationMs + 250);
    };
    runOne();
  }

  _runPostRoundFlow() {
    if (this.pendingSpins.length > 0) return this._runSpinQueueThenNextRound();
    this._queueNextRound();
  }

  armSteal(user, charges = 1) {
    const u = this._normUser(user);
    const add = Math.max(1, Math.floor(Number(charges) || 1));
    if (typeof this.store.addPowerupCharges === "function") {
      const out = this.store.addPowerupCharges(u, "steal", add);
      if (!out.ok) return out;
      return { ok: true, user: u, stealsReady: out.count, added: add, inventory: out.inventory };
    }
    const next = Number(this._armedSteals.get(u) || 0) + add;
    this._armedSteals.set(u, next);
    return { ok: true, user: u, stealsReady: next, added: add };
  }

  armShieldBreak(user, charges = 1) {
    const u = this._normUser(user);
    const add = Math.max(1, Math.floor(Number(charges) || 1));
    if (typeof this.store.addPowerupCharges === "function") {
      const out = this.store.addPowerupCharges(u, "shield_break", add);
      if (!out.ok) return out;
      return { ok: true, user: u, shieldBreaksReady: out.count, added: add, inventory: out.inventory };
    }
    const next = Number(this._armedShieldBreaks.get(u) || 0) + add;
    this._armedShieldBreaks.set(u, next);
    return { ok: true, user: u, shieldBreaksReady: next, added: add };
  }

  armJetLock(user, charges = 1) {
    const u = this._normUser(user);
    const add = Math.max(1, Math.floor(Number(charges) || 1));
    if (typeof this.store.addPowerupCharges === "function") {
      const out = this.store.addPowerupCharges(u, "jet_lock", add);
      if (!out.ok) return out;
      return { ok: true, user: u, jetLocksReady: out.count, added: add, inventory: out.inventory };
    }
    const next = Number(this._armedJetLocks.get(u) || 0) + add;
    this._armedJetLocks.set(u, next);
    return { ok: true, user: u, jetLocksReady: next, added: add };
  }

  applyShield(user, durationMs) {
    return this.store.shieldUser(user, durationMs, "racing_debut");
  }

  _runBackupNow(rawActor) {
    const actor = this._normUser(rawActor);
    const view = this._userView(actor);
    if (!this.store || typeof this.store.createDataBackup !== "function") {
      return { ok: false, reason: "backup_unavailable", user: actor, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank };
    }
    try {
      const out = this.store.createDataBackup({ keepLatest: 12 });
      return { ok: !!(out && out.ok), user: actor, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank, backupDir: out && out.backupDir ? out.backupDir : null, deleted: out && Number.isFinite(out.deleted) ? out.deleted : 0 };
    } catch (err) {
      return { ok: false, reason: "backup_failed", error: String(err && err.message ? err.message : err), user: actor, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank };
    }
  }

  _trySteal(thief, targetRaw) {
    const from = this._normUser(thief);
    const target = this._normUser(targetRaw);
    const fromView = this._userView(from);
    const targetView = this._userView(target);
    if (!target) return { ok: false, reason: "invalid_target", user: from };
    if (from.toLowerCase() === target.toLowerCase()) return { ok: false, reason: "same_user", user: from, target };
    if (target.toLowerCase() === HOST_STEAL_PROTECTED_USER) return { ok: false, reason: "target_host_protected", user: from, target };

    const unlimitedSteal = this._isHostUnlimitedStealUser(from);
    const armed = unlimitedSteal
      ? HOST_UNLIMITED_STEAL_VISIBLE
      : typeof this.store.getPowerupInventory === "function"
      ? Number(this.store.getPowerupInventory(from).stealCharges || 0)
      : Number(this._armedSteals.get(from) || 0);
    if (!unlimitedSteal && armed <= 0) return { ok: false, reason: "steal_not_armed", user: from, target, stealsReady: 0 };

    const shield = this.store.getShieldStatus(target);
    if (shield.active) {
      return { ok: false, reason: "target_shielded", user: from, target, secondsLeft: Math.ceil(shield.msLeft / 1000), stealsReady: armed };
    }

    const moved = this.store.transferAllPoints(target, from);
    if (!moved.ok) return { ok: false, reason: moved.reason === "empty_target" ? "target_empty" : "steal_failed", user: from, target, stealsReady: armed };
    this._clearShieldBreakLock(target);

    let left = unlimitedSteal ? HOST_UNLIMITED_STEAL_VISIBLE : Math.max(0, armed - 1);
    if (!unlimitedSteal) {
      if (typeof this.store.consumePowerupCharge === "function") {
        const consumed = this.store.consumePowerupCharge(from, "steal", 1);
        left = consumed.ok ? Number(consumed.count || 0) : left;
      } else if (left <= 0) this._armedSteals.delete(from);
      else this._armedSteals.set(from, left);
    }

    let bountyClaimed = null;
    if (this.activeBounty && String(this.activeBounty.target || "").toLowerCase() === target.toLowerCase()) {
      const bonus = Math.max(0, Math.floor(Number(this.activeBounty.amount) || 0));
      if (bonus > 0) {
        this.store.credit(from, bonus);
        bountyClaimed = { target, amount: bonus, setter: this.activeBounty.setter };
      }
      this.activeBounty = null;
    }

    return {
      ok: true,
      user: from,
      displayName: fromView.displayName,
      nameStyle: fromView.nameStyle,
      level: fromView.level,
      rank: fromView.rank,
      target,
      targetDisplayName: targetView.displayName,
      targetNameStyle: targetView.nameStyle,
      targetLevel: targetView.level,
      targetRank: targetView.rank,
      stolen: moved.amount,
      balance: this.store.getBalance(from),
      stealsReady: left,
      bountyClaimed,
    };
  }

  _tryBreakShield(actor, targetRaw) {
    const from = this._normUser(actor);
    const target = this._normUser(targetRaw);
    if (!target) return { ok: false, reason: "invalid_target", user: from };
    if (from.toLowerCase() === target.toLowerCase()) return { ok: false, reason: "same_user", user: from, target };
    const armed = typeof this.store.getPowerupInventory === "function" ? Number(this.store.getPowerupInventory(from).shieldBreakCharges || 0) : Number(this._armedShieldBreaks.get(from) || 0);
    if (armed <= 0) return { ok: false, reason: "shield_break_not_armed", user: from, target, shieldBreaksReady: 0 };

    const broken = this.store.breakShield(target, "car_drifting_break");
    if (!broken.ok) return { ok: false, reason: broken.reason, user: from, target, shieldBreaksReady: armed };
    let left = Math.max(0, armed - 1);
    if (typeof this.store.consumePowerupCharge === "function") {
      const consumed = this.store.consumePowerupCharge(from, "shield_break", 1);
      left = consumed.ok ? Number(consumed.count || 0) : left;
    } else if (left <= 0) this._armedShieldBreaks.delete(from);
    else this._armedShieldBreaks.set(from, left);
    const lock = this._setShieldBreakLock(target, Math.max(1, Math.floor(Number(this.opts.shieldBreakLockMs) || 300000)));
    this.onUpdate();
    return { ok: true, user: from, target, shieldBreaksReady: left, reducedMs: broken.reducedMs || 0, shieldMsBefore: broken.shieldMsBefore || 0, shieldMsLeft: broken.shieldMsLeft || 0, fullyBroken: !!broken.fullyBroken, targetLockSeconds: lock ? Math.max(1, Math.ceil((lock.blockedUntil - Date.now()) / 1000)) : 0, targetBlockedUntil: lock ? lock.blockedUntil : 0 };
  }

  _tryJetLock(actor, targetRaw) {
    const from = this._normUser(actor);
    const target = this._normUser(targetRaw);
    if (!target) return { ok: false, reason: "invalid_target", user: from };
    if (from.toLowerCase() === target.toLowerCase()) return { ok: false, reason: "same_user", user: from, target };
    const armed = typeof this.store.getPowerupInventory === "function" ? Number(this.store.getPowerupInventory(from).jetLockCharges || 0) : Number(this._armedJetLocks.get(from) || 0);
    if (armed <= 0) return { ok: false, reason: "jet_lock_not_armed", user: from, target, jetLocksReady: 0 };
    const lock = this._setJetLock(target, Math.max(1, Math.floor(Number(this.opts.flyingJetLockMs) || 3600000)));
    let left = Math.max(0, armed - 1);
    if (typeof this.store.consumePowerupCharge === "function") {
      const consumed = this.store.consumePowerupCharge(from, "jet_lock", 1);
      left = consumed.ok ? Number(consumed.count || 0) : left;
    } else if (left <= 0) this._armedJetLocks.delete(from);
    else this._armedJetLocks.set(from, left);
    this.onUpdate();
    return { ok: true, user: from, target, jetLocksReady: left, targetLockSeconds: lock ? lock.secondsLeft : 0, targetBlockedUntil: lock ? lock.blockedUntil : 0 };
  }

  _placeBounty(rawSetter, rawTarget, rawAmount) {
    const setter = this._normUser(rawSetter);
    const target = this._normUser(rawTarget);
    const amount = Math.floor(Number(rawAmount) || 0);
    const min = Math.max(1, Math.floor(Number(this.opts.bountyMinPoints) || 500));
    if (!target) return { ok: false, reason: "invalid_target", user: setter };
    if (setter.toLowerCase() === target.toLowerCase()) return { ok: false, reason: "self_target", user: setter, target };
    if (amount < min) return { ok: false, reason: "bounty_too_small", user: setter, min };
    this.store.ensureAccount(setter);
    const debit = this.store.tryDebit(setter, amount);
    if (!debit.ok) return { ok: false, reason: debit.reason, user: setter, balance: debit.balance };
    this.activeBounty = { target, amount, setter, createdAt: Date.now() };
    this.onUpdate();
    const sv = this._userView(setter);
    const tv = this._userView(target);
    return { ok: true, user: setter, displayName: sv.displayName, nameStyle: sv.nameStyle, level: sv.level, rank: sv.rank, target, targetDisplayName: tv.displayName, targetNameStyle: tv.nameStyle, targetLevel: tv.level, targetRank: tv.rank, amount, balance: this.store.getBalance(setter) };
  }

  _setPinnedMessage(rawUser, rawText) {
    const user = this._normUser(rawUser);
    const text = String(rawText || "").trim().replace(/\s+/g, " ").slice(0, 120);
    const cost = Math.max(1, Math.floor(Number(this.opts.pinMessageCost) || 3000));
    const durationMs = Math.max(10_000, Math.floor(Number(this.opts.pinMessageDurationMs) || 180_000));
    if (!text) return { ok: false, reason: "pin_empty", user };
    this.store.ensureAccount(user);
    const debit = this.store.tryDebit(user, cost);
    if (!debit.ok) return { ok: false, reason: debit.reason, user, balance: debit.balance };
    this.pinnedMessage = { user, text, expiresAt: Date.now() + durationMs };
    this.onUpdate();
    const view = this._userView(user);
    return { ok: true, user, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank, text, cost, balance: this.store.getBalance(user), expiresAt: this.pinnedMessage.expiresAt };
  }

  _queueSpinTicket(rawUser) {
    const user = this._normUser(rawUser);
    const cost = Math.max(1, Math.floor(Number(this.opts.spinTicketCost) || 2000));
    if (!(this.phase === PHASE.BETTING || this.phase === PHASE.RUNNING)) return { ok: false, reason: "spin_requires_active_round", user };
    this.store.ensureAccount(user);
    const debit = this.store.tryDebit(user, cost);
    if (!debit.ok) return { ok: false, reason: debit.reason, user, balance: debit.balance };
    const view = this._userView(user);
    this.pendingSpins.push({ user, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank, cost });
    this.onUpdate();
    return { ok: true, user, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank, cost, balance: this.store.getBalance(user), queued: true, queueSize: this.pendingSpins.length };
  }

  _buyNameStyle(rawUser, rawStyle) {
    const user = this._normUser(rawUser);
    const styleId = String(rawStyle || "").trim().toLowerCase();
    const style = NAME_STYLE_SHOP[styleId];
    if (!style) return { ok: false, reason: "style_unknown", user, styles: Object.keys(NAME_STYLE_SHOP) };
    this.store.ensureAccount(user);
    const current = this.store.getNameStyle(user);
    if (current === styleId) return { ok: false, reason: "style_already_active", user, style: styleId };
    if (style.cost > 0) {
      const debit = this.store.tryDebit(user, style.cost);
      if (!debit.ok) return { ok: false, reason: debit.reason, user, balance: debit.balance };
    }
    this.store.setNameStyle(user, styleId);
    this.onUpdate();
    const view = this._userView(user);
    return { ok: true, user, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank, style: styleId, styleIcon: style.icon, cost: style.cost, balance: this.store.getBalance(user) };
  }

  _buyNameBadge(rawUser, rawBadge) {
    const user = this._normUser(rawUser);
    const badgeId = resolveBadgeId(rawBadge);
    const badge = NAME_BADGE_SHOP[badgeId];
    if (!badge) return { ok: false, reason: "badge_unknown", user, badges: Object.keys(NAME_BADGE_SHOP) };
    this.store.ensureAccount(user);
    const currentBadge = typeof this.store.getNameBadge === "function" ? this.store.getNameBadge(user) : "none";
    if (currentBadge === badgeId) return { ok: false, reason: "badge_already_active", user, badge: badgeId };
    const owns = typeof this.store.ownsNameBadge === "function" ? this.store.ownsNameBadge(user, badgeId) : false;
    let charged = 0;
    if (!owns) {
      const debit = this.store.tryDebit(user, badge.cost);
      if (!debit.ok) return { ok: false, reason: debit.reason, user, balance: debit.balance };
      charged = badge.cost;
      if (typeof this.store.addOwnedNameBadge === "function") this.store.addOwnedNameBadge(user, badgeId);
    }
    if (typeof this.store.setNameBadge === "function") this.store.setNameBadge(user, badgeId);
    this.onUpdate();
    const view = this._userView(user);
    return { ok: true, user, displayName: view.displayName, nameStyle: view.nameStyle, nameBadge: view.nameBadge || badgeId, level: view.level, rank: view.rank, badge: badgeId, badgeLabel: badge.label, badgeShort: badge.short, tier: badge.tier, cost: charged, switched: owns, ownedBadges: typeof this.store.getOwnedBadges === "function" ? this.store.getOwnedBadges(user) : [], balance: this.store.getBalance(user) };
  }

  _sellCrown(rawUser) {
    const user = this._normUser(rawUser);
    this.store.ensureAccount(user);
    const revoke =
      typeof this.store.revokeNameBadge === "function"
        ? this.store.revokeNameBadge(user, "crown")
        : { ok: false, reason: "crown_not_owned" };
    if (!revoke.ok) {
      return { ok: false, reason: revoke.reason || "crown_not_owned", user, balance: this.store.getBalance(user) };
    }
    this.store.add(user, CROWN_SELL_REFUND, { countAsEarned: false });
    this.onUpdate();
    const view = this._userView(user);
    return {
      ok: true,
      user,
      displayName: view.displayName,
      nameStyle: view.nameStyle,
      level: view.level,
      rank: view.rank,
      soldBadge: "crown",
      refund: CROWN_SELL_REFUND,
      balance: this.store.getBalance(user),
      ownedBadges: typeof this.store.getOwnedBadges === "function" ? this.store.getOwnedBadges(user) : [],
      nameBadge: typeof this.store.getNameBadge === "function" ? this.store.getNameBadge(user) : "none",
    };
  }

  _triggerIconsPopup(rawUser) {
    const user = this._normUser(rawUser);
    const view = this._userView(user);
    const cdMs = Math.max(30_000, Number(this.opts.iconsPopupCooldownMs) || 120_000);
    const durationMs = Math.max(3000, Number(this.opts.iconsPopupDurationMs) || 10_000);
    const now = Date.now();
    if (now - Number(this._iconsPopupLastAt || 0) < cdMs) {
      return { type: "icons_popup", ok: false, cooldown: true, user, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank, secondsLeft: Math.ceil((cdMs - (now - Number(this._iconsPopupLastAt || 0))) / 1000), durationMs };
    }
    this._iconsPopupLastAt = now;
    const badges = listNameBadgeShop().map((b) => ({ id: b.id, label: b.label, short: b.short, tier: b.tier, cost: b.cost }));
    return { type: "icons_popup", ok: true, user, displayName: view.displayName, nameStyle: view.nameStyle, level: view.level, rank: view.rank, durationMs, badges };
  }

  parseChatMessage(rawUser, message) {
    const text = String(message || "").trim();
    const lower = text.toLowerCase();
    const user = this._normUser(rawUser);
    if (!user) return null;

    if (lower === "!points" || lower === "!bal" || lower === "!balance") {
      this.store.ensureAccount(user);
      const balance = this.store.getBalance(user);
      const cdMs = Number(this.opts.balanceShoutCooldownMs) || 30_000;
      const now = Date.now();
      const last = Number(this._balanceShoutAt.get(user) || 0);
      if (now - last < cdMs) {
        const v = this._userView(user);
        return { type: "balance_shout", ok: false, cooldown: true, user, displayName: v.displayName, nameStyle: v.nameStyle, level: v.level, rank: v.rank, balance, secondsLeft: Math.ceil((cdMs - (now - last)) / 1000) };
      }
      this._balanceShoutAt.set(user, now);
      const v = this._userView(user);
      const inventory = typeof this.store.getPowerupInventory === "function"
        ? this.store.getPowerupInventory(user)
        : { stealCharges: Number(this._armedSteals.get(user) || 0), shieldBreakCharges: Number(this._armedShieldBreaks.get(user) || 0), jetLockCharges: Number(this._armedJetLocks.get(user) || 0) };
      if (this._isHostUnlimitedStealUser(user)) inventory.stealCharges = HOST_UNLIMITED_STEAL_VISIBLE;
      return { type: "balance_shout", ok: true, user, displayName: v.displayName, nameStyle: v.nameStyle, level: v.level, rank: v.rank, balance, jetLock: this.getJetLockStatus(user), inventory };
    }

    const superFanCmd = text.match(/^!superfan\s+@?([a-zA-Z0-9._-]{1,40})\s*$/i);
    if (superFanCmd) {
      if (user.toLowerCase() !== SUPERFAN_COMMAND_HOST) return { type: "superfan", ok: false, reason: "host_only", user, active: true };
      this.store.setSuperFan(superFanCmd[1], true, 0);
      return { type: "superfan", ok: true, user, target: this._normUser(superFanCmd[1]), active: true };
    }

    const removeSuperFanCmd = text.match(/^!removesuperfan\s+@?([a-zA-Z0-9._-]{1,40})\s*$/i);
    if (removeSuperFanCmd) {
      if (user.toLowerCase() !== SUPERFAN_COMMAND_HOST) return { type: "superfan", ok: false, reason: "host_only", user, active: false };
      this.store.setSuperFan(removeSuperFanCmd[1], false, 0);
      return { type: "superfan", ok: true, user, target: this._normUser(removeSuperFanCmd[1]), active: false };
    }

    const addPointsCmd = text.match(/^!addpoints\s+@?([a-zA-Z0-9._-]{1,40})\s+(-?\d+)\s*$/i);
    if (addPointsCmd) {
      if (user.toLowerCase() !== ADMIN_POINTS_COMMAND_HOST) return { type: "addpoints", ok: false, reason: "host_only", user };
      const target = this._normUser(addPointsCmd[1]);
      const amount = Math.floor(Number(addPointsCmd[2]) || 0);
      this.store.ensureAccount(target);
      const before = this.store.getBalance(target);
      this.store.add(target, amount, { countAsEarned: amount > 0 });
      const after = this.store.getBalance(target);
      this.onUpdate();
      return { type: "addpoints", ok: true, user, target, amount, before, balance: after };
    }

    if (lower === "!backupnow") {
      if (user.toLowerCase() !== BACKUP_COMMAND_HOST) return { type: "backupnow", ok: false, reason: "host_only", user };
      return { type: "backupnow", ...this._runBackupNow(user) };
    }

    const jetLock = this._getJetLock(user);
    if (jetLock) {
      const v = this._userView(user);
      return { type: "command_lock", ok: false, reason: "jet_lock_active", user, displayName: v.displayName, nameStyle: v.nameStyle, level: v.level, rank: v.rank, secondsLeft: jetLock.secondsLeft, blockedUntil: jetLock.blockedUntil };
    }

    const betCmd = parseBetCommand(text);
    if (betCmd) {
      let { amount, cashout } = betCmd;
      const requestedAllIn = !!betCmd.allIn;
      if (requestedAllIn) {
        this.store.ensureAccount(user);
        const queuedRefund = this.phase !== PHASE.BETTING && this.queuedBets.has(user)
          ? Math.max(0, Math.floor(Number(this.queuedBets.get(user)?.amount || 0)))
          : 0;
        amount = Math.max(0, Math.floor(this.store.getBalance(user)) + queuedRefund);
      }
      let res = this.placeBet(user, amount, cashout);
      if (!res.ok && res.reason === "not_betting") res = this.queueBet(user, amount, cashout);
      const v = this._userView(user);
      return { type: "bet", user, displayName: v.displayName, nameStyle: v.nameStyle, level: v.level, rank: v.rank, amount, cashout, requestedAllIn, ...res };
    }

    const stealCmd = text.match(/^!steal\s+@?([a-zA-Z0-9._-]{1,40})\s*$/i);
    if (stealCmd) return { type: "steal", ...this._trySteal(user, stealCmd[1]) };

    const breakShieldCmd = text.match(/^!break\s+@?([a-zA-Z0-9._-]{1,40})\s*$/i);
    if (breakShieldCmd) return { type: "shield_break", ...this._tryBreakShield(user, breakShieldCmd[1]) };

    const jetLockCmd = text.match(/^!freeze\s+@?([a-zA-Z0-9._-]{1,40})\s*$/i);
    if (jetLockCmd) return { type: "jet_lock", ...this._tryJetLock(user, jetLockCmd[1]) };

    const bountyCmd = text.match(/^!bounty\s+@?([a-zA-Z0-9._-]{1,40})\s+(\d+)\s*$/i);
    if (bountyCmd) return { type: "bounty", ...this._placeBounty(user, bountyCmd[1], bountyCmd[2]) };

    if (lower === "!icons" || lower === "!vault" || lower === "!badges") return this._triggerIconsPopup(user);
    if (lower === "!spin" || lower === "!wheel") return { type: "spin_ticket", ...this._queueSpinTicket(user) };

    const pinCmd = text.match(/^!pin\s+(.+)$/i);
    if (pinCmd) return { type: "pin", ...this._setPinnedMessage(user, pinCmd[1]) };

    const nameFxCmd = text.match(/^!namefx\s+([a-z0-9_-]{1,20})\s*$/i);
    if (nameFxCmd) return { type: "namefx", ...this._buyNameStyle(user, nameFxCmd[1]) };

    const buyCmd = text.match(/^!buy\s+([a-z0-9_-]{1,20})\s*$/i);
    if (buyCmd) return { type: "buy", ...this._buyNameBadge(user, buyCmd[1]) };

    if (/^!sellcrown\s*$/i.test(text) || /^!sell\s+crown\s*$/i.test(text)) {
      return { type: "sell_crown", ...this._sellCrown(user) };
    }

    return null;
  }
}

module.exports = { CrashGame, PHASE, NAME_STYLE_SHOP, NAME_BADGE_SHOP, listNameBadgeShop };
