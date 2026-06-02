/**
 * NFG Arcade — Stake-style mini-games (Roll Line, Hi-Lo, Mines, Plinko, Wheel, Dragon Tower).
 * Each round stakes / credits the main Crash pointStore balance.
 * Global cooldown between staked rounds limits spam (see ARCADE_ROUND_COOLDOWN_MS).
 */
const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");
const { buildWalletPayload } = require("./mobile-wallet");
const { getTikTokBridgeStatus } = require("./tiktok-bridge");
const {
  TOWER_SLOTS,
  TOWER_GEAR,
  TOWER_CONSUMABLES,
  getTowerGear,
  getTowerConsumable,
  defaultTowerEquipment,
  migrateTowerHeroGear,
  towerHeroVisuals,
  towerHeroStatsFromGear,
  towerShopForLevel,
  towerShopBySlot,
} = require("./tower-gear");

const DATA_FILE = path.join(getAppRoot(), "data", "arcade-state.json");
const LIVE_WIN_MULT = 1.15;
const MAX_SKILL = 10;
/** Arcade house edge — same or worse than Crash (crash.js uses 3%). */
const ARCADE_HOUSE_EDGE = 0.04;
const ARCADE_EDGE_MULT = 1 - ARCADE_HOUSE_EDGE;
/** 5% of profit on wins — same as Crash cashout; credited to the global tax pot. */
const WIN_PROFIT_TAX_RATE = 0.05;
/** Minimum gap between staked arcade rounds (play / spin / start) per user. */
const ARCADE_ROUND_COOLDOWN_MS = 15_000;

const GAME_DEFS = [
  {
    id: "nfg_dice",
    title: "Roll Line",
    subtitle: "Roll under or over your line (0.00–99.99)",
    icon: "🎯",
    helpText: "A random number from 0.00 to 99.99 is rolled. Win if it lands on your chosen side of the line (line is inclusive).",
  },
  {
    id: "nfg_hilo",
    title: "Hi-Lo",
    subtitle: "Higher or lower — chain the streak",
    icon: "🃏",
    helpText: "Guess if the next card is higher or lower. Each correct guess raises your multiplier — cash out anytime.",
  },
  {
    id: "nfg_mines",
    title: "Mines",
    subtitle: "Reveal gems — hit a mine and lose",
    icon: "💣",
    helpText: "Reveal safe tiles to grow multiplier. Cash out before hitting a mine.",
  },
  {
    id: "nfg_plinko",
    title: "Plinko",
    subtitle: "Drop the ball — land a multiplier",
    icon: "⚪",
    helpText: "One drop per stake. Ball lands in a bucket with a multiplier.",
  },
  {
    id: "nfg_wheel",
    title: "Wheel",
    subtitle: "Spin for prize or lose stake",
    icon: "🎡",
    helpText: "Spin once per stake. Pointer lands on LOSE or a payout multiplier.",
  },
  {
    id: "nfg_tower",
    title: "Dragon Tower",
    subtitle: "Turn-based RPG — climb & battle",
    icon: "🐉",
    helpText: "Level your hero, upgrade gear, and fight casino-themed monsters floor by floor. Boss every 10 levels.",
  },
  {
    id: "nfg_blocks",
    title: "NFG Blocks",
    subtitle: "Block puzzle — clear lines for points",
    icon: "🧱",
    helpText: "Place blocks on the 8×8 grid. Clear enough lines to finish each level. Session streak increases payouts.",
  },
];

const STAKE_BASE = {
  nfg_dice: 1200,
  nfg_hilo: 1500,
  nfg_mines: 2000,
  nfg_plinko: 1800,
  nfg_wheel: 2500,
  nfg_tower: 1200,
  nfg_blocks: 0,
};

/** Weights — higher mult = much rarer. Total 1000 → ~4% EV after ARCADE_EDGE. */
const WHEEL_SEGMENTS = [
  { label: "LOSE", mult: 0, weight: 560 },
  { label: "½ back", mult: 0.5, weight: 260 },
  { label: "1.5×", mult: 1.5, weight: 110 },
  { label: "2×", mult: 2, weight: 50 },
  { label: "3×", mult: 3, weight: 15 },
  { label: "JACKPOT", mult: 5, weight: 5 },
];

const PLINKO_BUCKETS = {
  low: [0.4, 0.6, 0.8, 1, 1.2, 1.5, 1.2, 1, 0.8, 0.6, 0.4],
  med: [0.2, 0.5, 0.8, 1.1, 1.6, 2.2, 1.6, 1.1, 0.8, 0.5, 0.2],
  high: [0, 0.2, 0.5, 1, 2, 5, 2, 1, 0.5, 0.2, 0],
};

function ukDayKey(now = Date.now()) {
  const fmt = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = fmt.formatToParts(new Date(now));
  const y = parts.find((p) => p.type === "year")?.value;
  const m = parts.find((p) => p.type === "month")?.value;
  const d = parts.find((p) => p.type === "day")?.value;
  return `${y}-${m}-${d}`;
}

function loadState() {
  try {
    if (fs.existsSync(DATA_FILE)) {
      return JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
    }
  } catch (_) {
    /* ignore */
  }
  return { users: {} };
}

function saveState(state) {
  const dir = path.dirname(DATA_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(state, null, 2));
}

function normUser(user) {
  return String(user || "")
    .trim()
    .replace(/^@+/, "")
    .toLowerCase()
    .slice(0, 40);
}

function ensureUser(state, user) {
  const u = normUser(user);
  if (!u) return null;
  if (!state.users[u]) {
    state.users[u] = {
      dayKey: "",
      stats: { rounds: 0, wins: 0, lost: 0 },
      games: {},
    };
  }
  const dayKey = ukDayKey();
  if (state.users[u].dayKey !== dayKey) {
    state.users[u].dayKey = dayKey;
    state.users[u].stats = { rounds: 0, wins: 0, lost: 0 };
  }
  return state.users[u];
}

function isLive() {
  try {
    return getTikTokBridgeStatus().state === "live";
  } catch (_) {
    return false;
  }
}

function skillOf(userRec, gameId) {
  return Math.min(MAX_SKILL, Math.max(1, userRec.games[gameId]?.skillLevel || 1));
}

function defaultStake(gameId, skill) {
  const base = STAKE_BASE[gameId] || 2000;
  return Math.floor(base * (1 + (skill - 1) * 0.08));
}

function stakeBounds(gameId, skill, balance) {
  const def = defaultStake(gameId, skill);
  const min = Math.max(100, Math.floor(def * 0.25));
  const capHigh = Math.floor(def * 3);
  const bal = Math.max(0, Math.floor(Number(balance) || 0));
  const max = bal > 0 ? Math.max(min, Math.min(bal, capHigh)) : Math.max(min, capHigh);
  return { min, max, default: def };
}

function clampStake(gameId, skill, payloadStake, balance) {
  const { min, max, default: def } = stakeBounds(gameId, skill, balance);
  let stake = Math.floor(Number(payloadStake) || def);
  if (!Number.isFinite(stake)) stake = def;
  return Math.max(min, Math.min(max, stake));
}

function debitStake(pointStore, user, amount) {
  const need = Math.max(1, Math.floor(amount));
  const res = pointStore.tryDebit(user, need);
  if (!res.ok) {
    return {
      ok: false,
      reason: "insufficient",
      message: `Need ${need.toLocaleString()} pts (balance ${(res.balance || 0).toLocaleString()}).`,
      balance: res.balance || 0,
    };
  }
  return { ok: true, stake: need, balance: res.balance };
}

function creditWin(pointStore, user, amount) {
  let gain = Math.max(0, Math.floor(amount));
  if (gain <= 0) return 0;
  if (isLive()) gain = Math.floor(gain * LIVE_WIN_MULT);
  pointStore.add(user, gain, { countAsEarned: true });
  return gain;
}

function recordRound(userRec, won, lostAmount) {
  userRec.stats.rounds = (userRec.stats.rounds || 0) + 1;
  if (won) userRec.stats.wins = (userRec.stats.wins || 0) + 1;
  if (lostAmount > 0) userRec.stats.lost = (userRec.stats.lost || 0) + lostAmount;
}

function bumpSkill(userRec, gameId, good) {
  const gRec = userRec.games[gameId] || {};
  if (good && (gRec.skillLevel || 1) < MAX_SKILL) {
    gRec.skillLevel = (gRec.skillLevel || 1) + 1;
  } else if (!good && (gRec.skillLevel || 1) > 1 && Math.random() < 0.12) {
    gRec.skillLevel = Math.max(1, (gRec.skillLevel || 1) - 1);
  }
  userRec.games[gameId] = gRec;
}

function isStakedAction(action) {
  const a = String(action || "").toLowerCase();
  return a === "play" || a === "spin" || a === "start";
}

function cooldownFields(userRec, now = Date.now()) {
  const last = Number(userRec.lastArcadeStakeAt) || 0;
  const leftMs = Math.max(0, ARCADE_ROUND_COOLDOWN_MS - (now - last));
  const seconds = Math.ceil(leftMs / 1000);
  return {
    cooldownSecondsLeft: seconds,
    arcadeCooldownActive: leftMs > 0,
  };
}

function touchArcadeStake(userRec, now = Date.now()) {
  userRec.lastArcadeStakeAt = now;
}

function cooldownBlock(userRec, pointStore, user, gameId) {
  const cd = cooldownFields(userRec);
  if (!cd.arcadeCooldownActive) return null;
  return {
    ok: false,
    reason: "cooldown",
    message: `Wait ${cd.cooldownSecondsLeft}s before the next arcade round.`,
    ...cd,
    ...baseFields(userRec, gameId, pointStore, user),
  };
}

function baseFields(userRec, gameId, pointStore, user) {
  const skill = skillOf(userRec, gameId);
  const balance = pointStore.getBalance(user);
  const bounds = stakeBounds(gameId, skill, balance);
  return {
    skillLevel: skill,
    maxSkillLevel: MAX_SKILL,
    playsPerDay: 0,
    playsLeft: 9999,
    playsUsed: userRec.stats.rounds || 0,
    suggestedStake: bounds.default,
    stakeMin: bounds.min,
    stakeMax: bounds.max,
    balance,
    unlimited: true,
    ...cooldownFields(userRec),
  };
}

function outcome(pointStore, user, userRec, { stake, payout, won, gameId }) {
  const grossPayout = won ? Math.max(0, Math.floor(payout)) : 0;
  let tax = 0;
  let netPayout = 0;
  let gained = 0;

  if (won && grossPayout > 0) {
    const settled = settleArcadeWin(pointStore, stake, grossPayout);
    tax = settled.tax;
    netPayout = settled.netPayout;
    gained = creditWin(pointStore, user, netPayout);
  }

  const lost = won ? 0 : stake;
  if (!won) recordRound(userRec, false, stake);
  else recordRound(userRec, true, 0);
  bumpSkill(userRec, gameId, won);
  const net = gained - (won ? 0 : stake);
  return {
    ok: true,
    won,
    stake,
    gained,
    grossPayout: won ? grossPayout : 0,
    tax: won ? tax : 0,
    lost: won ? 0 : stake,
    net,
    balance: pointStore.getBalance(user),
    message: won
      ? tax > 0
        ? `Won ${gained.toLocaleString()} pts (${tax.toLocaleString()} pts → tax pot)`
        : `Won ${gained.toLocaleString()} pts`
      : `Lost ${stake.toLocaleString()} pts`,
  };
}

function buildMissions(userRec) {
  const s = userRec.stats || {};
  return [
    {
      id: "win_5",
      title: "Win 5 arcade rounds today",
      goal: 5,
      progress: s.wins || 0,
      done: (s.wins || 0) >= 5,
      claimed: false,
    },
    {
      id: "play_10",
      title: "Play 10 staked rounds today",
      goal: 10,
      progress: s.rounds || 0,
      done: (s.rounds || 0) >= 10,
      claimed: false,
    },
    {
      id: "live_win",
      title: "Win a round while LIVE",
      goal: 1,
      progress: s.liveWin || 0,
      done: (s.liveWin || 0) >= 1,
      claimed: false,
    },
  ];
}

function catalogGames(userRec, pointStore, user) {
  return GAME_DEFS.map((g) => {
    const skill = skillOf(userRec, g.id);
    return {
      id: g.id,
      title: g.title,
      subtitle: g.subtitle,
      icon: g.icon,
      playsPerDay: 0,
      playsUsed: userRec.stats.rounds || 0,
      playsLeft: 9999,
      skillLevel: skill,
      maxSkillLevel: MAX_SKILL,
      suggestedStake: defaultStake(g.id, skill),
      helpText: g.helpText,
      houseEdge: ARCADE_HOUSE_EDGE,
      winProfitTax: WIN_PROFIT_TAX_RATE,
    };
  });
}

function applyArcadeEdge(amount) {
  return Math.max(0, Math.floor(amount * ARCADE_EDGE_MULT));
}

/** Gross after house edge, minus 5% profit tax (same as Crash cashout). Tax goes to global pot. */
function settleArcadeWin(pointStore, stake, grossPayout) {
  const gross = Math.max(0, Math.floor(grossPayout));
  const st = Math.max(0, Math.floor(stake));
  const profit = Math.max(0, gross - st);
  const tax = Math.max(0, Math.floor(profit * WIN_PROFIT_TAX_RATE));
  const netPayout = Math.max(0, gross - tax);
  if (tax > 0 && pointStore && typeof pointStore.addTaxToPot === "function") {
    pointStore.addTaxToPot(tax);
  }
  return { grossPayout: gross, profit, tax, netPayout };
}

function diceFairMult(mode, target) {
  if (mode === "under") return 100 / (target + 1);
  return 100 / (101 - target);
}

function pickWheelSegment() {
  const total = WHEEL_SEGMENTS.reduce((s, x) => s + x.weight, 0);
  let r = Math.random() * total;
  for (let i = 0; i < WHEEL_SEGMENTS.length; i++) {
    const seg = WHEEL_SEGMENTS[i];
    r -= seg.weight;
    if (r <= 0) return { seg, index: i };
  }
  return { seg: WHEEL_SEGMENTS[0], index: 0 };
}

function pickPlinkoBucket(risk) {
  const mults = PLINKO_BUCKETS[risk] || PLINKO_BUCKETS.med;
  const rows = mults.length - 1;
  // Fair peg physics: each row is 50/50 left/right → binomial spread across buckets.
  let rights = 0;
  for (let i = 0; i < rows; i++) {
    if (Math.random() < 0.5) rights += 1;
  }
  return rights;
}

const HILO_SUITS = ["spades", "hearts", "diamonds", "clubs"];

function drawHiLoCard() {
  return {
    rank: 1 + Math.floor(Math.random() * 13),
    suit: HILO_SUITS[Math.floor(Math.random() * 4)],
  };
}

function hiloWinProb(rank, direction) {
  const d = String(direction || "").toLowerCase();
  if (d === "hi" || d === "higher") return (13 - rank) / 13;
  if (d === "lo" || d === "lower") return (rank - 1) / 13;
  return 0;
}

function hiloFairStepMult(rank, direction) {
  const prob = hiloWinProb(rank, direction);
  if (prob <= 0) return null;
  return Math.round((1 / prob) * 100) / 100;
}

function handleDice(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_dice";
  const fields = baseFields(userRec, gameId, pointStore, user);

  if (action === "status") {
    return {
      ...fields,
      message: `Roll Line: pick under/over on 0.00–99.99. Stake ~${fields.suggestedStake.toLocaleString()} pts.`,
    };
  }

  if (action !== "play") {
    return { ok: false, reason: "invalid_action", message: "Use play." };
  }

  const stake = clampStake(
    gameId,
    skillOf(userRec, gameId),
    payload.stake,
    pointStore.getBalance(user),
  );
  const debit = debitStake(pointStore, user, stake);
  if (!debit.ok) return { ...debit, ...fields };

  const mode = String(payload.mode || "under").toLowerCase() === "over" ? "over" : "under";
  let target = Math.floor(Number(payload.target) || 50);
  target = Math.max(2, Math.min(98, target));
  const roll = Math.floor(Math.random() * 10000) / 100;
  const won =
    mode === "under" ? roll <= target : roll >= target;
  const fairMult = diceFairMult(mode, target);
  const payout = won
    ? Math.max(1, applyArcadeEdge(Math.floor(stake * fairMult)))
    : 0;

  const res = outcome(pointStore, user, userRec, {
    stake,
    payout,
    won,
    gameId,
  });
  return {
    ...res,
    ...fields,
    roll,
    guess: target,
    direction: mode,
    mode,
    actual: roll,
    win: won,
    won,
  };
}

function handleHiLo(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_hilo";
  const fields = baseFields(userRec, gameId, pointStore, user);
  if (!userRec.games) userRec.games = {};
  if (!userRec.games.nfg_hilo) userRec.games.nfg_hilo = {};
  const gRec = userRec.games.nfg_hilo;

  if (action === "status") {
    const sess = gRec.session;
    return {
      ...fields,
      sessionActive: !!sess,
      cardRank: sess?.card?.rank,
      cardSuit: sess?.card?.suit,
      multiplier: sess?.mult ?? 1,
      streak: sess?.streak ?? 0,
      stake: sess?.stake,
      message: sess
        ? `×${(sess.mult || 1).toFixed(2)} — ${sess.streak || 0} correct — Higher or Lower?`
        : "Stake-style Hi-Lo — chain correct guesses, then cash out.",
    };
  }

  if (action === "start") {
    if (gRec.session) {
      return { ok: false, reason: "in_progress", message: "Finish or cash out first.", ...fields };
    }
    const stake = clampStake(
      gameId,
      skillOf(userRec, gameId),
      payload.stake,
      pointStore.getBalance(user),
    );
    const debit = debitStake(pointStore, user, stake);
    if (!debit.ok) return { ...debit, ...fields };

    const card = drawHiLoCard();
    gRec.session = { stake, card, mult: 1, streak: 0 };
    userRec.games.nfg_hilo = gRec;

    return {
      ok: true,
      ...fields,
      sessionActive: true,
      cardRank: card.rank,
      cardSuit: card.suit,
      multiplier: 1,
      streak: 0,
      stake,
      balance: debit.balance,
      message: `${stake.toLocaleString()} pts staked — is the next card Higher or Lower?`,
    };
  }

  if (action === "cashout") {
    const sess = gRec.session;
    if (!sess) {
      return { ok: false, reason: "not_started", message: "Start a round first.", ...fields };
    }
    if ((sess.streak || 0) < 1) {
      return {
        ok: false,
        reason: "need_guess",
        message: "Make at least one correct guess before cashing out.",
        ...fields,
      };
    }
    const stake = sess.stake;
    const payout = applyArcadeEdge(Math.floor(stake * (sess.mult || 1)));
    gRec.session = null;
    userRec.games.nfg_hilo = gRec;
    const res = outcome(pointStore, user, userRec, {
      stake,
      payout,
      won: payout > stake,
      gameId,
    });
    return {
      ...res,
      ...fields,
      sessionActive: false,
      cleared: true,
      multiplier: sess.mult,
      streak: sess.streak,
      cardRank: sess.card.rank,
      cardSuit: sess.card.suit,
    };
  }

  if (action !== "guess") {
    return { ok: false, reason: "invalid_action", message: "Use start, guess, or cashout." };
  }

  const sess = gRec.session;
  if (!sess) {
    return { ok: false, reason: "not_started", message: "Start a round first.", ...fields };
  }

  const direction = String(payload.direction || "").toLowerCase();
  if (direction !== "hi" && direction !== "lo") {
    return { ok: false, reason: "invalid_guess", message: "Pick Higher or Lower.", ...fields };
  }

  const prob = hiloWinProb(sess.card.rank, direction);
  if (prob <= 0) {
    return {
      ok: false,
      reason: "invalid_guess",
      message: direction === "hi" ? "King is highest — only Lower works." : "Ace is lowest — only Higher works.",
      ...fields,
    };
  }

  const prev = { ...sess.card };
  const next = drawHiLoCard();
  const correct =
    direction === "hi" ? next.rank > prev.rank : next.rank < prev.rank;

  if (!correct) {
    const stake = sess.stake;
    gRec.session = null;
    userRec.games.nfg_hilo = gRec;
    return {
      ...outcome(pointStore, user, userRec, { stake, payout: 0, won: false, gameId }),
      ...fields,
      sessionActive: false,
      bust: true,
      hiloCorrect: false,
      direction,
      prevCardRank: prev.rank,
      prevCardSuit: prev.suit,
      nextCardRank: next.rank,
      nextCardSuit: next.suit,
      cardRank: next.rank,
      cardSuit: next.suit,
      multiplier: sess.mult,
      streak: sess.streak,
    };
  }

  const stepMult = hiloFairStepMult(prev.rank, direction);
  sess.mult = Math.round(sess.mult * stepMult * 100) / 100;
  sess.streak += 1;
  sess.card = next;
  userRec.games.nfg_hilo = gRec;

  return {
    ok: true,
    ...fields,
    sessionActive: true,
    hiloCorrect: true,
    direction,
    prevCardRank: prev.rank,
    prevCardSuit: prev.suit,
    nextCardRank: next.rank,
    nextCardSuit: next.suit,
    cardRank: next.rank,
    cardSuit: next.suit,
    stepMultiplier: stepMult,
    multiplier: sess.mult,
    streak: sess.streak,
    stake: sess.stake,
    message: `Correct! ×${sess.mult.toFixed(2)} — ${sess.streak} in a row. Cash out or keep going.`,
  };
}

function handleMines(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_mines";
  const fields = baseFields(userRec, gameId, pointStore, user);
  if (!userRec.games) userRec.games = {};
  if (!userRec.games.nfg_mines) userRec.games.nfg_mines = {};
  const gRec = userRec.games.nfg_mines;
  const GRID = 25;

  if (action === "status") {
    const sess = gRec.session;
    return {
      ...fields,
      sessionActive: !!sess,
      minesCount: sess?.minesCount || 3,
      revealed: sess?.revealed || [],
      multiplier: sess?.mult || 1,
      stake: sess?.stake,
      message: sess
        ? `×${(sess.mult || 1).toFixed(2)} — tap tiles or Cash Out`
        : `Pick 3–8 mines. Stake ~${fields.suggestedStake.toLocaleString()} pts.`,
    };
  }

  if (action === "start") {
    if (gRec.session) {
      return { ok: false, reason: "in_progress", message: "Finish or cash out first.", ...fields };
    }
    const stake = clampStake(
      gameId,
      skillOf(userRec, gameId),
      payload.stake,
      pointStore.getBalance(user),
    );
    const debit = debitStake(pointStore, user, stake);
    if (!debit.ok) return { ...debit, ...fields };

    let minesCount = Math.floor(Number(payload.mines) || 3);
    if (![3, 5, 8].includes(minesCount)) minesCount = 3;
    const mines = new Set();
    while (mines.size < minesCount) {
      mines.add(Math.floor(Math.random() * GRID));
    }
    gRec.session = {
      stake,
      minesCount,
      mines: [...mines],
      revealed: [],
      mult: 1,
    };
    userRec.games.nfg_mines = gRec;

    return {
      ok: true,
      ...fields,
      sessionActive: true,
      minesCount,
      revealed: [],
      multiplier: 1,
      stake,
      balance: debit.balance,
      livesRemaining: 1,
      livesTotal: 1,
      message: `${stake.toLocaleString()} pts staked — tap tiles to reveal gems`,
    };
  }

  if (action === "cashout") {
    const sess = gRec.session;
    if (!sess) {
      return { ok: false, reason: "not_started", message: "Start a round first.", ...fields };
    }
    const stake = sess.stake;
    const payout = applyArcadeEdge(Math.floor(stake * (sess.mult || 1)));
    gRec.session = null;
    userRec.games.nfg_mines = gRec;
    const res = outcome(pointStore, user, userRec, {
      stake,
      payout,
      won: payout > stake,
      gameId,
    });
    return {
      ...res,
      ...fields,
      sessionActive: false,
      cleared: true,
      multiplier: sess.mult,
      revealed: sess.revealed,
      minePositions: [...sess.mines],
      livesRemaining: 0,
      livesTotal: 1,
    };
  }

  if (action !== "reveal") {
    return { ok: false, reason: "invalid_action", message: "Unknown action." };
  }

  const sess = gRec.session;
  if (!sess) {
    return { ok: false, reason: "not_started", message: "Start a round first.", ...fields };
  }

  const idx = Math.floor(Number(payload.index));
  if (idx < 0 || idx >= GRID || sess.revealed.includes(idx)) {
    return { ok: false, reason: "invalid_cell", message: "Pick an unrevealed tile.", ...fields };
  }

  if (sess.mines.includes(idx)) {
    const stake = sess.stake;
    const safeRevealed = [...sess.revealed];
    gRec.session = null;
    userRec.games.nfg_mines = gRec;
    return {
      ...outcome(pointStore, user, userRec, { stake, payout: 0, won: false, gameId }),
      ...fields,
      sessionActive: false,
      bust: true,
      mineHit: true,
      mineHitIndex: idx,
      revealed: safeRevealed,
      minePositions: [...sess.mines],
      livesRemaining: 0,
      livesTotal: 1,
      minesCount: sess.minesCount,
      multiplier: sess.mult,
    };
  }

  sess.revealed.push(idx);
  const safeLeft = GRID - sess.minesCount - sess.revealed.length;
  sess.mult = Math.round((sess.mult + 0.12 + safeLeft * 0.008) * 100) / 100;
  userRec.games.nfg_mines = gRec;

  const autoCash =
    sess.revealed.length >= GRID - sess.minesCount;
  if (autoCash) {
    const stake = sess.stake;
    const payout = applyArcadeEdge(Math.floor(stake * sess.mult));
    gRec.session = null;
    userRec.games.nfg_mines = gRec;
    const res = outcome(pointStore, user, userRec, {
      stake,
      payout,
      won: true,
      gameId,
    });
    return {
      ...res,
      ...fields,
      sessionActive: false,
      cleared: true,
      multiplier: sess.mult,
      revealed: sess.revealed,
      minePositions: [...sess.mines],
      livesRemaining: 0,
      livesTotal: 1,
    };
  }

  return {
    ok: true,
    ...fields,
    sessionActive: true,
    minesCount: sess.minesCount,
    revealed: sess.revealed,
    multiplier: sess.mult,
    stake: sess.stake,
    livesRemaining: 1,
    livesTotal: 1,
    message: `×${sess.mult.toFixed(2)} — ${safeLeft} safe tiles left`,
  };
}

function handlePlinko(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_plinko";
  const fields = baseFields(userRec, gameId, pointStore, user);

  if (action === "status") {
    return { ...fields, message: "Low / Med / High risk — one drop per stake." };
  }

  if (action !== "play") {
    return { ok: false, reason: "invalid_action", message: "Use play." };
  }

  const stake = clampStake(
    gameId,
    skillOf(userRec, gameId),
    payload.stake,
    pointStore.getBalance(user),
  );
  const debit = debitStake(pointStore, user, stake);
  if (!debit.ok) return { ...debit, ...fields };

  const riskRaw = String(payload.risk || "med").toLowerCase();
  const risk = ["low", "high"].includes(riskRaw) ? riskRaw : "med";
  const bucket = pickPlinkoBucket(risk);
  const mult = PLINKO_BUCKETS[risk][bucket];
  const payout = applyArcadeEdge(Math.floor(stake * mult));
  const won = payout > stake;

  const res = outcome(pointStore, user, userRec, { stake, payout, won, gameId });
  return {
    ...res,
    ...fields,
    segmentIndex: bucket,
    multiplier: mult,
    direction: risk,
    message: `${risk.toUpperCase()} → ×${mult} → ${payout.toLocaleString()} pts`,
  };
}

function handleWheel(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_wheel";
  const fields = baseFields(userRec, gameId, pointStore, user);

  if (action === "status") {
    const totalW = WHEEL_SEGMENTS.reduce((s, x) => s + x.weight, 0);
    return {
      ...fields,
      segments: WHEEL_SEGMENTS.map((s) => s.label),
      message: "High multipliers are rare — LOSE is most likely.",
      wheelOdds: WHEEL_SEGMENTS.map((s) => ({
        label: s.label,
        mult: s.mult,
        weight: s.weight,
        chancePct: Math.round((s.weight / totalW) * 1000) / 10,
      })),
    };
  }

  if (action !== "spin") {
    return { ok: false, reason: "invalid_action", message: "Use spin." };
  }

  const stake = clampStake(
    gameId,
    skillOf(userRec, gameId),
    payload.stake,
    pointStore.getBalance(user),
  );
  const debit = debitStake(pointStore, user, stake);
  if (!debit.ok) return { ...debit, ...fields };

  const picked = pickWheelSegment();
  const seg = picked.seg;
  const grossPayout =
    seg.mult === 0 ? 0 : applyArcadeEdge(Math.floor(stake * seg.mult));
  const segmentIndex = picked.index;

  let res;
  if (grossPayout === 0) {
    res = outcome(pointStore, user, userRec, { stake, payout: 0, won: false, gameId });
  } else if (grossPayout >= stake) {
    res = outcome(pointStore, user, userRec, { stake, payout: grossPayout, won: true, gameId });
  } else {
    const credited = creditWin(pointStore, user, grossPayout);
    recordRound(userRec, false, stake - grossPayout);
    bumpSkill(userRec, gameId, false);
    const lost = stake - grossPayout;
    res = {
      ok: true,
      won: false,
      stake,
      gained: credited,
      grossPayout,
      tax: 0,
      lost,
      net: credited - stake,
      balance: pointStore.getBalance(user),
      message: `Half back — recovered ${credited.toLocaleString()} of ${stake.toLocaleString()} pts`,
    };
  }

  return {
    ...res,
    ...fields,
    prize: grossPayout,
    segmentIndex,
    segmentLabel: seg.label,
    multiplier: seg.mult,
    message:
      seg.mult === 0
        ? `LOSE — ${stake.toLocaleString()} pts`
        : res.message,
  };
}

// ========== Dragon Tower RPG ==========

const TOWER_MONSTERS = [
  { id: "dice_goblin", name: "Pip the Dice Goblin", emoji: "🎲", theme: "dice" },
  { id: "chip_slime", name: "Copper Chip Slime", emoji: "🪙", theme: "money" },
  { id: "ace_shade", name: "Ace of Spades Shade", emoji: "♠️", theme: "cards" },
  { id: "roulette_wraith", name: "Roulette Wraith", emoji: "🎡", theme: "roulette" },
  { id: "slot_mimic", name: "One-Armed Slot Mimic", emoji: "🎰", theme: "slots" },
  { id: "diamond_drake", name: "Diamond Suit Drake", emoji: "♦️", theme: "cards" },
  { id: "coin_golem", name: "Gold Coin Golem", emoji: "💰", theme: "money" },
  { id: "craps_hound", name: "Snake-Eyes Hound", emoji: "🐍", theme: "dice" },
];

const TOWER_BOSSES = [
  { id: "high_roller", name: "High Roller Titan", emoji: "👑", theme: "money" },
  { id: "house_dragon", name: "House Edge Dragon", emoji: "🐉", theme: "boss" },
  { id: "jackpot_hydra", name: "Jackpot Hydra", emoji: "💎", theme: "slots" },
  { id: "void_dealer", name: "Void Dealer", emoji: "🃏", theme: "cards" },
  { id: "roulette_colossus", name: "Roulette Colossus", emoji: "🎡", theme: "roulette" },
  { id: "ace_overlord", name: "Ace Overlord", emoji: "♠️", theme: "cards" },
  { id: "fortune_leviathan", name: "Fortune Leviathan", emoji: "🐲", theme: "boss" },
  { id: "chip_behemoth", name: "Chip Behemoth", emoji: "🪙", theme: "money" },
];

// Higher floor bands give bosses a tougher epithet + enhanced look (client uses `tier`).
const TOWER_BOSS_EPITHETS = [
  "", "Greater ", "Elder ", "Ancient ", "Mythic ",
  "Astral ", "Cosmic ", "Eternal ", "Omega ", "Apex ",
];

function defaultTowerAppearance() {
  return {
    created: false,
    bodyStyle: "male",
    skinTone: 2,
    hairStyle: 1,
    hairColor: 3,
    beard: false,
    heroName: "",
  };
}

function normalizeTowerAppearance(raw) {
  const a = raw && typeof raw === "object" ? raw : {};
  const bodyStyle = a.bodyStyle === "female" ? "female" : "male";
  return {
    created: !!a.created,
    bodyStyle,
    skinTone: Math.max(0, Math.min(5, Math.floor(Number(a.skinTone) || 2))),
    hairStyle: Math.max(0, Math.min(4, Math.floor(Number(a.hairStyle) || 1))),
    hairColor: Math.max(0, Math.min(5, Math.floor(Number(a.hairColor) || 3))),
    beard: bodyStyle === "male" && !!a.beard,
    heroName: String(a.heroName || "").trim().slice(0, 16),
  };
}

function defaultTowerHero() {
  const equipment = defaultTowerEquipment();
  return {
    level: 1,
    xp: 0,
    gold: 25,
    equipment,
    weaponId: equipment.weapon,
    armorId: equipment.body,
    potions: 2,
    bestFloor: 0,
    ownedGear: Object.values(equipment),
    ownedWeapons: [equipment.weapon],
    ownedArmors: [equipment.body],
    appearance: defaultTowerAppearance(),
  };
}

function ensureTowerHero(gRec) {
  if (!gRec.hero || typeof gRec.hero !== "object") {
    gRec.hero = defaultTowerHero();
  }
  migrateTowerHeroGear(gRec.hero);
  if (gRec.session?.traps) gRec.session = null;
  gRec.hero.appearance = normalizeTowerAppearance(gRec.hero.appearance || defaultTowerAppearance());
  return gRec.hero;
}

function towerXpToNext(level) {
  return 50 + Math.max(0, level - 1) * 40;
}

function getTowerWeapon(id) {
  const g = getTowerGear(id);
  return g.slot === "weapon" ? g : getTowerGear(defaultTowerEquipment().weapon);
}

function getTowerArmor(id) {
  const g = getTowerGear(id);
  return g.slot === "body" ? g : getTowerGear(defaultTowerEquipment().body);
}

function towerHeroStats(hero) {
  migrateTowerHeroGear(hero);
  const stats = towerHeroStatsFromGear(hero);
  const weapon = getTowerGear(hero.equipment.weapon);
  const body = getTowerGear(hero.equipment.body);
  return { ...stats, weapon, armor: body };
}

function spawnTowerMonster(floor) {
  const f = Math.max(1, Math.floor(Number(floor) || 1));
  const isBoss = f % 10 === 0;
  const pool = isBoss ? TOWER_BOSSES : TOWER_MONSTERS;
  const base = pool[(isBoss ? Math.floor(f / 10) - 1 : f - 1) % pool.length];
  // Visual/difficulty rank that grows every ~30 floors (0..9).
  const tier = Math.min(9, Math.floor(f / 30));
  const scale = isBoss ? 2.8 : 1;
  // Mild quadratic term so deeper floors get progressively harder.
  const hp = Math.floor((35 + f * 12 + f * f * 0.08) * scale);
  const atk = Math.floor((4 + f * 1.7) * (isBoss ? 1.5 : 1));
  const def = Math.floor((1 + f * 0.55) * (isBoss ? 1.35 : 1));
  const name = isBoss ? `${TOWER_BOSS_EPITHETS[tier] || ""}${base.name}` : base.name;
  return {
    id: base.id,
    name,
    emoji: base.emoji,
    theme: base.theme,
    hp,
    maxHp: hp,
    atk,
    def,
    floor: f,
    isBoss,
    tier,
  };
}

function towerGrantXp(hero, amount) {
  const gained = Math.max(0, Math.floor(Number(amount) || 0));
  hero.xp = Math.max(0, Math.floor(Number(hero.xp) || 0)) + gained;
  const levelUps = [];
  while (hero.xp >= towerXpToNext(hero.level)) {
    hero.xp -= towerXpToNext(hero.level);
    hero.level = Math.max(1, Math.floor(Number(hero.level) || 1)) + 1;
    levelUps.push(hero.level);
  }
  return { xpGained: gained, levelUps };
}

function towerRollDamage(atk, def, spread) {
  const raw = Math.max(1, Math.floor(Number(atk) || 1) - Math.floor(Number(def) || 0) * 0.45);
  return Math.max(1, raw + Math.floor(Math.random() * (spread * 2 + 1)) - spread);
}

function towerPushLog(session, line) {
  if (!session.log) session.log = [];
  session.log.push(String(line));
  if (session.log.length > 12) session.log = session.log.slice(-12);
}

function towerPayload(hero, session, stats, extra = {}) {
  migrateTowerHeroGear(hero);
  const visuals = towerHeroVisuals(hero.equipment);
  const weapon = getTowerGear(hero.equipment.weapon);
  const body = getTowerGear(hero.equipment.body);
  const monster = session?.monster || null;
  const shopCatalog = towerShopForLevel(hero.level);
  const shopBySlot = towerShopBySlot(hero.level);
  return {
    sessionActive: !!session,
    runActive: !!session,
    tower: {
      needsCreation: !hero.appearance?.created,
      hero: {
        level: hero.level,
        xp: hero.xp,
        xpToNext: towerXpToNext(hero.level),
        gold: hero.gold,
        potions: hero.potions,
        bestFloor: hero.bestFloor || 0,
        equipment: { ...hero.equipment },
        visuals,
        weaponId: hero.equipment.weapon,
        weaponName: weapon.name,
        weaponAtk: weapon.atk || 0,
        weaponVisual: visuals.weapon,
        armorId: hero.equipment.body,
        armorName: body.name,
        armorDef: body.def || 0,
        armorVisual: visuals.body,
        maxHp: stats.maxHp,
        atk: stats.atk,
        def: stats.def,
        ownedGear: [...(hero.ownedGear || [])],
        ownedWeapons: [...(hero.ownedWeapons || [])],
        ownedArmors: [...(hero.ownedArmors || [])],
        appearance: normalizeTowerAppearance(hero.appearance),
      },
      shop: {
        gear: shopCatalog,
        bySlot: shopBySlot,
        weapons: shopBySlot.weapon,
        armors: shopBySlot.body,
        consumables: TOWER_CONSUMABLES,
      },
      combat: session
        ? {
            floor: session.floor,
            playerHp: session.playerHp,
            turn: session.turn,
            defending: !!session.defending,
            monster,
            log: (session.log || []).slice(-8),
            lastEvent: session.lastEvent || null,
          }
        : null,
    },
    level: session?.floor || hero.bestFloor || 0,
    streak: session?.floor || 0,
    livesRemaining: session?.playerHp ?? stats.maxHp,
    livesTotal: stats.maxHp,
    opponentScore: monster?.hp,
    score: monster?.maxHp,
    ...extra,
  };
}

function towerMonsterTurn(session, stats) {
  const m = session.monster;
  let dmg = towerRollDamage(m.atk, stats.def, 2);
  if (session.defending) {
    dmg = Math.max(1, Math.floor(dmg * 0.45));
    session.defending = false;
    towerPushLog(session, `${m.emoji} ${m.name} strikes — you block! ${dmg} dmg`);
  } else {
    towerPushLog(session, `${m.emoji} ${m.name} hits you for ${dmg}!`);
  }
  session.playerHp = Math.max(0, session.playerHp - dmg);
  session.turn = "player";
  return dmg;
}

function towerAdvanceFloor(session, hero) {
  const next = session.floor + 1;
  session.floor = next;
  session.monster = spawnTowerMonster(next);
  session.defending = false;
  session.turn = "player";
  const m = session.monster;
  const bossTag = m.isBoss ? " ⚔️ BOSS" : "";
  towerPushLog(session, `— Floor ${next}${bossTag}: ${m.emoji} ${m.name} —`);
}

function handleTower(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_tower";
  const fields = baseFields(userRec, gameId, pointStore, user);
  if (!userRec.games) userRec.games = {};
  if (!userRec.games.nfg_tower) userRec.games.nfg_tower = {};
  const gRec = userRec.games.nfg_tower;
  const hero = ensureTowerHero(gRec);
  const stats = towerHeroStats(hero);
  const act = String(action || "status").toLowerCase();

  if (act === "status") {
    return {
      ...fields,
      ...towerPayload(hero, gRec.session, stats),
      message: gRec.session
        ? `Floor ${gRec.session.floor} — ${gRec.session.monster?.emoji || ""} ${gRec.session.monster?.name || "Monster"}`
        : "Dragon Tower RPG — Enter the tower, battle casino monsters, upgrade gear between runs.",
    };
  }

  if (act === "customize") {
    if (gRec.session) {
      return {
        ok: false,
        reason: "in_combat",
        message: "Finish your run before changing appearance.",
        ...fields,
        ...towerPayload(hero, gRec.session, stats),
      };
    }
    const next = normalizeTowerAppearance({
      ...hero.appearance,
      bodyStyle: payload.bodyStyle ?? hero.appearance?.bodyStyle,
      skinTone: payload.skinTone ?? hero.appearance?.skinTone,
      hairStyle: payload.hairStyle ?? hero.appearance?.hairStyle,
      hairColor: payload.hairColor ?? hero.appearance?.hairColor,
      beard: payload.beard ?? hero.appearance?.beard,
      heroName: payload.heroName ?? hero.appearance?.heroName,
      created: payload.finalize === true ? true : !!hero.appearance?.created,
    });
    hero.appearance = next;
    userRec.games.nfg_tower = gRec;
    return {
      ok: true,
      ...fields,
      ...towerPayload(hero, null, towerHeroStats(hero)),
      message: next.created
        ? `Welcome, ${next.heroName || "Adventurer"}! Your hero is ready.`
        : "Preview updated.",
    };
  }

  if (act === "enter" || act === "start") {
    if (!hero.appearance?.created) {
      return {
        ok: false,
        reason: "needs_creation",
        message: "Create your hero first — customize body, hair, and name.",
        ...fields,
        ...towerPayload(hero, gRec.session, stats),
      };
    }
    if (gRec.session) {
      return {
        ok: false,
        reason: "in_progress",
        message: "A run is already in progress — fight, flee, or finish first.",
        ...fields,
        ...towerPayload(hero, gRec.session, stats),
      };
    }
    const monster = spawnTowerMonster(1);
    gRec.session = {
      floor: 1,
      monster,
      playerHp: stats.maxHp,
      turn: "player",
      defending: false,
      log: [`You enter the Dragon Tower…`, `Floor 1 — ${monster.emoji} ${monster.name} awaits!`],
    };
    userRec.games.nfg_tower = gRec;
    return {
      ok: true,
      ...fields,
      ...towerPayload(hero, gRec.session, stats),
      message: "Run started! Attack to gain XP — you level up even without kills.",
    };
  }

  if (act === "flee") {
    if (!gRec.session) {
      return { ok: false, reason: "not_started", message: "No active run.", ...fields, ...towerPayload(hero, null, stats) };
    }
    const floor = gRec.session.floor;
    gRec.session = null;
    userRec.games.nfg_tower = gRec;
    return {
      ok: true,
      ...fields,
      ...towerPayload(hero, null, stats),
      cleared: true,
      message: `You fled from floor ${floor}. Hero progress saved.`,
    };
  }

  if (act === "buy") {
    if (gRec.session) {
      return {
        ok: false,
        reason: "in_combat",
        message: "Flee or finish your run before shopping.",
        ...fields,
        ...towerPayload(hero, gRec.session, stats),
      };
    }
    const itemId = String(payload.itemId || payload.id || "").trim();

    // Consumables (potions) — bought with gold, add to potion stock.
    const consumable = getTowerConsumable(itemId);
    if (consumable) {
      if ((hero.gold || 0) < consumable.cost) {
        return { ok: false, reason: "insufficient_gold", message: `Need ${consumable.cost} tower gold (have ${hero.gold || 0}).`, ...fields, ...towerPayload(hero, null, stats) };
      }
      hero.gold -= consumable.cost;
      hero.potions = Math.max(0, Math.floor(Number(hero.potions) || 0)) + (consumable.potions || 0);
      userRec.games.nfg_tower = gRec;
      return {
        ok: true,
        ...fields,
        ...towerPayload(hero, null, towerHeroStats(hero)),
        message: `Bought ${consumable.name} (+${consumable.potions} potion${consumable.potions === 1 ? "" : "s"}).`,
      };
    }

    const item = getTowerGear(itemId);
    if (!item || !TOWER_GEAR.some((g) => g.id === itemId)) {
      return { ok: false, reason: "invalid_item", message: "Unknown item.", ...fields, ...towerPayload(hero, null, stats) };
    }
    const slot = item.slot;
    if ((hero.level || 1) < (item.minLevel || 1)) {
      return {
        ok: false,
        reason: "level_locked",
        message: `Requires tower level ${item.minLevel}.`,
        ...fields,
        ...towerPayload(hero, null, stats),
      };
    }
    if ((hero.ownedGear || []).includes(itemId)) {
      return { ok: false, reason: "already_owned", message: "You already own that.", ...fields, ...towerPayload(hero, null, stats) };
    }
    if ((hero.gold || 0) < item.cost) {
      return { ok: false, reason: "insufficient_gold", message: `Need ${item.cost} tower gold (have ${hero.gold || 0}).`, ...fields, ...towerPayload(hero, null, stats) };
    }
    hero.gold -= item.cost;
    if (!Array.isArray(hero.ownedGear)) hero.ownedGear = [];
    hero.ownedGear.push(itemId);
    hero.equipment[slot] = itemId;
    migrateTowerHeroGear(hero);
    userRec.games.nfg_tower = gRec;
    const newStats = towerHeroStats(hero);
    return {
      ok: true,
      ...fields,
      ...towerPayload(hero, null, newStats),
      message: `Purchased & equipped ${item.name}!`,
    };
  }

  if (act === "equip") {
    if (gRec.session) {
      return {
        ok: false,
        reason: "in_combat",
        message: "Can't change gear mid-fight.",
        ...fields,
        ...towerPayload(hero, gRec.session, stats),
      };
    }
    const itemId = String(payload.itemId || payload.id || "").trim();
    const kind = String(payload.kind || payload.slot || "").toLowerCase();
    const item = getTowerGear(itemId);
    if (!item || !TOWER_GEAR.some((g) => g.id === itemId)) {
      return { ok: false, reason: "invalid_item", message: "Unknown item.", ...fields, ...towerPayload(hero, null, stats) };
    }
    if (kind && kind !== item.slot && kind !== "armor" && kind !== "weapon") {
      return { ok: false, reason: "slot_mismatch", message: "Item does not fit that slot.", ...fields, ...towerPayload(hero, null, stats) };
    }
    if (!(hero.ownedGear || []).includes(itemId)) {
      return { ok: false, reason: "not_owned", message: "Buy that item first.", ...fields, ...towerPayload(hero, null, stats) };
    }
    hero.equipment[item.slot] = itemId;
    migrateTowerHeroGear(hero);
    userRec.games.nfg_tower = gRec;
    const newStats = towerHeroStats(hero);
    return {
      ok: true,
      ...fields,
      ...towerPayload(hero, null, newStats),
      message: `Equipped ${item.name}.`,
    };
  }

  if (act === "attack" || act === "defend" || act === "potion" || act === "use_potion") {
    const session = gRec.session;
    if (!session) {
      return { ok: false, reason: "not_started", message: "Enter the tower first.", ...fields, ...towerPayload(hero, null, stats) };
    }
    if (session.turn !== "player") {
      return { ok: false, reason: "not_your_turn", message: "Wait for the monster…", ...fields, ...towerPayload(hero, session, stats) };
    }

    const m = session.monster;
    let xpGained = 0;
    let levelUps = [];
    let killed = false;
    let playerDown = false;

    if (act === "defend") {
      session.defending = true;
      xpGained = 3;
      const xpRes = towerGrantXp(hero, xpGained);
      levelUps = xpRes.levelUps;
      towerPushLog(session, "You brace for impact (+3 training XP).");
      const monsterDmg = towerMonsterTurn(session, stats);
      playerDown = session.playerHp <= 0;
      session.lastEvent = {
        kind: "defend",
        xpGained,
        monsterDamage: monsterDmg,
        levelUp: levelUps.length > 0,
        blocked: true,
      };
    } else if (act === "potion" || act === "use_potion") {
      if ((hero.potions || 0) <= 0) {
        return { ok: false, reason: "no_potions", message: "No potions left.", ...fields, ...towerPayload(hero, session, stats) };
      }
      hero.potions -= 1;
      const heal = Math.floor(stats.maxHp * 0.4);
      session.playerHp = Math.min(stats.maxHp, session.playerHp + heal);
      towerPushLog(session, `Potion! +${heal} HP`);
      const monsterDmg = towerMonsterTurn(session, stats);
      playerDown = session.playerHp <= 0;
      session.lastEvent = {
        kind: "potion",
        heal,
        monsterDamage: monsterDmg,
      };
    } else {
      const dmg = towerRollDamage(stats.atk, m.def, 3);
      m.hp = Math.max(0, m.hp - dmg);
      xpGained = 5 + session.floor * 2;
      const xpRes = towerGrantXp(hero, xpGained);
      levelUps = xpRes.levelUps;
      towerPushLog(session, `You hit ${m.emoji} ${m.name} for ${dmg}! (+${xpGained} XP)`);
      let monsterDmg = 0;

      if (m.hp <= 0) {
        killed = true;
        const goldGain = 8 + session.floor * 4 + (m.isBoss ? 40 : 0);
        hero.gold = (hero.gold || 0) + goldGain;
        const killXp = 15 + session.floor * 5 + (m.isBoss ? 25 : 0);
        const killRes = towerGrantXp(hero, killXp);
        levelUps = [...new Set([...levelUps, ...killRes.levelUps])];
        xpGained += killXp;
        if (session.floor > (hero.bestFloor || 0)) hero.bestFloor = session.floor;
        towerPushLog(session, `Victory! +${goldGain} gold, +${killXp} bonus XP.`);

        if (m.isBoss && session.floor >= 10) {
          // 10k at floor 10, scaling ~+54/floor to a 25k cap (~floor 290).
          const bonusPts = Math.min(25000, Math.floor(10000 + (session.floor - 10) * 54));
          pointStore.credit(user, bonusPts, { countAsEarned: true });
          towerPushLog(session, `Boss bonus: ${bonusPts.toLocaleString()} pts credited!`);
        }

        if (levelUps.length) {
          towerPushLog(session, `LEVEL UP! Now level ${hero.level}!`);
        }
        towerAdvanceFloor(session, hero);
        const freshStats = towerHeroStats(hero);
        session.playerHp = levelUps.length
          ? freshStats.maxHp
          : Math.min(freshStats.maxHp, session.playerHp + Math.floor(freshStats.maxHp * 0.15));
        session.lastEvent = {
          kind: "kill",
          playerDamage: dmg,
          xpGained,
          killed: true,
          levelUp: levelUps.length > 0,
        };
      } else {
        monsterDmg = towerMonsterTurn(session, stats);
        playerDown = session.playerHp <= 0;
        if (levelUps.length) {
          towerPushLog(session, `LEVEL UP! Now level ${hero.level}!`);
          session.playerHp = Math.min(towerHeroStats(hero).maxHp, session.playerHp + Math.floor(towerHeroStats(hero).maxHp * 0.25));
        }
        session.lastEvent = {
          kind: "attack",
          playerDamage: dmg,
          monsterDamage: monsterDmg,
          xpGained,
          levelUp: levelUps.length > 0,
        };
      }
    }

    if (playerDown) {
      const reached = session.floor;
      if (reached > (hero.bestFloor || 0)) hero.bestFloor = reached;
      gRec.session = null;
      userRec.games.nfg_tower = gRec;
      bumpSkill(userRec, gameId, false);
      return {
        ok: true,
        ...fields,
        ...towerPayload(hero, null, towerHeroStats(hero)),
        bust: true,
        sessionActive: false,
        funPoints: xpGained,
        message: `Defeated on floor ${reached}. Keep attacking next run — XP always sticks!`,
      };
    }

    userRec.games.nfg_tower = gRec;
    const liveStats = towerHeroStats(hero);
    if (killed) bumpSkill(userRec, gameId, true);

    return {
      ok: true,
      ...fields,
      ...towerPayload(hero, gRec.session, liveStats),
      funPoints: xpGained,
      win: killed,
      cleared: killed && m.isBoss,
      message: killed
        ? `Floor cleared! Now fighting ${session.monster?.emoji || ""} ${session.monster?.name || "next foe"}`
        : `${m.emoji} ${m.name} — ${m.hp}/${m.maxHp} HP (+${xpGained} XP)`,
    };
  }

  if (act === "climb" || act === "cashout") {
    return {
      ok: false,
      reason: "invalid_action",
      message: "Dragon Tower is now turn-based RPG — use enter, attack, defend, potion, flee, buy.",
      ...fields,
      ...towerPayload(hero, gRec.session, stats),
    };
  }

  return {
    ok: false,
    reason: "invalid_action",
    message: "Use enter, attack, defend, potion, flee, buy, equip, or customize.",
    ...fields,
    ...towerPayload(hero, gRec.session, stats),
  };
}

// ========== NFG Blocks (Block Blast puzzle) ==========

const BLOCKBLAST_BASE_CAP = 5000;
const BLOCKBLAST_LEVEL_BONUS = 450;
const BLOCKBLAST_SESSION_STEP = 0.1;
const BLOCKBLAST_MAX_CAP = 25000;

function blockBlastLinesTarget(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  return 6 + (lv - 1) * 2;
}

function blockBlastReward(level, sessionLevelsCompleted) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  const clears = Math.max(1, Math.floor(Number(sessionLevelsCompleted) || 1));
  const base = Math.min(BLOCKBLAST_BASE_CAP + (lv - 1) * BLOCKBLAST_LEVEL_BONUS, BLOCKBLAST_MAX_CAP);
  const mult = 1 + Math.max(0, clears - 1) * BLOCKBLAST_SESSION_STEP;
  return Math.floor(base * mult);
}

function defaultBlockBlastSession() {
  return {
    active: false,
    level: 1,
    sessionLevels: 0,
    sessionPoints: 0,
  };
}

function blockBlastPayload(gRec) {
  const s = gRec.session || defaultBlockBlastSession();
  const nextClear = (s.sessionLevels || 0) + 1;
  return {
    runActive: !!s.active,
    sessionActive: !!s.active,
    level: s.level || 1,
    sessionLevels: s.sessionLevels || 0,
    sessionPoints: s.sessionPoints || 0,
    score: s.sessionPoints || 0,
    linesTarget: blockBlastLinesTarget(s.level || 1),
    levelRewardPreview: blockBlastReward(s.level || 1, nextClear),
    bestLevel: gRec.bestLevel || 1,
    practiceMode: false,
    unlimited: true,
    stakeMin: 0,
    stakeMax: 0,
    suggestedStake: 0,
  };
}

function handleBlockBlast(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_blocks";
  const fields = baseFields(userRec, gameId, pointStore, user);
  fields.stakeMin = 0;
  fields.stakeMax = 0;
  fields.suggestedStake = 0;
  fields.unlimited = true;

  if (!userRec.games.nfg_blocks) userRec.games.nfg_blocks = {};
  const gRec = userRec.games.nfg_blocks;
  if (!gRec.session) gRec.session = defaultBlockBlastSession();

  const act = String(action || "status").toLowerCase();

  if (act === "status") {
    return {
      ok: true,
      ...fields,
      ...blockBlastPayload(gRec),
      message: "Clear the line target each level. Session streak boosts points (from ~5,000 pts).",
    };
  }

  if (act === "start") {
    gRec.session = {
      active: true,
      level: 1,
      sessionLevels: 0,
      sessionPoints: 0,
    };
    gRec.bestLevel = gRec.bestLevel || 1;
    userRec.games.nfg_blocks = gRec;
    return {
      ok: true,
      ...fields,
      ...blockBlastPayload(gRec),
      message: "Level 1 — clear 6 lines to advance!",
    };
  }

  if (act === "level_clear") {
    if (!gRec.session?.active) {
      return { ok: false, reason: "no_session", message: "Tap New Game first.", ...fields, ...blockBlastPayload(gRec) };
    }
    const level = Math.max(1, Math.floor(Number(gRec.session.level) || 1));
    const sessionLevels = (gRec.session.sessionLevels || 0) + 1;
    const reward = blockBlastReward(level, sessionLevels);
    const gained = creditWin(pointStore, user, reward);

    gRec.session.sessionLevels = sessionLevels;
    gRec.session.sessionPoints = (gRec.session.sessionPoints || 0) + gained;
    gRec.session.level = level + 1;
    gRec.bestLevel = Math.max(gRec.bestLevel || 1, level + 1);
    userRec.games.nfg_blocks = gRec;

    return {
      ok: true,
      ...fields,
      ...blockBlastPayload(gRec),
      gained,
      cleared: true,
      win: true,
      level,
      message: `Level ${level} cleared! +${gained.toLocaleString()} pts (session ${gRec.session.sessionPoints.toLocaleString()} pts)`,
    };
  }

  if (act === "game_over") {
    const sessionPts = gRec.session?.sessionPoints || 0;
    gRec.session = defaultBlockBlastSession();
    userRec.games.nfg_blocks = gRec;
    return {
      ok: true,
      ...fields,
      ...blockBlastPayload(gRec),
      sessionPoints: sessionPts,
      score: sessionPts,
      message:
        sessionPts > 0
          ? `Board full — session total ${sessionPts.toLocaleString()} pts banked`
          : "No moves left — start a new session!",
    };
  }

  return {
    ok: false,
    reason: "invalid_action",
    message: "Use start, level_clear, or game_over.",
    ...fields,
    ...blockBlastPayload(gRec),
  };
}

const HANDLERS = {
  nfg_dice: handleDice,
  nfg_hilo: handleHiLo,
  nfg_limbo: handleHiLo, // legacy id → Hi-Lo (Limbo removed)
  nfg_mines: handleMines,
  nfg_plinko: handlePlinko,
  nfg_wheel: handleWheel,
  nfg_tower: handleTower,
  nfg_coinflip: handleTower, // legacy id → Dragon Tower
  nfg_blocks: handleBlockBlast,
};

function buildCatalog(pointStore, user) {
  const state = loadState();
  const userRec = ensureUser(state, user);
  saveState(state);
  return {
    ok: true,
    earnedToday: 0,
    earnCap: 0,
    earnLeft: 0,
    liveBonusMultiplier: LIVE_WIN_MULT,
    isLive: isLive(),
    funPoints: 0,
    balance: pointStore.getBalance(user),
    games: catalogGames(userRec, pointStore, user),
    missions: buildMissions(userRec),
    season: null,
    riskMode: true,
    message: "Stake arcade — 15s cooldown between staked rounds.",
    stats: userRec.stats,
    ...cooldownFields(userRec),
  };
}

function playGame(pointStore, game, user, gameId, action, payload) {
  const handler = HANDLERS[gameId];
  if (!handler) {
    return { ok: false, reason: "invalid_game", message: "Unknown game." };
  }

  const state = loadState();
  const userRec = ensureUser(state, user);
  if (!userRec) {
    return { ok: false, reason: "invalid_user", message: "Invalid user." };
  }

  if (isStakedAction(action)) {
    const block = cooldownBlock(userRec, pointStore, user, gameId);
    if (block) {
      saveState(state);
      const catalog = buildCatalog(pointStore, user);
      return {
        ...block,
        game: gameId,
        wallet: buildWalletPayload(user, pointStore, game),
        arcade: catalog,
        missions: catalog.missions,
      };
    }
  }

  const result = handler(user, userRec, action, payload || {}, pointStore);

  if (result.ok !== false && isStakedAction(action)) {
    touchArcadeStake(userRec);
  }

  Object.assign(result, cooldownFields(userRec));

  if (result.gained > 0 && isLive() && result.won) {
    userRec.stats.liveWin = 1;
  }

  saveState(state);

  const catalog = buildCatalog(pointStore, user);
  return {
    ...result,
    ok: result.ok !== false,
    game: gameId,
    wallet: buildWalletPayload(user, pointStore, game),
    arcade: catalog,
    missions: catalog.missions,
  };
}

function getPublicTowerHero(user) {
  const u = normUser(user);
  if (!u) return null;
  const state = loadState();
  const userRec = state.users?.[u];
  if (!userRec?.games?.nfg_tower) return null;
  const hero = ensureTowerHero(userRec.games.nfg_tower);
  if (!hero.appearance?.created) return null;
  const visuals = towerHeroVisuals(hero.equipment);
  return {
    heroName: hero.appearance.heroName || u,
    level: Math.max(1, Math.floor(Number(hero.level) || 1)),
    bestFloor: Math.max(0, Math.floor(Number(hero.bestFloor) || 0)),
    appearance: normalizeTowerAppearance(hero.appearance),
    equipment: { ...hero.equipment },
    visuals,
    weaponVisual: visuals.weapon,
    armorVisual: visuals.body,
  };
}

function registerMobileArcadeRoutes(app, ctx) {
  const { validateBearer, pointStore, game } = ctx;

  app.get("/api/mobile/arcade/catalog", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });
    try {
      return res.json(buildCatalog(pointStore, session.userId));
    } catch (e) {
      return res.status(500).json({ ok: false, message: e.message || "arcade_error" });
    }
  });

  app.post("/api/mobile/arcade/play", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    const body = req.body && typeof req.body === "object" ? req.body : {};
    const gameId = String(body.gameId || "").trim();
    const action = String(body.action || "status").trim();
    const payload = body.payload && typeof body.payload === "object" ? body.payload : {};

    if (!gameId) {
      return res.status(400).json({ ok: false, reason: "invalid_game", message: "Missing gameId." });
    }

    try {
      const result = playGame(pointStore, game, session.userId, gameId, action, payload);
      const status = result.ok === false ? 400 : 200;
      return res.status(status).json(result);
    } catch (e) {
      return res.status(500).json({ ok: false, message: e.message || "arcade_error" });
    }
  });
}

module.exports = { registerMobileArcadeRoutes, buildCatalog, playGame, GAME_DEFS, getPublicTowerHero };
