/**
 * Recover arcade leaderboards from a backup arcade-state.json
 * Usage: node scripts/recover-arcade-leaderboards.js [backupPath]
 */
const fs = require("fs");
const path = require("path");

const livePath = path.join(__dirname, "..", "data", "arcade-state.json");
const defaultBackup = "C:\\Users\\Yusef\\Documents\\nfg-crash\\data\\arcade-state.json";
const backupPath = process.argv[2] || defaultBackup;

if (!fs.existsSync(livePath)) {
  console.error("Missing live file:", livePath);
  process.exit(1);
}
if (!fs.existsSync(backupPath)) {
  console.error("Missing backup file:", backupPath);
  process.exit(1);
}

const live = JSON.parse(fs.readFileSync(livePath, "utf8"));
const backup = JSON.parse(fs.readFileSync(backupPath, "utf8"));
const stamp = new Date().toISOString().replace(/[:.]/g, "-");
const preBackup = `${livePath}.bak-pre-recover-${stamp}`;
fs.copyFileSync(livePath, preBackup);

function normUser(user) {
  return String(user || "")
    .trim()
    .replace(/^@+/, "")
    .toLowerCase();
}

function mergeUserGame(target, source) {
  if (!source?.games) return;
  if (!target.games) target.games = {};
  for (const [gameId, gSrc] of Object.entries(source.games)) {
    if (!gSrc || typeof gSrc !== "object") continue;
    const gT = { ...(target.games[gameId] || {}) };
    if (gSrc.bestHeight != null) {
      gT.bestHeight = Math.max(gT.bestHeight || 0, Number(gSrc.bestHeight) || 0);
    }
    if (gSrc.bestLevel != null) {
      gT.bestLevel = Math.max(gT.bestLevel || 0, Number(gSrc.bestLevel) || 0);
    }
    if (gSrc.bestDistance != null) {
      gT.bestDistance = Math.max(gT.bestDistance || 0, Number(gSrc.bestDistance) || 0);
    }
    if (Array.isArray(gSrc.ownedSkins)) {
      gT.ownedSkins = [...new Set([...(gT.ownedSkins || []), ...gSrc.ownedSkins])];
    }
    if (Array.isArray(gSrc.ownedShips)) {
      gT.ownedShips = [...new Set([...(gT.ownedShips || []), ...gSrc.ownedShips])];
    }
    if (gSrc.equippedSkin && !gT.equippedSkin) gT.equippedSkin = gSrc.equippedSkin;
    if (gSrc.equippedShip && !gT.equippedShip) gT.equippedShip = gSrc.equippedShip;
    if (!gT.session && gSrc.session) gT.session = gSrc.session;
    target.games[gameId] = gT;
  }
}

for (const [uid, uSrc] of Object.entries(backup.users || {})) {
  const key = normUser(uid);
  if (!key) continue;
  if (!live.users[key]) {
    live.users[key] = {
      dayKey: uSrc.dayKey || "",
      stats: uSrc.stats || { rounds: 0, wins: 0, lost: 0 },
      games: {},
      claimedMissions: [],
    };
  }
  mergeUserGame(live.users[key], uSrc);
}

function mergeBoard(gameId) {
  const rows = new Map();
  for (const state of [backup, live]) {
    for (const row of (state.leaderboards || {})[gameId] || []) {
      const uid = normUser(row.userId);
      if (!uid) continue;
      const pts = Math.floor(Number(row.points) || 0);
      const prev = rows.get(uid);
      if (!prev || pts > prev.points) {
        rows.set(uid, {
          ...row,
          userId: uid,
          points: pts,
          displayName: row.displayName || uid,
          updatedAt: row.updatedAt || Date.now(),
        });
      }
    }
  }
  return [...rows.values()].sort((a, b) => b.points - a.points).slice(0, 200);
}

if (!live.leaderboards) live.leaderboards = {};
for (const gameId of ["nfg_snake_jump", "nfg_blocks", "nfg_vault_run"]) {
  live.leaderboards[gameId] = mergeBoard(gameId);
}

fs.writeFileSync(livePath, JSON.stringify(live, null, 2));

console.log("Recovered from:", backupPath);
console.log("Pre-recovery backup:", preBackup);
for (const gameId of ["nfg_snake_jump", "nfg_blocks", "nfg_vault_run"]) {
  console.log(`  ${gameId}: ${live.leaderboards[gameId].length} entries`);
}
console.log("Users:", Object.keys(live.users).length);
