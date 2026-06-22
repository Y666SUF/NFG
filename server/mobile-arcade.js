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
/** Skill games with no stake — never apply arcade round cooldown. */
const ARCADE_NO_COOLDOWN_GAMES = new Set(["nfg_blocks", "nfg_snake_jump", "nfg_vault_run"]);

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
    helpText: "Level your hero, upgrade gear, and fight vault-themed monsters floor by floor. Boss every 10 levels.",
  },
  {
    id: "nfg_blocks",
    title: "NFG Blocks",
    subtitle: "Block puzzle — clear lines for points",
    icon: "🧱",
    helpText:
      "Place blocks on the 8×8 grid. Clear enough lines per level. Earn rate matches NFG Jump (~1k pts/min at level 1); higher levels pay more per line. Session streak +10% per level cleared.",
  },
  {
    id: "nfg_snake_jump",
    title: "NFG Jump",
    subtitle: "Play on your phone — milestone rewards sync here",
    icon: "⬆️",
    helpText:
      "Bounce higher on platforms. Green = safe, yellow = one jump only, blue = moves, red = deadly. +3,000 pts every 2,500m. Your best height is saved across runs.",
  },
  {
    id: "nfg_vault_run",
    title: "NFG Rush",
    subtitle: "3-lane space run — milestone pts",
    icon: "🚀",
    helpText:
      "3-lane space flight. Swipe lanes, boost over orange debris, shrink through purple rock tunnels, dodge red asteroids. Milestones every 400m — 3,000 pts scaling up. Ship shop in-game.",
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
  nfg_snake_jump: 0,
  nfg_vault_run: 0,
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
  let state = { users: {} };
  try {
    if (fs.existsSync(DATA_FILE)) {
      const parsed = JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
      if (parsed && typeof parsed === "object") {
        state = parsed;
        if (!state.users || typeof state.users !== "object") state.users = {};
      }
    }
  } catch (_) {
    /* ignore */
  }
  ensureLeaderboards(state);
  return state;
}

function saveState(state) {
  const dir = path.dirname(DATA_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  ensureLeaderboards(state);
  fs.writeFileSync(DATA_FILE, JSON.stringify(state, null, 2));
}

const LEADERBOARD_GAME_IDS = new Set(["nfg_blocks", "nfg_snake_jump", "nfg_vault_run"]);
const LEADERBOARD_MAX = 50;

function ensureLeaderboards(state) {
  if (!state.leaderboards || typeof state.leaderboards !== "object") {
    state.leaderboards = {};
  }
  for (const gameId of LEADERBOARD_GAME_IDS) {
    if (!Array.isArray(state.leaderboards[gameId])) {
      state.leaderboards[gameId] = [];
    }
  }
  return state.leaderboards;
}

function arcadeDisplayName(userId, pointStore) {
  const u = normUser(userId);
  if (!u) return "Player";
  if (pointStore?.getUserPresentation) {
    const p = pointStore.getUserPresentation(u);
    const name = String(p?.displayName || "").trim();
    if (name) return name.slice(0, 40);
  }
  if (pointStore && typeof pointStore.getDisplayName === "function") {
    const dn = String(pointStore.getDisplayName(u) || "").trim();
    if (dn) return dn.slice(0, 40);
  }
  return u;
}

function userRecBest(userRec, gameId) {
  if (!userRec?.games) return 0;
  if (gameId === "nfg_blocks") {
    return Math.floor(Number(userRec.games.nfg_blocks?.bestLevel) || 0);
  }
  if (gameId === "nfg_snake_jump") {
    return Math.floor(Number(userRec.games.nfg_snake_jump?.bestHeight) || 0);
  }
  if (gameId === "nfg_vault_run") {
    return Math.floor(Number(userRec.games.nfg_vault_run?.bestDistance) || 0);
  }
  return 0;
}

function recordArcadeLeaderboard(state, gameId, userId, score, pointStore) {
  if (!LEADERBOARD_GAME_IDS.has(gameId)) return;
  const u = normUser(userId);
  const pts = Math.floor(Number(score) || 0);
  if (!u || pts <= 0) return;
  const boards = ensureLeaderboards(state);
  const rows = boards[gameId];
  const existing = rows.find((r) => normUser(r.userId) === u);
  if (existing) {
    if (pts <= Math.floor(Number(existing.points) || 0)) return;
    existing.points = pts;
    existing.displayName = arcadeDisplayName(u, pointStore);
    existing.updatedAt = Date.now();
  } else {
    rows.push({
      userId: u,
      displayName: arcadeDisplayName(u, pointStore),
      points: pts,
      updatedAt: Date.now(),
    });
  }
  rows.sort((a, b) => (Number(b.points) || 0) - (Number(a.points) || 0));
  boards[gameId] = rows.slice(0, LEADERBOARD_MAX);
}

function getArcadeLeaderboard(state, gameId, userId, pointStore) {
  const boards = ensureLeaderboards(state);
  const rows = boards[gameId] || [];
  const scoreLabel =
    gameId === "nfg_blocks"
      ? "Best level"
      : gameId === "nfg_vault_run"
        ? "Best distance"
        : "Best height";
  const top = rows.map((r) => {
    const base = {
      userId: r.userId,
      displayName: r.displayName || arcadeDisplayName(r.userId, pointStore),
      points: Math.floor(Number(r.points) || 0),
    };
    if (gameId === "nfg_snake_jump" && r.jumpSkinId) {
      return {
        ...base,
        jumpSkinId: r.jumpSkinId,
        jumpSkinName: r.jumpSkinName || null,
        jumpSkinFill: r.jumpSkinFill,
        jumpSkinRing: r.jumpSkinRing,
      };
    }
    return base;
  });
  const u = normUser(userId);
  let myRank = null;
  let myScore = 0;
  if (u) {
    const idx = rows.findIndex((r) => normUser(r.userId) === u);
    if (idx >= 0) {
      myRank = idx + 1;
      myScore = Math.floor(Number(rows[idx].points) || 0);
    } else {
      myScore = userRecBest(state.users?.[u], gameId);
    }
  }
  return { ok: true, gameId, top, myRank, myScore, scoreLabel };
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
      claimedMissions: [],
    };
  }
  const dayKey = ukDayKey();
  if (state.users[u].dayKey !== dayKey) {
    state.users[u].dayKey = dayKey;
    state.users[u].stats = { rounds: 0, wins: 0, lost: 0 };
    state.users[u].claimedMissions = [];
  }
  if (!Array.isArray(state.users[u].claimedMissions)) state.users[u].claimedMissions = [];
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

function isNoCooldownGame(gameId) {
  return ARCADE_NO_COOLDOWN_GAMES.has(String(gameId || "").trim());
}

function isStakedAction(action, gameId) {
  if (isNoCooldownGame(gameId)) return false;
  const a = String(action || "").toLowerCase();
  return a === "play" || a === "spin" || a === "start";
}

function arcadeCooldownFields(userRec, gameId, now = Date.now()) {
  if (isNoCooldownGame(gameId)) {
    return { cooldownSecondsLeft: 0, arcadeCooldownActive: false };
  }
  return cooldownFields(userRec, now);
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
  const cd = arcadeCooldownFields(userRec, gameId);
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
    ...arcadeCooldownFields(userRec, gameId),
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

const MISSION_DEFS = [
  { id: "win_5", title: "Win 5 arcade rounds today", goal: 5, reward: 2000, stat: "wins" },
  { id: "play_10", title: "Play 10 staked rounds today", goal: 10, reward: 1500, stat: "rounds" },
  { id: "live_win", title: "Win a round while LIVE", goal: 1, reward: 3000, stat: "liveWin" },
];

function buildMissions(userRec) {
  const s = userRec.stats || {};
  const claimed = Array.isArray(userRec.claimedMissions) ? userRec.claimedMissions : [];
  return MISSION_DEFS.map((def) => {
    const progress = s[def.stat] || 0;
    return {
      id: def.id,
      title: def.title,
      goal: def.goal,
      reward: def.reward,
      progress,
      done: progress >= def.goal,
      claimed: claimed.includes(def.id),
    };
  });
}

function claimMission(pointStore, game, user, missionId) {
  const state = loadState();
  const userRec = ensureUser(state, user);
  if (!userRec) return { ok: false, reason: "invalid_user", message: "Invalid user." };

  const id = String(missionId || "").trim();
  const def = MISSION_DEFS.find((m) => m.id === id);
  if (!def) return { ok: false, reason: "invalid_mission", message: "Unknown mission." };

  if (!Array.isArray(userRec.claimedMissions)) userRec.claimedMissions = [];
  const progress = (userRec.stats || {})[def.stat] || 0;
  if (progress < def.goal) {
    return { ok: false, reason: "not_done", message: "Mission not complete yet." };
  }
  if (userRec.claimedMissions.includes(id)) {
    return { ok: false, reason: "already_claimed", message: "Reward already claimed." };
  }

  userRec.claimedMissions.push(id);
  pointStore.credit(user, def.reward, { countAsEarned: true });
  saveState(state);

  const catalog = buildCatalog(pointStore, user);
  return {
    ok: true,
    claimed: id,
    reward: def.reward,
    message: `Claimed ${def.reward.toLocaleString()} pts!`,
    arcade: catalog,
    missions: catalog.missions,
    wallet: buildWalletPayload(user, pointStore, game),
  };
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
  const segmentIndex = picked.index;
  const seg = WHEEL_SEGMENTS[segmentIndex] || picked.seg;
  const grossPayout =
    seg.mult === 0 ? 0 : applyArcadeEdge(Math.floor(stake * seg.mult));

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
        : "Dragon Tower RPG — Enter the tower, battle vault monsters, upgrade gear between runs.",
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
// Payouts are time-aligned to NFG Jump: 3,000 pts / ~2.8 min per 2,500m tier (~1,070 pts/min).
// Blocks uses estimated active seconds per line cleared, then a tier bonus so deep levels beat L1 per line.
/** Keep in sync with SNAKE_JUMP_REWARD and typical skilled time between milestones. */
const BLOCKBLAST_ALIGN_JUMP_REWARD = 3000;
const BLOCKBLAST_ALIGN_JUMP_MINUTES_PER_MILESTONE = 2.8;
const BLOCKBLAST_REFERENCE_PTS_PER_MIN =
  BLOCKBLAST_ALIGN_JUMP_REWARD / BLOCKBLAST_ALIGN_JUMP_MINUTES_PER_MILESTONE;
/** Median seconds of play per line toward the level target (place + clear). */
const BLOCKBLAST_SEC_PER_LINE = 42;
/** Extra vs time baseline — higher levels = more pts/min than grinding L1. */
const BLOCKBLAST_TIER_LINEAR = 0.02;
const BLOCKBLAST_TIER_CURVE = 0.003;
const BLOCKBLAST_SESSION_STEP = 0.1;
const BLOCKBLAST_MAX_CAP = 100000;
function blockBlastLinesTarget(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  return 6 + (lv - 1) * 2;
}
function blockBlastExpectedMinutes(level) {
  const lines = blockBlastLinesTarget(level);
  return (lines * BLOCKBLAST_SEC_PER_LINE) / 60;
}
function blockBlastTierMultiplier(level) {
  const n = Math.max(0, Math.floor(Number(level) || 1) - 1);
  return 1 + n * BLOCKBLAST_TIER_LINEAR + BLOCKBLAST_TIER_CURVE * n * n;
}
function blockBlastBase(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  const timeAligned = BLOCKBLAST_REFERENCE_PTS_PER_MIN * blockBlastExpectedMinutes(lv);
  const raw = Math.floor(timeAligned * blockBlastTierMultiplier(lv));
  return Math.min(raw, BLOCKBLAST_MAX_CAP);
}
function blockBlastReward(level, sessionLevelsCompleted) {
  const clears = Math.max(1, Math.floor(Number(sessionLevelsCompleted) || 1));
  const base = blockBlastBase(level);
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
      message:
        "Payouts match NFG Jump time (~1k pts/min at L1). Higher levels pay more per line — streak +10% per level in session.",
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

// ========== Snake Jump (vertical bounce skill game) ==========
const SNAKE_JUMP_MILESTONE_STEP = 2500;
const SNAKE_JUMP_REWARD = 3000;
const SNAKE_JUMP_MAX_MILESTONES = 40;
const SNAKE_JUMP_DEFAULT_SKIN = "classic";
const SNAKE_JUMP_SKINS = [
  { id: "classic", name: "Classic", cost: 0, fill: "#596ff2", ring: "#f2c733", desc: "Default blue & gold" },
  { id: "neon_cyan", name: "Neon Dynasty", cost: 1_000_000, fill: "#22d3ee", ring: "#06b6d4", desc: "Bright cyan prestige" },
  { id: "solar_gold", name: "Solar Sovereign", cost: 3_500_000, fill: "#fbbf24", ring: "#fef08a", desc: "Golden sun tier" },
  { id: "violet_void", name: "Violet Voidlord", cost: 6_000_000, fill: "#a855f7", ring: "#e879f9", desc: "Purple nebula elite" },
  { id: "emerald", name: "Emerald Elite", cost: 8_500_000, fill: "#34d399", ring: "#a7f3d0", desc: "Jungle green prestige" },
  { id: "crimson", name: "Crimson Overlord", cost: 11_000_000, fill: "#ef4444", ring: "#fca5a5", desc: "Red hot dominion" },
  { id: "ghost", name: "Ghost Phantom", cost: 13_500_000, fill: "#f8fafc", ring: "#94a3b8", desc: "Minimal white phantom" },
  { id: "nfg_fire", name: "NFG Inferno", cost: 15_000_000, fill: "#ff6b35", ring: "#ffd700", desc: "Official NFG flame" },
];

function getSnakeJumpSkin(id) {
  const key = String(id || "").trim();
  return SNAKE_JUMP_SKINS.find((s) => s.id === key) || SNAKE_JUMP_SKINS[0];
}

function ensureSnakeJumpCosmetics(gRec) {
  if (!Array.isArray(gRec.ownedSkins)) gRec.ownedSkins = [SNAKE_JUMP_DEFAULT_SKIN];
  if (!gRec.ownedSkins.includes(SNAKE_JUMP_DEFAULT_SKIN)) {
    gRec.ownedSkins.unshift(SNAKE_JUMP_DEFAULT_SKIN);
  }
  if (!gRec.equippedSkin) gRec.equippedSkin = SNAKE_JUMP_DEFAULT_SKIN;
  if (!gRec.ownedSkins.includes(gRec.equippedSkin)) {
    gRec.equippedSkin = SNAKE_JUMP_DEFAULT_SKIN;
  }
}

function jumpLeaderboardExtras(gRec) {
  ensureSnakeJumpCosmetics(gRec);
  const skin = getSnakeJumpSkin(gRec.equippedSkin);
  const isClassic = skin.id === SNAKE_JUMP_DEFAULT_SKIN;
  return {
    jumpSkinId: skin.id,
    jumpSkinName: isClassic ? null : skin.name,
    jumpSkinFill: skin.fill,
    jumpSkinRing: skin.ring,
  };
}

function syncJumpLeaderboardEntry(state, gameId, userId, score, gRec, pointStore) {
  if (gameId !== "nfg_snake_jump") {
    return recordArcadeLeaderboard(state, gameId, userId, score, pointStore);
  }
  const u = normUser(userId);
  const pts = Math.floor(Number(score) || 0);
  if (!u || pts <= 0) return;
  const boards = ensureLeaderboards(state);
  const rows = boards[gameId];
  const extras = gRec ? jumpLeaderboardExtras(gRec) : {};
  const existing = rows.find((r) => normUser(r.userId) === u);
  if (existing) {
    if (pts <= Math.floor(Number(existing.points) || 0)) {
      Object.assign(existing, extras, { updatedAt: Date.now() });
      return;
    }
    existing.points = pts;
    existing.displayName = arcadeDisplayName(u, pointStore);
    existing.updatedAt = Date.now();
    Object.assign(existing, extras);
  } else {
    rows.push({
      userId: u,
      displayName: arcadeDisplayName(u, pointStore),
      points: pts,
      updatedAt: Date.now(),
      ...extras,
    });
  }
  rows.sort((a, b) => (Number(b.points) || 0) - (Number(a.points) || 0));
  boards[gameId] = rows.slice(0, LEADERBOARD_MAX);
}

function snakeJumpShopPayload(gRec) {
  ensureSnakeJumpCosmetics(gRec);
  const equipped = getSnakeJumpSkin(gRec.equippedSkin);
  return {
    jumpShop: SNAKE_JUMP_SKINS.map((s) => ({
      id: s.id,
      name: s.name,
      cost: s.cost,
      fill: s.fill,
      ring: s.ring,
      desc: s.desc,
      owned: gRec.ownedSkins.includes(s.id),
      equipped: gRec.equippedSkin === s.id,
    })),
    equippedSkin: gRec.equippedSkin,
    equippedFill: equipped.fill,
    equippedRing: equipped.ring,
    skinFill: equipped.fill,
    skinRing: equipped.ring,
  };
}

function snakeJumpReward() {
  return SNAKE_JUMP_REWARD;
}
function defaultSnakeJumpSession() {
  return {
    active: false,
    milestones: 0,
    sessionPoints: 0,
    lastMilestoneHeight: 0,
    lastMilestoneAt: 0,
    peakHeight: 0,
    vsMatchId: null,
    vsDeferred: false,
  };
}
function snakeJumpPayload(gRec) {
  const s = gRec.session || defaultSnakeJumpSession();
  return {
    runActive: !!s.active,
    sessionActive: !!s.active,
    sessionPoints: s.sessionPoints || 0,
    score: s.peakHeight || 0,
    sessionMilestones: s.milestones || 0,
    sessionLevels: s.milestones || 0,
    bestLevel: gRec.bestHeight || 0,
    levelRewardPreview: snakeJumpReward(),
    ...snakeJumpShopPayload(gRec),
    practiceMode: false,
    unlimited: true,
    stakeMin: 0,
    stakeMax: 0,
    suggestedStake: 0,
    vsMatchId: s.vsMatchId || null,
    vsDeferred: !!s.vsDeferred,
  };
}

function milestoneGainAmount() {
  let gain = snakeJumpReward();
  if (isLive()) gain = Math.floor(gain * LIVE_WIN_MULT);
  return gain;
}
function handleSnakeJump(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_snake_jump";
  const fields = baseFields(userRec, gameId, pointStore, user);
  fields.stakeMin = 0;
  fields.stakeMax = 0;
  fields.suggestedStake = 0;
  fields.unlimited = true;
  if (!userRec.games.nfg_snake_jump) userRec.games.nfg_snake_jump = {};
  const gRec = userRec.games.nfg_snake_jump;
  if (!gRec.session) gRec.session = defaultSnakeJumpSession();
  ensureSnakeJumpCosmetics(gRec);
  const act = String(action || "status").toLowerCase();
  const p = payload && typeof payload === "object" ? payload : {};
  if (act === "status" || act === "shop") {
    return {
      ok: true,
      ...fields,
      ...snakeJumpPayload(gRec),
      message:
        "NFG Jump — bounce higher. +3,000 pts every 2,500m. Jump VS: winner takes the combined pot.",
    };
  }
  if (act === "start") {
    ensureSnakeJumpCosmetics(gRec);
    gRec.session = defaultSnakeJumpSession();
    gRec.session.active = true;
    if (p?.vsMatchId) {
      gRec.session.vsMatchId = String(p.vsMatchId).slice(0, 64);
      gRec.session.vsDeferred = true;
    }
    gRec.bestHeight = gRec.bestHeight || 0;
    userRec.games.nfg_snake_jump = gRec;
    return {
      ok: true,
      ...fields,
      ...snakeJumpPayload(gRec),
      message: gRec.session.vsMatchId
        ? "VS match — climb fast or get eliminated!"
        : "New run — climb as high as you can!",
    };
  }
  if (act === "milestone") {
    if (!gRec.session?.active) {
      return {
        ok: false,
        reason: "no_session",
        message: "Tap New Run first.",
        ...fields,
        ...snakeJumpPayload(gRec),
      };
    }
    const height = Math.max(0, Math.floor(Number(p.height) || 0));
    const now = Date.now();
    const expected = (gRec.session.milestones || 0) + 1;
    const requiredHeight = expected * SNAKE_JUMP_MILESTONE_STEP;
    if (height < requiredHeight) {
      return {
        ok: false,
        reason: "height_too_low",
        message: `Reach ${requiredHeight}m for the next milestone.`,
        ...fields,
        ...snakeJumpPayload(gRec),
      };
    }
    if ((gRec.session.milestones || 0) >= SNAKE_JUMP_MAX_MILESTONES) {
      return {
        ok: false,
        reason: "cap",
        message: "Milestone cap reached this run — end session.",
        ...fields,
        ...snakeJumpPayload(gRec),
      };
    }
    const gained = milestoneGainAmount();
    if (gRec.session.vsDeferred) {
      gRec.session.sessionPoints = (gRec.session.sessionPoints || 0) + gained;
    } else {
      creditWin(pointStore, user, gained);
      gRec.session.sessionPoints = (gRec.session.sessionPoints || 0) + gained;
    }
    gRec.session.milestones = expected;
    gRec.session.lastMilestoneHeight = requiredHeight;
    gRec.session.lastMilestoneAt = now;
    gRec.session.peakHeight = Math.max(gRec.session.peakHeight || 0, height);
    gRec.bestHeight = Math.max(gRec.bestHeight || 0, height);
    userRec.games.nfg_snake_jump = gRec;
    return {
      ok: true,
      ...fields,
      ...snakeJumpPayload(gRec),
      gained,
      cleared: true,
      win: true,
      message: `${height}m milestone! +${gained.toLocaleString()} pts (session ${gRec.session.sessionPoints.toLocaleString()} pts)`,
    };
  }
  if (act === "game_over") {
    const height = Math.max(0, Math.floor(Number(p.height) || 0));
    const peak = Math.max(gRec.session?.peakHeight || 0, height);
    const sessionPts = gRec.session?.sessionPoints || 0;
    const vsDeferred = !!gRec.session?.vsDeferred;
    const vsMatchId = gRec.session?.vsMatchId;
    gRec.bestHeight = Math.max(gRec.bestHeight || 0, peak);
    if (vsDeferred && vsMatchId) {
      gRec.session.active = false;
      gRec.session.peakHeight = peak;
      userRec.games.nfg_snake_jump = gRec;
      return {
        ok: true,
        ...fields,
        ...snakeJumpPayload(gRec),
        sessionPoints: sessionPts,
        score: peak,
        message: `VS run over at ${peak}m — pot still in play`,
      };
    }
    gRec.session = defaultSnakeJumpSession();
    userRec.games.nfg_snake_jump = gRec;
    return {
      ok: true,
      ...fields,
      ...snakeJumpPayload(gRec),
      sessionPoints: sessionPts,
      score: peak,
      message:
        sessionPts > 0
          ? `Run over — ${peak}m peak, ${sessionPts.toLocaleString()} pts banked`
          : peak > 0
            ? `Run over at ${peak}m — start a new run for milestones`
            : "Run over — try again!",
    };
  }
  if (act === "buy") {
    const skinId = String(p.skinId || p.skin || p.itemId || "").trim();
    const skin = getSnakeJumpSkin(skinId);
    if (!skin || skin.id !== skinId) {
      return {
        ok: false,
        reason: "unknown_skin",
        message: "Unknown circle style.",
        ...fields,
        ...snakeJumpPayload(gRec),
      };
    }
    if (gRec.ownedSkins.includes(skinId)) {
      gRec.equippedSkin = skinId;
      userRec.games.nfg_snake_jump = gRec;
      return {
        ok: true,
        ...fields,
        ...snakeJumpPayload(gRec),
        message: `${skin.name} equipped.`,
      };
    }
    if (skin.cost > 0) {
      const debit = debitStake(pointStore, user, skin.cost);
      if (!debit.ok) {
        return { ...debit, ...fields, ...snakeJumpPayload(gRec) };
      }
      fields.balance = debit.balance;
    }
    gRec.ownedSkins.push(skinId);
    gRec.equippedSkin = skinId;
    userRec.games.nfg_snake_jump = gRec;
    return {
      ok: true,
      ...fields,
      ...snakeJumpPayload(gRec),
      cost: skin.cost,
      message:
        skin.cost > 0
          ? `Unlocked ${skin.name} for ${skin.cost.toLocaleString()} pts!`
          : `${skin.name} equipped.`,
    };
  }
  if (act === "equip") {
    const skinId = String(p.skinId || p.skin || p.itemId || "").trim();
    const skin = getSnakeJumpSkin(skinId);
    if (!skin || skin.id !== skinId) {
      return {
        ok: false,
        reason: "unknown_skin",
        message: "Unknown circle style.",
        ...fields,
        ...snakeJumpPayload(gRec),
      };
    }
    if (!gRec.ownedSkins.includes(skinId)) {
      return {
        ok: false,
        reason: "not_owned",
        message: "Buy this style first.",
        ...fields,
        ...snakeJumpPayload(gRec),
      };
    }
    gRec.equippedSkin = skinId;
    userRec.games.nfg_snake_jump = gRec;
    return {
      ok: true,
      ...fields,
      ...snakeJumpPayload(gRec),
      message: `${skin.name} equipped.`,
    };
  }
  return {
    ok: false,
    reason: "invalid_action",
    message: "Use start, milestone, game_over, buy, or equip.",
    ...fields,
    ...snakeJumpPayload(gRec),
  };
}

function getJumpPlayerCosmetics(userId) {
  const state = loadState();
  const uid = normUser(userId);
  const g = state.users?.[uid]?.games?.nfg_snake_jump;
  if (!g) {
    const skin = getSnakeJumpSkin(SNAKE_JUMP_DEFAULT_SKIN);
    return { skinId: skin.id, fill: skin.fill, ring: skin.ring, name: skin.name };
  }
  ensureSnakeJumpCosmetics(g);
  const skin = getSnakeJumpSkin(g.equippedSkin);
  return { skinId: skin.id, fill: skin.fill, ring: skin.ring, name: skin.name };
}

function prepareJumpVsMatch(playerIds, matchId, matchSeed) {
  const state = loadState();
  for (const rawId of playerIds) {
    const user = normUser(rawId);
    if (!user) continue;
    const userRec = ensureUser(state, user);
    if (!userRec.games.nfg_snake_jump) userRec.games.nfg_snake_jump = {};
    const gRec = userRec.games.nfg_snake_jump;
    gRec.session = defaultSnakeJumpSession();
    gRec.session.active = true;
    gRec.session.vsMatchId = matchId;
    gRec.session.vsDeferred = true;
    gRec.session.vsMatchSeed = matchSeed;
    userRec.games.nfg_snake_jump = gRec;
  }
  saveState(state);
}

function syncJumpVsSessionPoints(userId) {
  const state = loadState();
  const uid = normUser(userId);
  const pts = state.users?.[uid]?.games?.nfg_snake_jump?.session?.sessionPoints || 0;
  return Math.max(0, Math.floor(Number(pts) || 0));
}

function finalizeJumpVsMatch(winnerId, playerIds, pointStore) {
  const state = loadState();
  let pot = 0;
  const winner = normUser(winnerId);

  for (const rawId of playerIds) {
    const user = normUser(rawId);
    if (!user) continue;
    const gRec = state.users?.[user]?.games?.nfg_snake_jump;
    const sessionPts = Math.max(0, Math.floor(Number(gRec?.session?.sessionPoints) || 0));
    pot += sessionPts;
    if (gRec) {
      gRec.session = defaultSnakeJumpSession();
      state.users[user].games.nfg_snake_jump = gRec;
    }
  }

  if (winner && pot > 0 && pointStore) {
    creditWin(pointStore, winner, pot);
  }

  saveState(state);
  return pot;
}

// ========== NFG Vault Run (3-lane space flight skill game) ==========
const VAULT_RUN_MILESTONE_BASE_STEP = 400;
const VAULT_RUN_MILESTONE_BASE_REWARD = 3000;
const VAULT_RUN_MILESTONE_REWARD_GROWTH = 600;
const VAULT_RUN_MAX_MILESTONES = 40;
const VAULT_RUN_DEFAULT_SHIP = "classic";

function vaultRunMilestoneDistance(tier) {
  return Math.max(0, tier) * VAULT_RUN_MILESTONE_BASE_STEP;
}

function vaultRunMilestoneReward(tier) {
  if (tier <= 0) return VAULT_RUN_MILESTONE_BASE_REWARD;
  return VAULT_RUN_MILESTONE_BASE_REWARD + (tier - 1) * VAULT_RUN_MILESTONE_REWARD_GROWTH;
}

const VAULT_RUN_SHIPS = [
  { id: "classic", name: "Star Scout", cost: 0, hull: "#62b8f8", cockpit: "#35e0ff", trail: "#22d3ee", style: "scout", desc: "Default cyan scout · ion trail" },
  { id: "neon_streak", name: "Neon Streak", cost: 1_000_000, hull: "#22d3ee", cockpit: "#67e8f9", trail: "#06b6d4", style: "fighter", desc: "Radiant fighter hull · cyan exhaust" },
  { id: "solar_flare", name: "Solar Flare", cost: 3_500_000, hull: "#fbbf24", cockpit: "#fef08a", trail: "#f59e0b", style: "interceptor", desc: "Golden interceptor · solar trail" },
  { id: "violet_nebula", name: "Violet Nebula", cost: 6_000_000, hull: "#a855f7", cockpit: "#e879f9", trail: "#c084fc", style: "scout", desc: "Purple nebula scout · violet wake" },
  { id: "emerald_comet", name: "Emerald Comet", cost: 8_500_000, hull: "#34d399", cockpit: "#a7f3d0", trail: "#10b981", style: "fighter", desc: "Emerald fighter · comet trail" },
  { id: "crimson_blaze", name: "Crimson Blaze", cost: 11_000_000, hull: "#ef4444", cockpit: "#fca5a5", trail: "#f97316", style: "interceptor", desc: "Crimson interceptor · blaze trail" },
  { id: "ghost_void", name: "Ghost Void", cost: 13_500_000, hull: "#e2e8f0", cockpit: "#94a3b8", trail: "#cbd5e1", style: "phantom", desc: "Phantom hull · ghost wake" },
  { id: "nfg_ignition", name: "NFG Ignition", cost: 15_000_000, hull: "#ff6b35", cockpit: "#ffd700", trail: "#fb923c", style: "inferno", desc: "Official NFG inferno · ultimate trail" },
];

function getVaultRunShip(id) {
  const key = String(id || "").trim();
  return VAULT_RUN_SHIPS.find((s) => s.id === key) || VAULT_RUN_SHIPS[0];
}

function ensureVaultRunCosmetics(gRec) {
  if (!Array.isArray(gRec.ownedShips)) gRec.ownedShips = [VAULT_RUN_DEFAULT_SHIP];
  if (!gRec.ownedShips.includes(VAULT_RUN_DEFAULT_SHIP)) {
    gRec.ownedShips.unshift(VAULT_RUN_DEFAULT_SHIP);
  }
  if (!gRec.equippedShip) gRec.equippedShip = VAULT_RUN_DEFAULT_SHIP;
  if (!gRec.ownedShips.includes(gRec.equippedShip)) {
    gRec.equippedShip = VAULT_RUN_DEFAULT_SHIP;
  }
}

function vaultRunShopPayload(gRec) {
  ensureVaultRunCosmetics(gRec);
  const equipped = getVaultRunShip(gRec.equippedShip);
  return {
    vaultShop: VAULT_RUN_SHIPS.map((s) => ({
      id: s.id,
      name: s.name,
      cost: s.cost,
      hull: s.hull,
      cockpit: s.cockpit,
      trail: s.trail,
      style: s.style,
      desc: s.desc,
      owned: gRec.ownedShips.includes(s.id),
      equipped: gRec.equippedShip === s.id,
    })),
    equippedVaultShip: gRec.equippedShip,
    ownedVaultShips: [...gRec.ownedShips],
    shipHull: equipped.hull,
    shipCockpit: equipped.cockpit,
    shipTrail: equipped.trail,
    shipStyle: equipped.style,
  };
}

function defaultVaultRunSession() {
  return {
    active: false,
    milestones: 0,
    sessionPoints: 0,
    lastMilestoneDistance: 0,
    lastMilestoneAt: 0,
    peakDistance: 0,
  };
}

function vaultRunPayload(gRec) {
  const s = gRec.session || defaultVaultRunSession();
  const nextTier = (s.milestones || 0) + 1;
  return {
    runActive: !!s.active,
    sessionActive: !!s.active,
    sessionPoints: s.sessionPoints || 0,
    score: s.peakDistance || 0,
    sessionMilestones: s.milestones || 0,
    sessionLevels: s.milestones || 0,
    bestLevel: gRec.bestDistance || 0,
    levelRewardPreview: vaultRunMilestoneReward(nextTier),
    practiceMode: false,
    unlimited: true,
    stakeMin: 0,
    stakeMax: 0,
    suggestedStake: 0,
    ...vaultRunShopPayload(gRec),
  };
}

function vaultRunMeters(p) {
  const raw = p.height != null ? p.height : p.distance;
  return Math.max(0, Math.floor(Number(raw) || 0));
}

function handleVaultRun(user, userRec, action, payload, pointStore) {
  const gameId = "nfg_vault_run";
  const fields = baseFields(userRec, gameId, pointStore, user);
  fields.stakeMin = 0;
  fields.stakeMax = 0;
  fields.suggestedStake = 0;
  fields.unlimited = true;
  if (!userRec.games.nfg_vault_run) userRec.games.nfg_vault_run = {};
  const gRec = userRec.games.nfg_vault_run;
  if (!gRec.session) gRec.session = defaultVaultRunSession();
  ensureVaultRunCosmetics(gRec);
  const act = String(action || "status").toLowerCase();
  const p = payload && typeof payload === "object" ? payload : {};

  if (act === "status") {
    return {
      ok: true,
      ...fields,
      ...vaultRunPayload(gRec),
      message:
        "NFG Rush — 3-lane dash. Swipe lanes, boost, shrink. Milestones every 400m — 3,000 pts scaling up.",
    };
  }
  if (act === "start") {
    ensureVaultRunCosmetics(gRec);
    gRec.session = defaultVaultRunSession();
    gRec.session.active = true;
    gRec.bestDistance = gRec.bestDistance || 0;
    userRec.games.nfg_vault_run = gRec;
    return {
      ok: true,
      ...fields,
      ...vaultRunPayload(gRec),
      message: "New run — dodge obstacles and fly as far as you can!",
    };
  }
  if (act === "milestone") {
    if (!gRec.session?.active) {
      return {
        ok: false,
        reason: "no_session",
        message: "Tap New Run first.",
        ...fields,
        ...vaultRunPayload(gRec),
      };
    }
    const distance = vaultRunMeters(p);
    const now = Date.now();
    const expected = (gRec.session.milestones || 0) + 1;
    const requiredDistance = vaultRunMilestoneDistance(expected);
    if (distance < requiredDistance) {
      return {
        ok: false,
        reason: "distance_too_low",
        message: `Reach ${requiredDistance}m for the next milestone.`,
        ...fields,
        ...vaultRunPayload(gRec),
      };
    }
    if ((gRec.session.milestones || 0) >= VAULT_RUN_MAX_MILESTONES) {
      return {
        ok: false,
        reason: "cap",
        message: "Milestone cap reached this run — end session.",
        ...fields,
        ...vaultRunPayload(gRec),
      };
    }
    const reward = vaultRunMilestoneReward(expected);
    const gained = creditWin(pointStore, user, reward);
    gRec.session.milestones = expected;
    gRec.session.sessionPoints = (gRec.session.sessionPoints || 0) + gained;
    gRec.session.lastMilestoneDistance = requiredDistance;
    gRec.session.lastMilestoneAt = now;
    gRec.session.peakDistance = Math.max(gRec.session.peakDistance || 0, distance);
    gRec.bestDistance = Math.max(gRec.bestDistance || 0, distance);
    userRec.games.nfg_vault_run = gRec;
    return {
      ok: true,
      ...fields,
      ...vaultRunPayload(gRec),
      gained,
      cleared: true,
      win: true,
      message: `${distance}m milestone! +${gained.toLocaleString()} pts (session ${gRec.session.sessionPoints.toLocaleString()} pts)`,
    };
  }
  if (act === "game_over") {
    const distance = vaultRunMeters(p);
    const peak = Math.max(gRec.session?.peakDistance || 0, distance);
    const sessionPts = gRec.session?.sessionPoints || 0;
    gRec.bestDistance = Math.max(gRec.bestDistance || 0, peak);
    gRec.session = defaultVaultRunSession();
    userRec.games.nfg_vault_run = gRec;
    return {
      ok: true,
      ...fields,
      ...vaultRunPayload(gRec),
      sessionPoints: sessionPts,
      score: peak,
      message:
        sessionPts > 0
          ? `Run over — ${peak}m peak, ${sessionPts.toLocaleString()} pts banked`
          : peak > 0
            ? `Run over at ${peak}m — start a new run for milestones`
            : "Run over — try again!",
    };
  }
  if (act === "shop") {
    return {
      ok: true,
      ...fields,
      ...vaultRunPayload(gRec),
      message: "Ship hangar — buy or equip ships with your Crash points.",
    };
  }
  if (act === "buy") {
    const shipId = String(p.itemId || p.skinId || p.shipId || "").trim();
    const ship = getVaultRunShip(shipId);
    if (!ship || ship.id !== shipId) {
      return {
        ok: false,
        reason: "unknown_ship",
        message: "Unknown ship.",
        ...fields,
        ...vaultRunPayload(gRec),
      };
    }
    if (gRec.ownedShips.includes(shipId)) {
      gRec.equippedShip = shipId;
      userRec.games.nfg_vault_run = gRec;
      return {
        ok: true,
        ...fields,
        ...vaultRunPayload(gRec),
        message: `${ship.name} equipped.`,
      };
    }
    if (ship.cost > 0) {
      const debit = debitStake(pointStore, user, ship.cost);
      if (!debit.ok) {
        return { ...debit, ...fields, ...vaultRunPayload(gRec) };
      }
      fields.balance = debit.balance;
    }
    gRec.ownedShips.push(shipId);
    gRec.equippedShip = shipId;
    userRec.games.nfg_vault_run = gRec;
    return {
      ok: true,
      ...fields,
      ...vaultRunPayload(gRec),
      cost: ship.cost,
      message:
        ship.cost > 0
          ? `Unlocked ${ship.name} for ${ship.cost.toLocaleString()} pts!`
          : `${ship.name} equipped.`,
    };
  }
  if (act === "equip") {
    const shipId = String(p.itemId || p.skinId || p.shipId || "").trim();
    const ship = getVaultRunShip(shipId);
    if (!ship || ship.id !== shipId) {
      return {
        ok: false,
        reason: "unknown_ship",
        message: "Unknown ship.",
        ...fields,
        ...vaultRunPayload(gRec),
      };
    }
    if (!gRec.ownedShips.includes(shipId)) {
      return {
        ok: false,
        reason: "not_owned",
        message: "Buy this ship first.",
        ...fields,
        ...vaultRunPayload(gRec),
      };
    }
    gRec.equippedShip = shipId;
    userRec.games.nfg_vault_run = gRec;
    return {
      ok: true,
      ...fields,
      ...vaultRunPayload(gRec),
      message: `${ship.name} equipped.`,
    };
  }
  return {
    ok: false,
    reason: "invalid_action",
    message: "Use start, milestone, game_over, buy, or equip.",
    ...fields,
    ...vaultRunPayload(gRec),
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
  nfg_snake_jump: handleSnakeJump,
  nfg_vault_run: handleVaultRun,
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

  if (isStakedAction(action, gameId)) {
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

  if (result.ok !== false) {
    if (gameId === "nfg_blocks") {
      const best = userRec.games?.nfg_blocks?.bestLevel;
      if (best > 0) recordArcadeLeaderboard(state, gameId, user, best, pointStore);
    }
    if (gameId === "nfg_snake_jump") {
      const gRec = userRec.games?.nfg_snake_jump;
      const best = gRec?.bestHeight;
      if (best > 0) syncJumpLeaderboardEntry(state, gameId, user, best, gRec, pointStore);
    }
    if (gameId === "nfg_vault_run") {
      const best = userRec.games?.nfg_vault_run?.bestDistance;
      if (best > 0) recordArcadeLeaderboard(state, gameId, user, best, pointStore);
    }
  }

  if (result.ok !== false && isStakedAction(action, gameId)) {
    touchArcadeStake(userRec);
  }

  Object.assign(result, arcadeCooldownFields(userRec, gameId));

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

  app.get("/api/mobile/arcade/leaderboard", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });
    const gameId = String(req.query?.gameId || "").trim();
    if (!LEADERBOARD_GAME_IDS.has(gameId)) {
      return res.status(400).json({
        ok: false,
        reason: "invalid_game",
        message: "Use gameId=nfg_blocks, gameId=nfg_snake_jump, or gameId=nfg_vault_run.",
      });
    }
    try {
      const state = loadState();
      return res.json(getArcadeLeaderboard(state, gameId, session.userId, pointStore));
    } catch (e) {
      return res.status(500).json({ ok: false, message: e.message || "arcade_error" });
    }
  });

  app.post("/api/mobile/arcade/mission/claim", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });
    const body = req.body && typeof req.body === "object" ? req.body : {};
    const missionId = String(body.missionId || body.id || "").trim();
    if (!missionId) {
      return res.status(400).json({ ok: false, reason: "invalid_mission", message: "Missing missionId." });
    }
    try {
      const result = claimMission(pointStore, game, session.userId, missionId);
      return res.status(result.ok === false ? 400 : 200).json(result);
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

module.exports = {
  registerMobileArcadeRoutes,
  buildCatalog,
  playGame,
  GAME_DEFS,
  getPublicTowerHero,
  getJumpPlayerCosmetics,
  prepareJumpVsMatch,
  syncJumpVsSessionPoints,
  finalizeJumpVsMatch,
  SNAKE_JUMP_SKINS,
};
