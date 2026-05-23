const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");

const DATA_DIR = path.join(getAppRoot(), "data");
const PRIMARY_POINTS_BASENAME = process.env.POINTS_FILE_NAME || "points.live.json";
const PRIMARY_POINTS_FILE = path.join(DATA_DIR, PRIMARY_POINTS_BASENAME);
const BACKUPS_DIR = path.join(DATA_DIR, "backups");
const LEGACY_POINTS_FILES = [
  path.join(DATA_DIR, "points.json"),
  path.join(getAppRoot(), "dist", "data", "points.json"),
];
const SHIELDS_FILE = path.join(DATA_DIR, "shields.json");
const POINTS_BAK_FILE = `${PRIMARY_POINTS_FILE}.bak`;
const POINTS_META_FILE = path.join(DATA_DIR, "points.live.meta.json");
const MIN_USERS_GUARD = Math.max(0, Math.floor(Number(process.env.POINTS_MIN_USERS_GUARD) || 5));
const SHRINK_RATIO_GUARD = Math.min(
  1,
  Math.max(0.05, Number(process.env.POINTS_SHRINK_RATIO_GUARD) || 0.5)
);
const SHIELD_UNIT_MS = 48 * 60 * 60 * 1000;
const TAX_POT_RESET_MS = 7 * 24 * 60 * 60 * 1000;
const HIGH_STAKE_BET_THRESHOLD = 1000;
const HIGH_STAKE_BET_BONUS_EVERY = 25;
const HIGH_STAKE_BET_BONUS_POINTS = 5000;
const XP_ACTION_VALUES = {
  CHAT_MESSAGE: 8,
  GIFT_RECEIVED: 40,
  BET_PLACED: 6,
  CASHOUT_SUCCESS: 38,
  MISSION_COMPLETED: 80,
  ACHIEVEMENT_UNLOCKED: 110,
  DAILY_LOGIN: 20,
};
const XP_LEVEL_BASE = 260;
const XP_LEVEL_GROWTH = 1.24;
const DAILY_CHALLENGE_DEFS = [
  { id: "daily_plays", key: "plays", title: "Play Rounds", baseGoal: 25, stepGoal: 5, stepEveryLevels: 5, xpReward: 130 },
  { id: "daily_likes", key: "likes", title: "Like the Live", baseGoal: 10000, stepGoal: 2000, stepEveryLevels: 4, xpReward: 170 },
  { id: "daily_gift_coins", key: "giftCoins", title: "Gift Coins (Money Gun goal)", baseGoal: 500, stepGoal: 100, stepEveryLevels: 4, xpReward: 180 },
];
const SUPERFAN_ICON_COUNT = 200;
const SUPERFAN_DAILY_BONUS_POINTS = 100_000;
const SUPERFAN_FIRST_ACTIVATION_BONUS_POINTS = 100_000;
const CHALLENGE_EVENT_TO_KEY = {
  PLAY_EVENT: "plays",
  LIKE_EVENT: "likes",
  GIFT_COINS: "giftCoins",
  GIFT_RECEIVED: "giftCoins",
};
const ACHIEVEMENTS = {
  first_chat: { title: "First Words", xpReward: 80 },
  level_10: { title: "Level 10", xpReward: 180 },
  week_streak: { title: "7 Day Streak", xpReward: 220 },
  first_gift: { title: "Gifted", xpReward: 120 },
};

const UK_DAY_FORMATTER = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Europe/London",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

function ukDayKey(input = Date.now()) {
  return UK_DAY_FORMATTER.format(new Date(input));
}

function nextUkMidnightMs(nowMs = Date.now()) {
  const nowKey = ukDayKey(nowMs);
  let probe = nowMs + 60_000;
  let guard = 0;
  while (ukDayKey(probe) === nowKey && guard < 60 * 48) {
    probe += 60_000;
    guard += 1;
  }
  let lo = probe - 60_000;
  let hi = probe;
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    if (ukDayKey(mid) === nowKey) lo = mid;
    else hi = mid;
  }
  return hi;
}

function defaultTaxPotState(nowMs = Date.now()) {
  return {
    dayKey: ukDayKey(nowMs),
    amount: 0,
    periodStartedAt: nowMs,
    updatedAt: nowMs,
  };
}

function normalizeDisplayKey(name) {
  return String(name || "")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase()
    .slice(0, 60);
}

const { CANONICAL_BADGE_IDS, resolveBadgeId } = require("./badge-ids");

const OWNABLE_NAME_BADGES = CANONICAL_BADGE_IDS;

function normalizeOwnedBadges(list) {
  if (!Array.isArray(list)) return [];
  const out = [];
  for (const raw of list) {
    const id = resolveBadgeId(raw);
    if (!OWNABLE_NAME_BADGES.has(id) || out.includes(id)) continue;
    out.push(id);
  }
  return out;
}

function getDefaultProfile(user) {
  return {
    displayName: user,
    nameStyle: "none",
    nameBadge: "none",
    ownedBadges: [],
    superFan: false,
    superFanLevel: 0,
    superFanIcon: -1,
    superFanWelcomeBonusGranted: false,
    superFanDailyBonusDay: "",
    xp: 0,
    level: 1,
    rank: "Rookie",
    dailyStreak: 0,
    lastDailyClaimAt: 0,
    achievements: [],
    missionProgress: {},
    completedMissions: [],
    totalWagered: 0,
    highStakeBetCount: 0,
    highStakeBonusClaims: 0,
    totalRakebackClaimed: 0,
    challengeState: null,
    challengeLog: [],
    powerups: {
      stealCharges: 0,
      shieldBreakCharges: 0,
      jetLockCharges: 0,
    },
  };
}

function challengeStepForLevel(level, stepEveryLevels) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  const stepEvery = Math.max(1, Math.floor(Number(stepEveryLevels) || 1));
  return Math.floor((lv - 1) / stepEvery);
}

function getLevelFromXp(xp) {
  const safeXp = Math.max(0, Math.floor(Number(xp) || 0));
  let level = 1;
  let guard = 0;
  while (xpNeededForLevel(level + 1) <= safeXp && guard < 2000) {
    level += 1;
    guard += 1;
  }
  return Math.max(1, level);
}

function xpNeededForLevel(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  if (lv <= 1) return 0;
  const terms = lv - 1;
  const total = XP_LEVEL_BASE * ((Math.pow(XP_LEVEL_GROWTH, terms) - 1) / (XP_LEVEL_GROWTH - 1));
  return Math.max(0, Math.floor(total));
}

function challengeCompletionLevelBoost(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  if (lv <= 15) return 3;
  if (lv <= 35) return 2;
  return 1;
}

function getRankFromLevel(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  if (lv >= 50) return "Master";
  if (lv >= 40) return "Diamond";
  if (lv >= 30) return "Platinum";
  if (lv >= 20) return "Gold";
  if (lv >= 12) return "Silver";
  if (lv >= 6) return "Bronze";
  return "Rookie";
}

function getRakebackRate(rank) {
  return {
    Rookie: 0.004,
    Bronze: 0.006,
    Silver: 0.008,
    Gold: 0.011,
    Platinum: 0.014,
    Diamond: 0.017,
    Master: 0.02,
  }[rank] || 0.004;
}

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function emptyPointsState() {
  return { balances: {}, allTime: {}, profiles: {}, notifications: [], taxPot: defaultTaxPotState() };
}

function countPointsUsers(state) {
  const balances = Object.keys((state && state.balances) || {}).length;
  const profiles = Object.keys((state && state.profiles) || {}).length;
  return Math.max(balances, profiles);
}

function serializePointsState(state) {
  return {
    balances: state.balances || {},
    allTime: state.allTime || {},
    profiles: state.profiles || {},
    notifications: Array.isArray(state.notifications) ? state.notifications : [],
    taxPot: state.taxPot && typeof state.taxPot === "object" ? state.taxPot : defaultTaxPotState(),
  };
}

function readPointsMeta() {
  if (!fs.existsSync(POINTS_META_FILE)) return null;
  try {
    const obj = JSON.parse(fs.readFileSync(POINTS_META_FILE, "utf8"));
    if (!obj || typeof obj !== "object") return null;
    return {
      users: Math.max(0, Math.floor(Number(obj.users) || 0)),
      savedAt: String(obj.savedAt || ""),
      bytes: Math.max(0, Math.floor(Number(obj.bytes) || 0)),
    };
  } catch {
    return null;
  }
}

function writePointsMeta(state, filePath = PRIMARY_POINTS_FILE) {
  let bytes = 0;
  try {
    if (fs.existsSync(filePath)) bytes = fs.statSync(filePath).size;
  } catch {
    // Ignore stat errors.
  }
  const meta = {
    users: countPointsUsers(state),
    savedAt: new Date().toISOString(),
    bytes,
  };
  atomicWriteJsonFile(POINTS_META_FILE, meta);
  return meta;
}

function atomicWriteJsonFile(filePath, obj) {
  ensureDataDir();
  const tmpPath = `${filePath}.tmp`;
  const payload = `${JSON.stringify(obj, null, 2)}\n`;
  fs.writeFileSync(tmpPath, payload, "utf8");
  fs.renameSync(tmpPath, filePath);
}

function isSuspiciousShrink(prevUsers, nextUsers) {
  const prev = Math.max(0, Math.floor(Number(prevUsers) || 0));
  const next = Math.max(0, Math.floor(Number(nextUsers) || 0));
  if (prev < MIN_USERS_GUARD) return false;
  if (next >= prev) return false;
  if (next < MIN_USERS_GUARD) return true;
  if (next < Math.floor(prev * SHRINK_RATIO_GUARD)) return true;
  return false;
}

function normalizePointsPayload(obj) {
  if (!obj || typeof obj !== "object") return null;
  if (obj.balances && typeof obj.balances === "object") {
    return {
      balances: { ...obj.balances },
      allTime: obj.allTime && typeof obj.allTime === "object" ? { ...obj.allTime } : {},
      profiles: obj.profiles && typeof obj.profiles === "object" ? { ...obj.profiles } : {},
      notifications: Array.isArray(obj.notifications) ? [...obj.notifications] : [],
      taxPot: obj.taxPot && typeof obj.taxPot === "object" ? { ...obj.taxPot } : defaultTaxPotState(),
    };
  }
  // Backward compatibility: old file was a plain { user: balance } map.
  return { balances: { ...obj }, allTime: {}, profiles: {}, notifications: [], taxPot: defaultTaxPotState() };
}

function loadPointsFromFile(filePath) {
  if (!filePath || !fs.existsSync(filePath)) return null;
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    if (!String(raw || "").trim()) return null;
    const obj = JSON.parse(raw);
    const normalized = normalizePointsPayload(obj);
    if (!normalized) return null;
    if (countPointsUsers(normalized) === 0) return null;
    return normalized;
  } catch {
    return null;
  }
}

function listBackupSnapshotDirs() {
  if (!fs.existsSync(BACKUPS_DIR)) return [];
  const days = fs
    .readdirSync(BACKUPS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
  const snapshots = [];
  for (const day of days) {
    const dayDir = path.join(BACKUPS_DIR, day);
    let slots = [];
    try {
      slots = fs
        .readdirSync(dayDir, { withFileTypes: true })
        .filter((d) => d.isDirectory())
        .map((d) => d.name)
        .sort();
    } catch {
      continue;
    }
    for (const slot of slots) {
      snapshots.push(path.join(dayDir, slot));
    }
  }
  return snapshots.sort();
}

function readBackupManifest(backupDir) {
  const manifestPath = path.join(backupDir, "manifest.json");
  if (!fs.existsSync(manifestPath)) return null;
  try {
    const obj = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
    if (!obj || typeof obj !== "object") return null;
    return {
      users: Math.max(0, Math.floor(Number(obj.users) || 0)),
      profiles: Math.max(0, Math.floor(Number(obj.profiles) || 0)),
      createdAt: String(obj.createdAt || ""),
    };
  } catch {
    return null;
  }
}

function findBestBackupPoints(minUsersHint = MIN_USERS_GUARD) {
  const snapshots = listBackupSnapshotDirs();
  let best = null;
  let bestUsers = 0;
  let bestDir = "";
  for (let i = snapshots.length - 1; i >= 0; i -= 1) {
    const backupDir = snapshots[i];
    const pointsName = path.basename(PRIMARY_POINTS_FILE);
    const pointsPath = path.join(backupDir, pointsName);
    const manifest = readBackupManifest(backupDir);
    const manifestUsers = manifest ? Math.max(manifest.users, manifest.profiles) : 0;
    const normalized = loadPointsFromFile(pointsPath);
    if (!normalized) continue;
    const users = countPointsUsers(normalized);
    if (users <= bestUsers) continue;
    if (manifestUsers > 0 && users < Math.min(manifestUsers, minUsersHint > 0 ? Math.max(1, Math.floor(minUsersHint * SHRINK_RATIO_GUARD)) : 1)) {
      continue;
    }
    best = normalized;
    bestUsers = users;
    bestDir = backupDir;
  }
  return best ? { state: best, users: bestUsers, backupDir: bestDir } : null;
}

function loadPoints() {
  ensureDataDir();
  const meta = readPointsMeta();
  const minExpected = meta && meta.users >= MIN_USERS_GUARD ? meta.users : 0;
  const candidates = [
    PRIMARY_POINTS_FILE,
    POINTS_BAK_FILE,
    ...LEGACY_POINTS_FILES.filter((filePath) => filePath !== PRIMARY_POINTS_FILE),
  ].filter((filePath, idx, arr) => arr.indexOf(filePath) === idx);

  let best = null;
  let bestUsers = 0;
  let bestPath = "";

  for (const filePath of candidates) {
    const normalized = loadPointsFromFile(filePath);
    if (!normalized) continue;
    const users = countPointsUsers(normalized);
    if (minExpected >= MIN_USERS_GUARD && users < Math.max(MIN_USERS_GUARD, Math.floor(minExpected * SHRINK_RATIO_GUARD))) {
      console.warn(
        `[Points] Ignoring ${filePath} (${users} users; meta expects ~${minExpected}).`
      );
      continue;
    }
    if (users > bestUsers) {
      best = normalized;
      bestUsers = users;
      bestPath = filePath;
    }
    if (filePath === PRIMARY_POINTS_FILE && users >= Math.max(MIN_USERS_GUARD, minExpected || 0)) {
      return normalized;
    }
  }

  if (best && bestUsers > 0) {
    if (bestPath !== PRIMARY_POINTS_FILE) {
      console.warn(`[Points] Loaded ${bestUsers} users from ${bestPath}. Restoring primary file.`);
      savePoints(best, { force: true, source: bestPath });
    }
    return best;
  }

  const recovered = findBestBackupPoints(minExpected || MIN_USERS_GUARD);
  if (recovered && recovered.users > 0) {
    console.error(
      `[Points] Primary data missing or corrupt. Recovered ${recovered.users} users from backup ${recovered.backupDir}.`
    );
    savePoints(recovered.state, { force: true, source: recovered.backupDir });
    return recovered.state;
  }

  if (best && bestUsers > 0) return best;
  console.warn("[Points] No existing database found; starting with an empty hi-scores file.");
  return emptyPointsState();
}

function savePoints(state, options = {}) {
  ensureDataDir();
  const payload = serializePointsState(state);
  const nextUsers = countPointsUsers(payload);
  const meta = readPointsMeta();
  const prevUsers = meta?.users ?? nextUsers;
  const force = options.force === true;

  if (!force && isSuspiciousShrink(prevUsers, nextUsers)) {
    console.error(
      `[Points] Refusing to save: user count would drop ${prevUsers} -> ${nextUsers}. Disk left unchanged.`
    );
    return { ok: false, reason: "shrink_guard", prevUsers, nextUsers };
  }

  atomicWriteJsonFile(PRIMARY_POINTS_FILE, payload);
  try {
    fs.copyFileSync(PRIMARY_POINTS_FILE, POINTS_BAK_FILE);
  } catch (err) {
    console.warn("[Points] Could not refresh .bak copy:", err.message);
  }
  writePointsMeta(payload);
  if (options.source) {
    console.log(`[Points] Saved ${nextUsers} users (${options.source}).`);
  }
  return { ok: true, users: nextUsers };
}

function loadShields() {
  ensureDataDir();
  if (!fs.existsSync(SHIELDS_FILE)) return {};
  try {
    const raw = fs.readFileSync(SHIELDS_FILE, "utf8");
    const obj = JSON.parse(raw);
    return typeof obj === "object" && obj ? obj : {};
  } catch {
    return {};
  }
}

function saveShields(shields) {
  ensureDataDir();
  atomicWriteJsonFile(SHIELDS_FILE, shields || {});
}

function normalizeUser(name) {
  return String(name || "")
    .trim()
    .replace(/^@+/, "")
    .slice(0, 40);
}

class PointStore {
  constructor(defaultStarter) {
    this.defaultStarter = defaultStarter;
    this.points = loadPoints();
    this._recoverPointsFromBackupIfWiped();
    if (!readPointsMeta() && countPointsUsers(this.points) >= MIN_USERS_GUARD) {
      writePointsMeta(this.points);
    }
    this.shields = loadShields();
    this._pruneExpiredShields();
  }

  _savePoints() {
    const result = savePoints(this.points);
    if (result && result.ok === false && result.reason === "shrink_guard") {
      console.error("[Points] Reloading in-memory hi-scores from last good on-disk copy.");
      this.points = loadPoints();
    }
  }

  /** Reload balances/profiles from disk (use after manual data fixes while server runs). */
  reloadFromDisk() {
    this.points = loadPoints();
  }

  _recoverPointsFromBackupIfWiped() {
    const meta = readPointsMeta();
    const users = countPointsUsers(this.points);
    const expected = meta?.users || 0;
    if (expected < MIN_USERS_GUARD) return { recovered: false, users };
    const minAllowed = Math.max(MIN_USERS_GUARD, Math.floor(expected * SHRINK_RATIO_GUARD));
    if (users >= minAllowed) return { recovered: false, users };
    const recovered = findBestBackupPoints(expected);
    if (!recovered || recovered.users <= users) {
      console.error(
        `[Points] Database looks wiped (${users} users; expected ~${expected}) but no better backup was found.`
      );
      return { recovered: false, users, expected };
    }
    console.error(
      `[Points] Auto-recovering ${recovered.users} users from ${recovered.backupDir} (was ${users}).`
    );
    this.points = recovered.state;
    savePoints(this.points, { force: true, source: recovered.backupDir });
    return { recovered: true, users: recovered.users, backupDir: recovered.backupDir };
  }

  _saveShields() {
    saveShields(this.shields);
  }

  _snapshotStamp(now = new Date()) {
    const pad = (n) => String(n).padStart(2, "0");
    const yyyy = String(now.getFullYear());
    const mm = pad(now.getMonth() + 1);
    const dd = pad(now.getDate());
    const hh = pad(now.getHours());
    const min = pad(now.getMinutes());
    const ss = pad(now.getSeconds());
    return {
      day: `${yyyy}-${mm}-${dd}`,
      time: `${hh}-${min}-${ss}`,
    };
  }

  _listBackupSnapshotDirs() {
    return listBackupSnapshotDirs();
  }

  _buildInventorySnapshot() {
    const out = {};
    const profiles = (this.points && this.points.profiles) || {};
    for (const [user, profile] of Object.entries(profiles)) {
      const p = profile && typeof profile === "object" ? profile : {};
      const powerups = p.powerups && typeof p.powerups === "object" ? p.powerups : {};
      const stealCharges = Math.max(0, Math.floor(Number(powerups.stealCharges) || 0));
      const shieldBreakCharges = Math.max(0, Math.floor(Number(powerups.shieldBreakCharges) || 0));
      const jetLockCharges = Math.max(0, Math.floor(Number(powerups.jetLockCharges) || 0));
      if (stealCharges > 0 || shieldBreakCharges > 0 || jetLockCharges > 0) {
        out[user] = { stealCharges, shieldBreakCharges, jetLockCharges };
      }
    }
    return out;
  }

  _buildSuperFanSnapshot() {
    const out = {};
    const profiles = (this.points && this.points.profiles) || {};
    for (const [user, profile] of Object.entries(profiles)) {
      const p = profile && typeof profile === "object" ? profile : {};
      if (p.superFan !== true) continue;
      out[user] = {
        superFan: true,
        superFanLevel: Math.max(0, Math.floor(Number(p.superFanLevel) || 0)),
        superFanIcon: Math.floor(Number(p.superFanIcon) || -1),
        superFanWelcomeBonusGranted: p.superFanWelcomeBonusGranted === true,
        superFanDailyBonusDay: String(p.superFanDailyBonusDay || ""),
      };
    }
    return out;
  }

  createDataBackup(options = {}) {
    const keepLatest = Math.max(1, Math.floor(Number(options.keepLatest) || 12));
    ensureDataDir();
    this._recoverPointsFromBackupIfWiped();
    const liveUsers = countPointsUsers(this.points);
    const meta = readPointsMeta();
    if (
      meta &&
      meta.users >= MIN_USERS_GUARD &&
      liveUsers < Math.max(MIN_USERS_GUARD, Math.floor(meta.users * SHRINK_RATIO_GUARD))
    ) {
      console.error(
        `[Backup] Skipped snapshot: only ${liveUsers} users loaded (meta expects ~${meta.users}).`
      );
      return { ok: false, reason: "skipped_low_users", users: liveUsers, expectedUsers: meta.users };
    }
    if (!fs.existsSync(BACKUPS_DIR)) {
      fs.mkdirSync(BACKUPS_DIR, { recursive: true });
    }
    const stamp = this._snapshotStamp();
    const dayDir = path.join(BACKUPS_DIR, stamp.day);
    fs.mkdirSync(dayDir, { recursive: true });

    let backupDir = path.join(dayDir, stamp.time);
    let suffix = 1;
    while (fs.existsSync(backupDir)) {
      backupDir = path.join(dayDir, `${stamp.time}-${String(suffix).padStart(2, "0")}`);
      suffix += 1;
    }
    fs.mkdirSync(backupDir, { recursive: true });

    const pointsFileName = path.basename(PRIMARY_POINTS_FILE);
    const pointsOut = path.join(backupDir, pointsFileName);
    const shieldsOut = path.join(backupDir, "shields.json");
    const inventorySnapshotName = "inventories.snapshot.json";
    const superFanSnapshotName = "superfans.snapshot.json";
    const inventoriesOut = path.join(backupDir, inventorySnapshotName);
    const superfansOut = path.join(backupDir, superFanSnapshotName);
    const inventorySnapshot = this._buildInventorySnapshot();
    const superFanSnapshot = this._buildSuperFanSnapshot();
    fs.writeFileSync(pointsOut, JSON.stringify(this.points || {}, null, 2), "utf8");
    fs.writeFileSync(shieldsOut, JSON.stringify(this.shields || {}, null, 2), "utf8");
    fs.writeFileSync(inventoriesOut, JSON.stringify(inventorySnapshot, null, 2), "utf8");
    fs.writeFileSync(superfansOut, JSON.stringify(superFanSnapshot, null, 2), "utf8");

    const manifest = {
      createdAt: new Date().toISOString(),
      pointsFile: pointsFileName,
      shieldsFile: "shields.json",
      inventoriesFile: inventorySnapshotName,
      superfansFile: superFanSnapshotName,
      users: Object.keys((this.points && this.points.balances) || {}).length,
      profiles: Object.keys((this.points && this.points.profiles) || {}).length,
      shieldedUsers: Object.keys(this.shields || {}).length,
      usersWithInventory: Object.keys(inventorySnapshot).length,
      superFanUsers: Object.keys(superFanSnapshot).length,
      keepLatest,
    };
    fs.writeFileSync(path.join(backupDir, "manifest.json"), JSON.stringify(manifest, null, 2), "utf8");

    const snapshots = this._listBackupSnapshotDirs();
    const overflow = Math.max(0, snapshots.length - keepLatest);
    for (let i = 0; i < overflow; i += 1) {
      const victim = snapshots[i];
      fs.rmSync(victim, { recursive: true, force: true });
      const parent = path.dirname(victim);
      try {
        if (fs.existsSync(parent) && fs.readdirSync(parent).length === 0) {
          fs.rmdirSync(parent);
        }
      } catch {
        // Ignore cleanup errors for empty day folders.
      }
    }
    return { ok: true, backupDir, kept: Math.min(keepLatest, snapshots.length), deleted: overflow };
  }

  _pruneExpiredShields() {
    const now = Date.now();
    let changed = false;
    for (const [user, row] of Object.entries(this.shields)) {
      const until = Number(row && row.until) || 0;
      if (!until || until <= now) {
        delete this.shields[user];
        changed = true;
      }
    }
    if (changed) this._saveShields();
  }

  _ensureTaxPotState() {
    const now = Date.now();
    if (!this.points.taxPot || typeof this.points.taxPot !== "object") {
      this.points.taxPot = defaultTaxPotState(now);
      this._savePoints();
      return this.points.taxPot;
    }
    const startedAt = Math.max(0, Number(this.points.taxPot.periodStartedAt) || 0);
    if (!startedAt || now - startedAt >= TAX_POT_RESET_MS) {
      this.points.taxPot = defaultTaxPotState(now);
      this._savePoints();
    }
    this.points.taxPot.periodStartedAt = Math.max(0, Number(this.points.taxPot.periodStartedAt) || now);
    this.points.taxPot.dayKey = ukDayKey(this.points.taxPot.periodStartedAt);
    this.points.taxPot.amount = Math.max(0, Math.floor(Number(this.points.taxPot.amount) || 0));
    return this.points.taxPot;
  }

  getTaxPotResetInfo(nowMs = Date.now()) {
    const pot = this._ensureTaxPotState();
    const startedAt = Math.max(0, Number(pot.periodStartedAt) || nowMs);
    const resetAtMs = startedAt + TAX_POT_RESET_MS;
    return {
      timezone: "Europe/London",
      periodSeconds: Math.floor(TAX_POT_RESET_MS / 1000),
      periodStartedAt: startedAt,
      resetAtMs,
      secondsUntilReset: Math.max(0, Math.ceil((resetAtMs - nowMs) / 1000)),
    };
  }

  getTaxPotStatus() {
    const pot = this._ensureTaxPotState();
    const reset = this.getTaxPotResetInfo();
    return {
      dayKey: pot.dayKey,
      potAmount: Math.max(0, Math.floor(Number(pot.amount) || 0)),
      resetAtMs: reset.resetAtMs,
      secondsUntilReset: reset.secondsUntilReset,
      timezone: reset.timezone,
    };
  }

  addTaxToPot(amount) {
    const pot = this._ensureTaxPotState();
    const add = Math.max(0, Math.floor(Number(amount) || 0));
    if (add <= 0) {
      return this.getTaxPotStatus();
    }
    pot.amount = Math.max(0, Math.floor(Number(pot.amount) || 0) + add);
    pot.updatedAt = Date.now();
    this.points.taxPot = pot;
    this._savePoints();
    return this.getTaxPotStatus();
  }

  claimTaxPot(user, reason = "interstellar_claim") {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user", amount: 0 };
    this.ensureAccount(u);
    const pot = this._ensureTaxPotState();
    const amount = Math.max(0, Math.floor(Number(pot.amount) || 0));
    if (amount <= 0) {
      return { ok: false, reason: "pot_empty", user: u, claimedAmount: 0, ...this.getTaxPotStatus() };
    }
    this.credit(u, amount, { countAsEarned: true });
    pot.amount = 0;
    pot.updatedAt = Date.now();
    this.points.taxPot = pot;
    this._savePoints();
    this.sendInGameNotification(u, "tax_pot_claim", `Claimed tax pot: ${amount} pts via ${reason}.`);
    return { ok: true, reason, user: u, claimedAmount: amount, balance: this.getBalance(u), ...this.getTaxPotStatus() };
  }

  getBalance(user) {
    const u = normalizeUser(user);
    if (!u) return 0;
    if (this.points.balances[u] == null) return 0;
    return Math.floor(Number(this.points.balances[u]) || 0);
  }

  getAllTime(user) {
    const u = normalizeUser(user);
    if (!u) return 0;
    return Math.floor(Number(this.points.allTime[u]) || 0);
  }

  _ensureProfileShape(user) {
    const u = normalizeUser(user);
    if (!u) return null;
    const current = this.points.profiles[u] || {};
    const base = getDefaultProfile(u);
    const merged = {
      ...base,
      ...current,
      displayName: this._normalizeDisplayName(current.displayName, u),
      nameStyle: String(current.nameStyle || "none").toLowerCase(),
      nameBadge: resolveBadgeId(current.nameBadge || "none"),
      ownedBadges: (() => {
        let owned = normalizeOwnedBadges(current.ownedBadges);
        const active = resolveBadgeId(current.nameBadge || "none");
        if (active !== "none" && OWNABLE_NAME_BADGES.has(active) && !owned.includes(active)) {
          owned = [...owned, active];
        }
        return owned;
      })(),
      superFan: current.superFan === true,
      superFanLevel: Math.max(0, Math.floor(Number(current.superFanLevel) || 0)),
      superFanIcon: (() => {
        const idx = Math.floor(Number(current.superFanIcon));
        if (Number.isFinite(idx) && idx >= 0 && idx < SUPERFAN_ICON_COUNT) return idx;
        return -1;
      })(),
      superFanWelcomeBonusGranted: current.superFanWelcomeBonusGranted === true,
      superFanDailyBonusDay: String(current.superFanDailyBonusDay || ""),
      xp: Math.max(0, Math.floor(Number(current.xp) || 0)),
      level: Math.max(1, Math.floor(Number(current.level) || 1)),
      rank: String(current.rank || "Rookie"),
      dailyStreak: Math.max(0, Math.floor(Number(current.dailyStreak) || 0)),
      lastDailyClaimAt: Math.max(0, Number(current.lastDailyClaimAt) || 0),
      achievements: Array.isArray(current.achievements) ? current.achievements.slice(0, 200) : [],
      missionProgress:
        current.missionProgress && typeof current.missionProgress === "object"
          ? { ...current.missionProgress }
          : {},
      completedMissions: Array.isArray(current.completedMissions) ? current.completedMissions.slice(0, 200) : [],
      totalWagered: Math.max(0, Math.floor(Number(current.totalWagered) || 0)),
      highStakeBetCount: Math.max(0, Math.floor(Number(current.highStakeBetCount) || 0)),
      highStakeBonusClaims: Math.max(0, Math.floor(Number(current.highStakeBonusClaims) || 0)),
      totalRakebackClaimed: Math.max(0, Number(current.totalRakebackClaimed) || 0),
      challengeState: current.challengeState && typeof current.challengeState === "object" ? { ...current.challengeState } : null,
      challengeLog: Array.isArray(current.challengeLog) ? current.challengeLog.slice(-400) : [],
      powerups:
        current.powerups && typeof current.powerups === "object"
          ? {
              stealCharges: Math.max(0, Math.floor(Number(current.powerups.stealCharges) || 0)),
              shieldBreakCharges: Math.max(0, Math.floor(Number(current.powerups.shieldBreakCharges) || 0)),
              jetLockCharges: Math.max(0, Math.floor(Number(current.powerups.jetLockCharges) || 0)),
            }
          : { stealCharges: 0, shieldBreakCharges: 0, jetLockCharges: 0 },
    };
    merged.level = getLevelFromXp(merged.xp);
    merged.rank = getRankFromLevel(merged.level);
    const challengeChanged = this._ensureChallengeState(merged);
    this.points.profiles[u] = merged;
    if (challengeChanged) this._savePoints();
    return merged;
  }

  _powerupField(type) {
    const t = String(type || "").trim().toLowerCase();
    if (t === "steal" || t === "galaxy") return "stealCharges";
    if (t === "shield_break" || t === "car_drifting") return "shieldBreakCharges";
    if (t === "jet_lock" || t === "flying_jet") return "jetLockCharges";
    return "";
  }

  addPowerupCharges(user, type, amount) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    const field = this._powerupField(type);
    if (!field) return { ok: false, reason: "unknown_powerup" };
    const add = Math.max(1, Math.floor(Number(amount) || 0));
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    profile.powerups[field] = Math.max(0, Math.floor(Number(profile.powerups[field]) || 0) + add);
    this.points.profiles[u] = profile;
    this._savePoints();
    return {
      ok: true,
      user: u,
      type: field,
      added: add,
      count: profile.powerups[field],
      inventory: { ...profile.powerups },
    };
  }

  consumePowerupCharge(user, type, amount = 1) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    const field = this._powerupField(type);
    if (!field) return { ok: false, reason: "unknown_powerup" };
    const need = Math.max(1, Math.floor(Number(amount) || 1));
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    const current = Math.max(0, Math.floor(Number(profile.powerups[field]) || 0));
    if (current < need) {
      return { ok: false, reason: "no_charges", user: u, type: field, count: current };
    }
    profile.powerups[field] = current - need;
    this.points.profiles[u] = profile;
    this._savePoints();
    return {
      ok: true,
      user: u,
      type: field,
      consumed: need,
      count: profile.powerups[field],
      inventory: { ...profile.powerups },
    };
  }

  getPowerupInventory(user) {
    const u = normalizeUser(user);
    if (!u) return { stealCharges: 0, shieldBreakCharges: 0, jetLockCharges: 0 };
    this.ensureAccount(u);
    const p = this._ensureProfileShape(u);
    return {
      stealCharges: Math.max(0, Math.floor(Number(p.powerups?.stealCharges) || 0)),
      shieldBreakCharges: Math.max(0, Math.floor(Number(p.powerups?.shieldBreakCharges) || 0)),
      jetLockCharges: Math.max(0, Math.floor(Number(p.powerups?.jetLockCharges) || 0)),
    };
  }

  _challengeGoalFor(def, level) {
    return Math.max(
      1,
      Number(def.baseGoal || 0) +
        challengeStepForLevel(level, def.stepEveryLevels) * Number(def.stepGoal || 0)
    );
  }

  _emptyChallengeProgress() {
    return { plays: 0, likes: 0, giftCoins: 0 };
  }

  _emptyChallengeCompleted() {
    return { plays: false, likes: false, giftCoins: false, allCompleteRewardClaimed: false };
  }

  _buildChallengeGoals(level) {
    const goals = {};
    for (const def of DAILY_CHALLENGE_DEFS) {
      goals[def.key] = this._challengeGoalFor(def, level);
    }
    return goals;
  }

  _ensureChallengeState(profile) {
    const dayKey = ukDayKey();
    let changed = false;
    if (!profile.challengeState || typeof profile.challengeState !== "object") {
      profile.challengeState = {
        dayKey,
        carry: this._emptyChallengeProgress(),
        today: this._emptyChallengeProgress(),
        goals: this._buildChallengeGoals(profile.level),
        completed: this._emptyChallengeCompleted(),
      };
      return true;
    }

    profile.challengeState.carry =
      profile.challengeState.carry && typeof profile.challengeState.carry === "object"
        ? { ...this._emptyChallengeProgress(), ...profile.challengeState.carry }
        : this._emptyChallengeProgress();
    profile.challengeState.today =
      profile.challengeState.today && typeof profile.challengeState.today === "object"
        ? { ...this._emptyChallengeProgress(), ...profile.challengeState.today }
        : this._emptyChallengeProgress();
    profile.challengeState.completed =
      profile.challengeState.completed && typeof profile.challengeState.completed === "object"
        ? { ...this._emptyChallengeCompleted(), ...profile.challengeState.completed }
        : this._emptyChallengeCompleted();
    profile.challengeState.goals =
      profile.challengeState.goals && typeof profile.challengeState.goals === "object"
        ? { ...this._buildChallengeGoals(profile.level), ...profile.challengeState.goals }
        : this._buildChallengeGoals(profile.level);

    if (profile.challengeState.dayKey !== dayKey) {
      this._rollChallengeDay(profile, dayKey);
      changed = true;
    }
    return changed;
  }

  _rollChallengeDay(profile, nextDayKey = ukDayKey()) {
    const state = profile.challengeState || {
      dayKey: nextDayKey,
      carry: this._emptyChallengeProgress(),
      today: this._emptyChallengeProgress(),
      goals: this._buildChallengeGoals(profile.level),
      completed: this._emptyChallengeCompleted(),
    };

    const totals = this._emptyChallengeProgress();
    const carryOut = this._emptyChallengeProgress();
    const completed = this._emptyChallengeCompleted();

    for (const def of DAILY_CHALLENGE_DEFS) {
      const key = def.key;
      const total = Math.max(0, Number(state.carry[key] || 0) + Number(state.today[key] || 0));
      const goal = Math.max(1, Number(state.goals[key] || this._challengeGoalFor(def, profile.level)));
      totals[key] = total;
      completed[key] = total >= goal;
      carryOut[key] = completed[key] ? Math.max(0, total - goal) : 0;
    }

    profile.challengeLog.push({
      dayKey: state.dayKey,
      level: profile.level,
      goals: { ...state.goals },
      totals,
      completed,
      carryOut,
      closedAt: Date.now(),
    });
    if (profile.challengeLog.length > 400) {
      profile.challengeLog = profile.challengeLog.slice(-400);
    }

    profile.challengeState = {
      dayKey: nextDayKey,
      carry: carryOut,
      today: this._emptyChallengeProgress(),
      goals: this._buildChallengeGoals(profile.level),
      completed: this._emptyChallengeCompleted(),
    };
  }

  _normalizeDisplayName(name, fallback = "") {
    const cleaned = String(name || "").replace(/\s+/g, " ").trim().slice(0, 40);
    if (cleaned) return cleaned;
    return String(fallback || "").replace(/^@+/, "").slice(0, 40);
  }

  _profileDisplayAliases(profile) {
    const list = Array.isArray(profile?.displayAliases) ? profile.displayAliases : [];
    return list
      .map((entry) => String(entry || "").replace(/\s+/g, " ").trim().slice(0, 40))
      .filter(Boolean)
      .slice(-50);
  }

  _displayMatchesProfile(profile, key) {
    if (!profile || !key) return false;
    if (normalizeDisplayKey(profile.displayName) === key) return true;
    const aliases = this._profileDisplayAliases(profile);
    for (const alias of aliases) {
      if (normalizeDisplayKey(alias) === key) return true;
    }
    return false;
  }

  _findUsersByDisplayName(displayName) {
    const key = normalizeDisplayKey(displayName);
    if (!key) return [];
    const out = [];
    for (const [user, profile] of Object.entries(this.points.profiles || {})) {
      if (!profile || typeof profile !== "object") continue;
      if (this._displayMatchesProfile(profile, key)) out.push(user);
    }
    return out;
  }

  _canAutoRestoreInto(user) {
    const bal = Math.max(0, this.getBalance(user));
    const all = Math.max(0, this.getAllTime(user));
    const profile = this.points.profiles[user];
    if (!profile || typeof profile !== "object") return bal <= this.defaultStarter && all === 0;
    const lowRiskProgress =
      Math.max(0, Math.floor(Number(profile.xp) || 0)) === 0 &&
      Math.max(0, Math.floor(Number(profile.totalWagered) || 0)) === 0 &&
      (!Array.isArray(profile.achievements) || profile.achievements.length === 0) &&
      (!Array.isArray(profile.challengeLog) || profile.challengeLog.length === 0) &&
      (!Array.isArray(profile.completedMissions) || profile.completedMissions.length === 0);
    return bal <= this.defaultStarter && all === 0 && lowRiskProgress;
  }

  _mergeUserAccount(fromUser, toUser, reason = "display_name_restore") {
    const from = normalizeUser(fromUser);
    const to = normalizeUser(toUser);
    if (!from || !to || from === to) return { ok: false, reason: "invalid_merge" };
    const fromBalance = Math.max(0, this.getBalance(from));
    const fromAllTime = Math.max(0, this.getAllTime(from));
    if (fromBalance <= 0 && fromAllTime <= 0 && !this.points.profiles[from]) {
      return { ok: false, reason: "source_empty" };
    }

    const toProfile = this._ensureProfileShape(to);
    const fromProfile = this._ensureProfileShape(from);
    const mergedAliases = [...this._profileDisplayAliases(toProfile), ...this._profileDisplayAliases(fromProfile)];
    if (fromProfile.displayName) mergedAliases.push(fromProfile.displayName);
    if (toProfile.displayName) mergedAliases.push(toProfile.displayName);

    this.points.balances[to] = Math.max(Math.max(0, this.getBalance(to)), fromBalance);
    this.points.allTime[to] = Math.max(Math.max(0, this.getAllTime(to)), fromAllTime);
    this.points.profiles[to] = {
      ...fromProfile,
      ...toProfile,
      displayAliases: [...new Set(mergedAliases)].slice(-50),
      lastRestoredFrom: from,
      lastRestoreReason: reason,
      lastRestoredAt: Date.now(),
    };

    const fromShield = this.shields[from];
    const toShield = this.shields[to];
    const fromUntil = Number(fromShield && fromShield.until) || 0;
    const toUntil = Number(toShield && toShield.until) || 0;
    if (fromUntil > toUntil) {
      this.shields[to] = { ...fromShield };
    }

    delete this.points.balances[from];
    delete this.points.allTime[from];
    delete this.points.profiles[from];
    delete this.shields[from];
    this._savePoints();
    this._saveShields();
    return { ok: true, from, to, restoredBalance: fromBalance, restoredAllTime: fromAllTime };
  }

  _attemptAutoRestoreByDisplayName(user, displayName) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    const key = normalizeDisplayKey(displayName);
    if (!key) return { ok: false, reason: "empty_display" };
    if (!this._canAutoRestoreInto(u)) return { ok: false, reason: "target_not_fresh" };

    const candidates = this._findUsersByDisplayName(displayName)
      .filter((candidate) => normalizeUser(candidate) !== u)
      .map((candidate) => ({
        user: candidate,
        score: Math.max(this.getBalance(candidate), this.getAllTime(candidate)),
      }))
      .sort((a, b) => b.score - a.score);
    if (!candidates.length) return { ok: false, reason: "no_match" };

    const best = candidates[0];
    if (best.score <= 0) return { ok: false, reason: "match_empty" };
    return this._mergeUserAccount(best.user, u, "display_name_rejoin");
  }

  setDisplayName(user, displayName) {
    const u = normalizeUser(user);
    if (!u) return;
    this.ensureAccount(u);
    this._attemptAutoRestoreByDisplayName(u, displayName);
    this.ensureAccount(u);
    const next = this._normalizeDisplayName(displayName, u);
    const cur = this.points.profiles[u] || {};
    const aliases = this._profileDisplayAliases(cur);
    if (cur.displayName && cur.displayName !== next) aliases.push(cur.displayName);
    if (next) aliases.push(next);
    if (cur.displayName === next && JSON.stringify(this._profileDisplayAliases(cur)) === JSON.stringify([...new Set(aliases)].slice(-50))) return;
    this.points.profiles[u] = {
      ...cur,
      displayName: next,
      displayAliases: [...new Set(aliases)].slice(-50),
    };
    this._savePoints();
  }

  setNameStyle(user, styleId) {
    const u = normalizeUser(user);
    if (!u) return;
    this.ensureAccount(u);
    const style = String(styleId || "none").trim().toLowerCase();
    const cur = this.points.profiles[u] || {};
    if (cur.nameStyle === style) return;
    this.points.profiles[u] = { ...cur, nameStyle: style };
    this._savePoints();
  }

  setNameBadge(user, badgeId) {
    const u = normalizeUser(user);
    if (!u) return;
    this.ensureAccount(u);
    const badge = resolveBadgeId(badgeId || "none");
    const profile = this._ensureProfileShape(u);
    if (profile.nameBadge === badge) return;
    profile.nameBadge = badge;
    this.points.profiles[u] = profile;
    this._savePoints();
  }

  getOwnedBadges(user) {
    const u = normalizeUser(user);
    if (!u) return [];
    return normalizeOwnedBadges(this._ensureProfileShape(u).ownedBadges);
  }

  ownsNameBadge(user, badgeId) {
    const id = resolveBadgeId(badgeId);
    if (!OWNABLE_NAME_BADGES.has(id)) return false;
    return this.getOwnedBadges(user).includes(id);
  }

  addOwnedNameBadge(user, badgeId) {
    const u = normalizeUser(user);
    if (!u) return false;
    const id = resolveBadgeId(badgeId);
    if (!OWNABLE_NAME_BADGES.has(id)) return false;
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    if (profile.ownedBadges.includes(id)) return false;
    profile.ownedBadges = [...profile.ownedBadges, id];
    this.points.profiles[u] = profile;
    this._savePoints();
    return true;
  }

  removeOwnedNameBadge(user, badgeId) {
    const u = normalizeUser(user);
    if (!u) return false;
    const id = resolveBadgeId(badgeId);
    if (!OWNABLE_NAME_BADGES.has(id)) return false;
    const out = this.revokeNameBadge(u, id);
    return !!(out && out.ok);
  }

  /** Unequip and remove ownership in one save (used by !sellcrown). */
  revokeNameBadge(user, badgeId) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    const id = resolveBadgeId(badgeId);
    if (!OWNABLE_NAME_BADGES.has(id)) return { ok: false, reason: "invalid_badge" };
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    const hadEquipped = profile.nameBadge === id;
    const hadOwned = Array.isArray(profile.ownedBadges) && profile.ownedBadges.includes(id);
    if (!hadEquipped && !hadOwned) return { ok: false, reason: "not_owned" };
    profile.ownedBadges = (profile.ownedBadges || []).filter((b) => b !== id);
    if (hadEquipped) profile.nameBadge = "none";
    this.points.profiles[u] = profile;
    this._savePoints();
    return { ok: true, hadEquipped, hadOwned, nameBadge: profile.nameBadge, ownedBadges: [...profile.ownedBadges] };
  }

  getDisplayName(user) {
    const u = normalizeUser(user);
    if (!u) return "";
    const row = this.points.profiles[u];
    const display = row && typeof row.displayName === "string" ? row.displayName : "";
    const baseName = this._normalizeDisplayName(display, u);
    return baseName;
  }

  getNameStyle(user) {
    const u = normalizeUser(user);
    if (!u) return "none";
    const row = this.points.profiles[u];
    const style = row && typeof row.nameStyle === "string" ? row.nameStyle : "none";
    return style || "none";
  }

  getNameBadge(user) {
    const u = normalizeUser(user);
    if (!u) return "none";
    const profile = this._ensureProfileShape(u);
    return profile ? profile.nameBadge || "none" : "none";
  }

  isSuperFan(user) {
    const u = normalizeUser(user);
    if (!u) return false;
    const row = this.points.profiles[u];
    return !!(row && row.superFan === true);
  }

  getSuperFanLevel(user) {
    const u = normalizeUser(user);
    if (!u) return 0;
    const row = this.points.profiles[u];
    return Math.max(0, Math.floor(Number(row && row.superFanLevel) || 0));
  }

  getSuperFanIcon(user) {
    const u = normalizeUser(user);
    if (!u) return -1;
    const row = this.points.profiles[u];
    const idx = Math.floor(Number(row && row.superFanIcon));
    if (Number.isFinite(idx) && idx >= 0 && idx < SUPERFAN_ICON_COUNT) return idx;
    return -1;
  }

  _superFanHash(user) {
    const key = String(user || "").toLowerCase();
    let h = 2166136261;
    for (let i = 0; i < key.length; i += 1) {
      h ^= key.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0) || 1;
  }

  _pickSuperFanIcon(user) {
    const u = normalizeUser(user);
    if (!u) return -1;
    const current = this.getSuperFanIcon(u);
    if (current >= 0) return current;
    const used = new Set();
    for (const [name, row] of Object.entries(this.points.profiles || {})) {
      if (normalizeUser(name) === u) continue;
      const idx = Math.floor(Number(row && row.superFanIcon));
      if (Number.isFinite(idx) && idx >= 0 && idx < SUPERFAN_ICON_COUNT) {
        used.add(idx);
      }
    }
    const base = this._superFanHash(u) % SUPERFAN_ICON_COUNT;
    for (let i = 0; i < SUPERFAN_ICON_COUNT; i += 1) {
      const idx = (base + i) % SUPERFAN_ICON_COUNT;
      if (!used.has(idx)) return idx;
    }
    return base;
  }

  setSuperFan(user, active = true, level = 0) {
    const u = normalizeUser(user);
    if (!u) return;
    this.ensureAccount(u);
    const cur = this.points.profiles[u] || {};
    const next = active === true;
    const lvl = Math.max(0, Math.floor(Number(level) || 0));
    const nextLevel = next ? Math.max(Math.floor(Number(cur.superFanLevel) || 0), lvl) : 0;
    const shouldGrantWelcomeBonus = next && !cur.superFan && cur.superFanWelcomeBonusGranted !== true;
    const nextIcon = (() => {
      const curIdx = Math.floor(Number(cur.superFanIcon));
      if (Number.isFinite(curIdx) && curIdx >= 0 && curIdx < SUPERFAN_ICON_COUNT) return curIdx;
      return this._pickSuperFanIcon(u);
    })();
    if (
      !!cur.superFan === next &&
      Math.floor(Number(cur.superFanLevel) || 0) === nextLevel &&
      Math.floor(Number(cur.superFanIcon) || -1) === nextIcon &&
      (!shouldGrantWelcomeBonus || cur.superFanWelcomeBonusGranted === true)
    )
      return;
    this.points.profiles[u] = {
      ...cur,
      superFan: next,
      superFanLevel: nextLevel,
      superFanIcon: nextIcon,
      superFanWelcomeBonusGranted: cur.superFanWelcomeBonusGranted === true || shouldGrantWelcomeBonus,
    };
    if (shouldGrantWelcomeBonus) {
      const bonus = SUPERFAN_FIRST_ACTIVATION_BONUS_POINTS;
      this.points.balances[u] = Math.max(0, this.getBalance(u) + bonus);
      this.points.allTime[u] = Math.max(0, this.getAllTime(u) + bonus);
      this.sendInGameNotification(u, "superfan_welcome_bonus", `Superfan unlocked: +${bonus.toLocaleString()} pts`);
    }
    this._savePoints();
  }

  applySuperFanDailyBonus(user) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user", amount: 0 };
    if (this.points.balances[u] == null) this.points.balances[u] = this.defaultStarter;
    if (this.points.allTime[u] == null) this.points.allTime[u] = 0;
    if (this.points.profiles[u] == null) this.points.profiles[u] = getDefaultProfile(u);
    const profile = this._ensureProfileShape(u);
    if (!profile.superFan) return { ok: false, reason: "not_superfan", amount: 0 };
    const day = ukDayKey();
    if (String(profile.superFanDailyBonusDay || "") === day) {
      return { ok: false, reason: "already_awarded_today", amount: 0, balance: this.getBalance(u) };
    }
    const amount = SUPERFAN_DAILY_BONUS_POINTS;
    this.points.balances[u] = Math.max(0, this.getBalance(u) + amount);
    this.points.allTime[u] = Math.max(0, this.getAllTime(u) + amount);
    profile.superFanDailyBonusDay = day;
    this.points.profiles[u] = profile;
    this._savePoints();
    this.sendInGameNotification(u, "superfan_daily_bonus", `Superfan daily bonus +${amount.toLocaleString()} pts`);
    return { ok: true, user: u, amount, balance: this.getBalance(u), dayKey: day };
  }

  getUserPresentation(user) {
    const u = normalizeUser(user);
    if (!u) {
      return { user: "", displayName: "", nameStyle: "none", nameBadge: "none" };
    }
    return {
      user: u,
      displayName: this.getDisplayName(u),
      nameStyle: this.getNameStyle(u),
      nameBadge: this.getNameBadge(u),
      ownedBadges: this.getOwnedBadges(u),
      superFan: this.isSuperFan(u),
      superFanLevel: this.getSuperFanLevel(u),
      superFanIcon: this.getSuperFanIcon(u),
      level: this.getLevel(u),
      rank: this.getRank(u),
    };
  }

  ensureAccount(user) {
    const u = normalizeUser(user);
    if (!u) return 0;
    if (this.points.balances[u] == null) {
      this.points.balances[u] = this.defaultStarter;
      if (this.points.allTime[u] == null) {
        this.points.allTime[u] = 0;
      }
      if (this.points.profiles[u] == null) {
        this.points.profiles[u] = getDefaultProfile(u);
      }
      this._savePoints();
    } else if (this.points.allTime[u] == null || this.points.profiles[u] == null) {
      if (this.points.allTime[u] == null) this.points.allTime[u] = 0;
      if (this.points.profiles[u] == null) {
        this.points.profiles[u] = getDefaultProfile(u);
      }
      this._savePoints();
    }
    this._ensureProfileShape(u);
    this.applySuperFanDailyBonus(u);
    return this.getBalance(u);
  }

  getLevel(user) {
    const u = normalizeUser(user);
    if (!u) return 1;
    this.ensureAccount(u);
    return this._ensureProfileShape(u).level;
  }

  getRank(user) {
    const u = normalizeUser(user);
    if (!u) return "Rookie";
    this.ensureAccount(u);
    return this._ensureProfileShape(u).rank;
  }

  updateRank(user) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    const prev = profile.rank;
    const next = getRankFromLevel(profile.level);
    profile.rank = next;
    this.points.profiles[u] = profile;
    this._savePoints();
    if (prev !== next) {
      this.sendInGameNotification(u, "rank_update", `Rank updated: ${prev} -> ${next}`);
    }
    return { ok: true, user: u, previousRank: prev, rank: next };
  }

  awardXP(user, action, amountMultiplier = 1) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    const base = XP_ACTION_VALUES[action] || 5;
    const gain = Math.max(1, Math.floor(base * Math.max(0.1, Number(amountMultiplier) || 1)));
    const oldLevel = profile.level;
    profile.xp = Math.max(0, Math.floor(profile.xp + gain));
    profile.level = getLevelFromXp(profile.xp);
    this.points.profiles[u] = profile;
    this._savePoints();
    this.updateRank(u);
    if (profile.level > oldLevel) {
      this.sendInGameNotification(u, "level_up", `Level up! Lv.${oldLevel} -> Lv.${profile.level}`);
    }
    if (profile.level >= 10) {
      this.grantAchievement(u, "level_10");
    }
    return { ok: true, user: u, action, gain, xp: profile.xp, level: profile.level };
  }

  grantLevelBoost(user, levels, reason = "daily_challenge_mastery") {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    const boostLevels = Math.max(1, Math.floor(Number(levels) || 1));
    const fromLevel = profile.level;
    const targetLevel = Math.max(fromLevel + 1, fromLevel + boostLevels);
    const targetXp = xpNeededForLevel(targetLevel);
    profile.xp = Math.max(profile.xp, targetXp);
    profile.level = getLevelFromXp(profile.xp);
    this.points.profiles[u] = profile;
    this._savePoints();
    this.updateRank(u);
    if (profile.level > fromLevel) {
      this.sendInGameNotification(
        u,
        "level_boost",
        `Daily challenge mastery: +${profile.level - fromLevel} level(s) (${reason}).`
      );
    }
    if (profile.level >= 10) {
      this.grantAchievement(u, "level_10");
    }
    return { ok: true, user: u, fromLevel, toLevel: profile.level };
  }

  claimDailyBonus(user) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    const today = ukDayKey();
    const last = profile.lastDailyClaimAt ? ukDayKey(profile.lastDailyClaimAt) : "";
    if (last === today) {
      return { ok: false, reason: "already_claimed", user: u, dailyStreak: profile.dailyStreak };
    }
    const yesterday = new Date();
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const yesterdayKey = ukDayKey(yesterday.getTime());
    profile.dailyStreak = last === yesterdayKey ? profile.dailyStreak + 1 : 1;
    profile.lastDailyClaimAt = Date.now();
    this.points.profiles[u] = profile;
    this._savePoints();
    this.awardXP(u, "DAILY_LOGIN", 1 + Math.min(7, profile.dailyStreak) * 0.05);
    if (profile.dailyStreak >= 7) this.grantAchievement(u, "week_streak");
    this.sendInGameNotification(u, "daily_bonus", `Daily bonus claimed. Streak: ${profile.dailyStreak} day(s).`);
    return { ok: true, user: u, dailyStreak: profile.dailyStreak };
  }

  grantAchievement(user, achievementKey) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    this.ensureAccount(u);
    const meta = ACHIEVEMENTS[achievementKey];
    if (!meta) return { ok: false, reason: "achievement_unknown", achievementKey };
    const profile = this._ensureProfileShape(u);
    if (profile.achievements.includes(achievementKey)) {
      return { ok: false, reason: "already_granted", achievementKey };
    }
    profile.achievements.push(achievementKey);
    this.points.profiles[u] = profile;
    this._savePoints();
    this.awardXP(u, "ACHIEVEMENT_UNLOCKED", meta.xpReward / XP_ACTION_VALUES.ACHIEVEMENT_UNLOCKED);
    this.sendInGameNotification(u, "achievement", `Achievement unlocked: ${meta.title}`);
    return { ok: true, user: u, achievementKey };
  }

  recordMissionProgress(user, eventType, value = 1) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    this._ensureChallengeState(profile);
    const metricKey = CHALLENGE_EVENT_TO_KEY[eventType];
    if (!metricKey) {
      return { ok: false, reason: "event_not_tracked" };
    }
    const add = Math.max(1, Number(value) || 1);
    profile.challengeState.today[metricKey] = Math.max(
      0,
      Number(profile.challengeState.today[metricKey] || 0) + add
    );

    const completedNow = [];
    for (const def of DAILY_CHALLENGE_DEFS) {
      const key = def.key;
      const total =
        Math.max(0, Number(profile.challengeState.carry[key] || 0)) +
        Math.max(0, Number(profile.challengeState.today[key] || 0));
      if (total >= Number(profile.challengeState.goals[key] || 1) && !profile.challengeState.completed[key]) {
        profile.challengeState.completed[key] = true;
        completedNow.push(def);
      }
    }
    this.points.profiles[u] = profile;
    this._savePoints();
    for (const challenge of completedNow) {
      this.awardXP(
        u,
        "MISSION_COMPLETED",
        Number(challenge.xpReward || 0) / XP_ACTION_VALUES.MISSION_COMPLETED
      );
      this.sendInGameNotification(u, "mission_complete", `Daily challenge complete: ${challenge.title}`);
    }
    const allCompletedToday = DAILY_CHALLENGE_DEFS.every(
      (def) => profile.challengeState.completed[def.key] === true
    );
    if (allCompletedToday && !profile.challengeState.completed.allCompleteRewardClaimed) {
      profile.challengeState.completed.allCompleteRewardClaimed = true;
      this.points.profiles[u] = profile;
      this._savePoints();
      const levelBoost = challengeCompletionLevelBoost(profile.level);
      this.grantLevelBoost(u, levelBoost, "all_daily_targets_hit");
      this.awardXP(u, "MISSION_COMPLETED", 4.5);
      this.sendInGameNotification(
        u,
        "daily_challenge_mastery",
        `All daily targets complete: massive level boost awarded (+${levelBoost} levels).`
      );
    }
    const missions = this.getEconomyProfile(u)?.missions || [];
    return {
      ok: true,
      user: u,
      completed: completedNow.map((m) => m.id),
      missionProgress: missions,
    };
  }

  addWagerVolume(user, amount) {
    const u = normalizeUser(user);
    if (!u) return 0;
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    profile.totalWagered = Math.max(0, Math.floor(profile.totalWagered + Math.max(0, Number(amount) || 0)));
    this.points.profiles[u] = profile;
    this._savePoints();
    return profile.totalWagered;
  }

  trackHighStakeBet(user, amount) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user", bonusAwarded: 0 };
    const wager = Math.max(0, Math.floor(Number(amount) || 0));
    if (wager < HIGH_STAKE_BET_THRESHOLD) {
      return {
        ok: true,
        user: u,
        qualifies: false,
        highStakeBetCount: Math.max(0, Math.floor(Number(this.points.profiles?.[u]?.highStakeBetCount) || 0)),
        bonusAwarded: 0,
        remainingForNextBonus: 0,
      };
    }

    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    profile.highStakeBetCount = Math.max(0, Math.floor(Number(profile.highStakeBetCount) || 0) + 1);
    let bonusAwarded = 0;
    if (profile.highStakeBetCount % HIGH_STAKE_BET_BONUS_EVERY === 0) {
      bonusAwarded = HIGH_STAKE_BET_BONUS_POINTS;
      profile.highStakeBonusClaims = Math.max(0, Math.floor(Number(profile.highStakeBonusClaims) || 0) + 1);
    }
    this.points.profiles[u] = profile;
    this._savePoints();

    if (bonusAwarded > 0) {
      this.credit(u, bonusAwarded, { countAsEarned: true });
      this.sendInGameNotification(
        u,
        "high_stake_loyalty_bonus",
        `Regular high-stake reward: +${bonusAwarded.toLocaleString()} pts (every ${HIGH_STAKE_BET_BONUS_EVERY} bets >= ${HIGH_STAKE_BET_THRESHOLD}).`
      );
    }

    const progressInCycle = profile.highStakeBetCount % HIGH_STAKE_BET_BONUS_EVERY;
    const remaining = progressInCycle === 0 ? HIGH_STAKE_BET_BONUS_EVERY : HIGH_STAKE_BET_BONUS_EVERY - progressInCycle;
    return {
      ok: true,
      user: u,
      qualifies: true,
      highStakeBetCount: profile.highStakeBetCount,
      highStakeBonusClaims: profile.highStakeBonusClaims,
      bonusAwarded,
      remainingForNextBonus: remaining,
    };
  }

  computeRakeback(user, period = "daily") {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    this.ensureAccount(u);
    const profile = this._ensureProfileShape(u);
    const factor = period === "weekly" ? 1 : 0.35;
    const payout = Number((profile.totalWagered * getRakebackRate(profile.rank) * factor).toFixed(2));
    if (payout <= 0) {
      return { ok: true, user: u, payout: 0, balance: this.getBalance(u), period };
    }
    profile.totalWagered = 0;
    profile.totalRakebackClaimed = Number((profile.totalRakebackClaimed + payout).toFixed(2));
    this.points.profiles[u] = profile;
    this.credit(u, Math.floor(payout), { countAsEarned: true });
    this._savePoints();
    this.sendInGameNotification(u, "rakeback", `Rakeback credited: ${payout.toFixed(2)} pts`);
    return { ok: true, user: u, payout, balance: this.getBalance(u), period };
  }

  sendInGameNotification(user, messageKey, message) {
    const u = normalizeUser(user);
    if (!u) return null;
    if (!Array.isArray(this.points.notifications)) this.points.notifications = [];
    const note = {
      id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      user: u,
      level: this.getLevel(u),
      rank: this.getRank(u),
      messageKey: String(messageKey || "info"),
      message: String(message || "").slice(0, 180),
      ts: Date.now(),
    };
    this.points.notifications.push(note);
    if (this.points.notifications.length > 250) {
      this.points.notifications = this.points.notifications.slice(-250);
    }
    this._savePoints();
    return note;
  }

  getNotifications(limit = 40) {
    const safeLimit = Math.max(1, Math.min(250, Number(limit) || 40));
    const all = Array.isArray(this.points.notifications) ? this.points.notifications : [];
    return all.slice(-safeLimit).reverse();
  }

  getMissionDefinitions() {
    return DAILY_CHALLENGE_DEFS.map((mission) => ({
      id: mission.id,
      title: mission.title,
      target: mission.baseGoal,
      xpReward: mission.xpReward,
      scalesWithLevel: true,
    }));
  }

  getMissionResetInfo(nowMs = Date.now()) {
    const resetAtMs = nextUkMidnightMs(nowMs);
    return {
      timezone: "Europe/London",
      dayKey: ukDayKey(nowMs),
      resetAtMs,
      secondsUntilReset: Math.max(0, Math.ceil((resetAtMs - nowMs) / 1000)),
    };
  }

  getEconomyProfile(user) {
    const u = normalizeUser(user);
    if (!u) return null;
    this.ensureAccount(u);
    const p = this._ensureProfileShape(u);
    this._ensureChallengeState(p);
    const missions = DAILY_CHALLENGE_DEFS.map((mission) => {
      const key = mission.key;
      const progress =
        Math.max(0, Number(p.challengeState.carry[key] || 0)) +
        Math.max(0, Number(p.challengeState.today[key] || 0));
      const target = Math.max(1, Number(p.challengeState.goals[key] || this._challengeGoalFor(mission, p.level)));
      return {
        id: mission.id,
        title: mission.title,
        key,
        target,
        progress,
        remaining: Math.max(0, target - progress),
        completed: !!p.challengeState.completed[key],
      };
    });
    return {
      user: u,
      displayName: p.displayName,
      nameStyle: p.nameStyle,
      xp: p.xp,
      level: p.level,
      rank: p.rank,
      dailyStreak: p.dailyStreak,
      achievements: [...p.achievements],
      totalWagered: p.totalWagered,
      totalRakebackClaimed: p.totalRakebackClaimed,
      missions,
      challengeDay: p.challengeState.dayKey,
      challengeLog: [...p.challengeLog],
      powerups: this.getPowerupInventory(u),
    };
  }

  setBalance(user, amount) {
    const u = normalizeUser(user);
    if (!u) return;
    this.ensureAccount(u);
    this.points.balances[u] = Math.max(0, Math.floor(Number(amount) || 0));
    this._savePoints();
  }

  add(user, delta, options = {}) {
    const countAsEarned = options.countAsEarned !== false;
    const u = normalizeUser(user);
    if (!u) return 0;
    this.ensureAccount(u);
    const cur = this.getBalance(u);
    const next = Math.max(0, cur + Math.floor(delta));
    this.points.balances[u] = next;
    if (countAsEarned && delta > 0) {
      this.points.allTime[u] = Math.max(0, this.getAllTime(u) + Math.floor(delta));
    }
    this._savePoints();
    return next;
  }

  /** Returns { ok, balance } */
  tryDebit(user, amount) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, balance: 0, reason: "invalid_user" };
    const amt = Math.floor(Number(amount) || 0);
    if (amt <= 0) return { ok: false, balance: this.getBalance(u), reason: "bad_amount" };
    const cur = this.getBalance(u);
    if (cur < amt) return { ok: false, balance: cur, reason: "insufficient" };
    this.points.balances[u] = cur - amt;
    this._savePoints();
    return { ok: true, balance: this.points.balances[u] };
  }

  credit(user, amount, options = {}) {
    return this.add(user, Math.floor(Number(amount) || 0), options);
  }

  transferAllPoints(fromUser, toUser) {
    const from = normalizeUser(fromUser);
    const to = normalizeUser(toUser);
    if (!from || !to || from === to) {
      return { ok: false, reason: "invalid_transfer", amount: 0 };
    }
    this.ensureAccount(from);
    this.ensureAccount(to);
    const amount = this.getBalance(from);
    if (amount <= 0) {
      return { ok: false, reason: "empty_target", amount: 0 };
    }
    this.points.balances[from] = 0;
    this.points.balances[to] = this.getBalance(to) + amount;
    this.points.allTime[to] = this.getAllTime(to) + amount;
    this._savePoints();
    return {
      ok: true,
      amount,
      from,
      to,
      fromBalance: 0,
      toBalance: this.points.balances[to],
    };
  }

  shieldUser(user, durationMs, reason = "gift") {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    const ms = Math.max(0, Math.floor(Number(durationMs) || 0));
    if (ms <= 0) return { ok: false, reason: "bad_duration" };
    const now = Date.now();
    const currentUntil = Math.max(0, Number(this.shields[u]?.until) || 0);
    const baseUntil = Math.max(now, currentUntil);
    const until = baseUntil + ms;
    this.shields[u] = { ...this.shields[u], until, reason };
    this._saveShields();
    return {
      ok: true,
      user: u,
      shieldUntil: until,
      msAdded: ms,
      msLeft: Math.max(0, until - now),
      previousMsLeft: Math.max(0, currentUntil - now),
    };
  }

  breakShield(user, reason = "car_drifting_break", reduceMs = SHIELD_UNIT_MS) {
    const u = normalizeUser(user);
    if (!u) return { ok: false, reason: "invalid_user" };
    this._pruneExpiredShields();
    const existing = this.shields[u];
    if (!existing) {
      return { ok: false, reason: "no_active_shield", user: u };
    }
    const now = Date.now();
    const shieldUntil = Number(existing.until) || 0;
    const shieldMsBefore = Math.max(0, shieldUntil - now);
    const reduction = Math.max(1, Math.floor(Number(reduceMs) || SHIELD_UNIT_MS));
    const reducedMs = Math.min(shieldMsBefore, reduction);
    const nextUntil = shieldUntil - reducedMs;
    const fullyBroken = nextUntil <= now;
    if (fullyBroken) {
      delete this.shields[u];
    } else {
      this.shields[u] = { ...existing, until: nextUntil };
    }
    this._saveShields();
    return {
      ok: true,
      user: u,
      reason,
      reducedMs,
      shieldMsBefore,
      shieldMsLeft: Math.max(0, nextUntil - now),
      shieldUntil: fullyBroken ? 0 : nextUntil,
      fullyBroken,
    };
  }

  getShieldStatus(user) {
    const u = normalizeUser(user);
    if (!u) return { active: false, msLeft: 0, shieldUntil: 0 };
    this._pruneExpiredShields();
    const row = this.shields[u];
    if (!row) return { active: false, msLeft: 0, shieldUntil: 0 };
    const shieldUntil = Number(row.until) || 0;
    const msLeft = Math.max(0, shieldUntil - Date.now());
    if (msLeft <= 0) return { active: false, msLeft: 0, shieldUntil: 0 };
    return { active: true, msLeft, shieldUntil, reason: row.reason || null };
  }

  snapshotTop(limit = 15) {
    const entries = Object.entries(this.points.balances)
      .map(([name, v]) => [name, Math.floor(Number(v) || 0)])
      .filter(([, v]) => v > 0)
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit);
    return entries.map(([name, balance]) => {
      const shield = this.getShieldStatus(name);
      const p = this.getUserPresentation(name);
      return {
        name,
        user: p.user,
        displayName: p.displayName,
        nameStyle: p.nameStyle,
        nameBadge: p.nameBadge,
        superFan: !!p.superFan,
        superFanLevel: Math.max(0, Math.floor(Number(p.superFanLevel) || 0)),
        superFanIcon: Math.max(-1, Math.floor(Number(p.superFanIcon) || -1)),
        level: p.level,
        rank: p.rank,
        balance,
        allTime: this.getAllTime(name),
        xp: this._ensureProfileShape(name).xp,
        shieldActive: shield.active,
        shieldUntil: shield.shieldUntil || 0,
        shieldMsLeft: shield.msLeft || 0,
      };
    });
  }

  /** Sorted by balance (highest first), for full on-stream list. */
  listBalances(limit = 50) {
    return this.snapshotTop(limit);
  }

  getDataHealth() {
    const meta = readPointsMeta();
    const users = countPointsUsers(this.points);
    const latestBackup = findBestBackupPoints(MIN_USERS_GUARD);
    return {
      users,
      meta,
      minUsersGuard: MIN_USERS_GUARD,
      shrinkRatioGuard: SHRINK_RATIO_GUARD,
      primaryFile: PRIMARY_POINTS_FILE,
      backupFile: POINTS_BAK_FILE,
      latestBackupUsers: latestBackup ? latestBackup.users : 0,
      latestBackupDir: latestBackup ? latestBackup.backupDir : "",
      looksHealthy:
        users >= MIN_USERS_GUARD &&
        (!meta || meta.users < MIN_USERS_GUARD || users >= Math.max(MIN_USERS_GUARD, Math.floor(meta.users * SHRINK_RATIO_GUARD))),
    };
  }
}

module.exports = { PointStore, normalizeUser };
