/**
 * Recover arcade leaderboards + Jump/Rush purchases from all known backups.
 * Usage: node scripts/recover-arcade-state.js
 */
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const repoRoot = path.join(__dirname, "..");
const livePath = path.join(repoRoot, "data", "arcade-state.json");
const stashExtract = path.join(repoRoot, "data", "_arcade-state-from-stash.json");

function normUser(user) {
  return String(user || "")
    .trim()
    .replace(/^@+/, "")
    .toLowerCase();
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) return null;
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (err) {
    console.warn("Skip unreadable:", filePath, err.message);
    return null;
  }
}

function extractStash() {
  try {
    const bytes = execSync('git show "stash@{0}^3:data/arcade-state.json"', {
      cwd: repoRoot,
      encoding: "buffer",
    });
    fs.writeFileSync(stashExtract, bytes);
    return readJson(stashExtract);
  } catch {
    return readJson(stashExtract);
  }
}

function collectSources() {
  const sources = [];
  const add = (label, filePath) => {
    const data = readJson(filePath);
    if (data) sources.push({ label, data });
  };

  add("git-stash", stashExtract);
  extractStash() && sources.unshift({ label: "git-stash", data: extractStash() });

  add("nfg-crash", "C:\\Users\\Yusef\\Documents\\nfg-crash\\data\\arcade-state.json");

  const dataDir = path.join(repoRoot, "data");
  for (const name of fs.readdirSync(dataDir)) {
    if (name.startsWith("arcade-state.json.bak-pre-recover-")) {
      add(name, path.join(dataDir, name));
    }
  }

  const live = readJson(livePath);
  if (live) sources.push({ label: "live", data: live });

  // de-dupe by label keeping first
  const seen = new Set();
  return sources.filter((s) => {
    if (seen.has(s.label)) return false;
    seen.add(s.label);
    return true;
  });
}

function pickEquipped(candidates) {
  const list = candidates.filter(Boolean);
  return list.find((s) => s !== "classic") || list[0] || "classic";
}

function ensureClassic(list) {
  const out = [...new Set(list || [])];
  if (!out.includes("classic")) out.unshift("classic");
  return out;
}

function mergeJumpCosmetics(live, sources) {
  const userIds = new Set();
  for (const { data } of sources) {
    for (const uid of Object.keys(data.users || {})) userIds.add(normUser(uid));
  }
  for (const uid of Object.keys(live.users || {})) userIds.add(normUser(uid));

  let restored = 0;
  for (const uid of userIds) {
    if (!uid) continue;
    if (!live.users[uid]) {
      for (const { data } of sources) {
        const src = data.users?.[uid];
        if (src) {
          live.users[uid] = JSON.parse(JSON.stringify(src));
          break;
        }
      }
    }
    if (!live.users[uid]) continue;
    if (!live.users[uid].games) live.users[uid].games = {};
    const gT = live.users[uid].games.nfg_snake_jump || {};

    const owned = new Set(gT.ownedSkins || []);
    const equippedCandidates = [gT.equippedSkin];

    for (const { data } of sources) {
      const j = data.users?.[uid]?.games?.nfg_snake_jump;
      if (!j) continue;
      for (const skin of j.ownedSkins || []) owned.add(skin);
      if (j.equippedSkin) equippedCandidates.push(j.equippedSkin);
    }

    for (const { data } of sources) {
      for (const row of (data.leaderboards?.nfg_snake_jump) || []) {
        if (normUser(row.userId) !== uid) continue;
        if (row.jumpSkinId && row.jumpSkinId !== "classic") {
          owned.add(row.jumpSkinId);
          equippedCandidates.push(row.jumpSkinId);
        }
      }
    }

    const before = JSON.stringify({
      owned: gT.ownedSkins || [],
      equipped: gT.equippedSkin || "classic",
    });
    gT.ownedSkins = ensureClassic([...owned]);
    gT.equippedSkin = pickEquipped(equippedCandidates);
    if (!gT.ownedSkins.includes(gT.equippedSkin)) {
      gT.equippedSkin = "classic";
    }
    live.users[uid].games.nfg_snake_jump = gT;

    const after = JSON.stringify({ owned: gT.ownedSkins, equipped: gT.equippedSkin });
    if (before !== after) {
      restored += 1;
      console.log(`  jump cosmetics ${uid}:`, gT.ownedSkins.join(","), "equip:", gT.equippedSkin);
    }
  }
  return restored;
}

function mergeVaultShips(live, sources) {
  let restored = 0;
  for (const uid of Object.keys(live.users || {})) {
    const gT = live.users[uid]?.games?.nfg_vault_run;
    if (!gT && !sources.some((s) => s.data.users?.[uid]?.games?.nfg_vault_run)) continue;

    const target = gT || {};
    const owned = new Set(target.ownedShips || []);
    const equippedCandidates = [target.equippedShip];

    for (const { data } of sources) {
      const v = data.users?.[uid]?.games?.nfg_vault_run;
      if (!v) continue;
      for (const ship of v.ownedShips || []) owned.add(ship);
      if (v.equippedShip) equippedCandidates.push(v.equippedShip);
    }

    if (!owned.size && !equippedCandidates.filter(Boolean).length) continue;

    if (!owned.has("classic")) owned.add("classic");
    target.ownedShips = [...owned];
    target.equippedShip = pickEquipped(equippedCandidates) || "classic";
    if (!target.ownedShips.includes(target.equippedShip)) target.equippedShip = "classic";

    if (!live.users[uid].games) live.users[uid].games = {};
    live.users[uid].games.nfg_vault_run = target;
    restored += 1;
  }
  return restored;
}

function mergeBoard(live, sources, gameId) {
  const rows = new Map();
  for (const { data } of sources) {
    for (const row of (data.leaderboards || {})[gameId] || []) {
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

function mergeUserStats(live, sources) {
  for (const { data } of sources) {
    for (const [uid, uSrc] of Object.entries(data.users || {})) {
      const key = normUser(uid);
      if (!key) continue;
      if (!live.users[key]) {
        live.users[key] = JSON.parse(JSON.stringify(uSrc));
        continue;
      }
      const target = live.users[key];
      if (!target.games) target.games = {};
      for (const [gameId, gSrc] of Object.entries(uSrc.games || {})) {
        if (!gSrc || typeof gSrc !== "object") continue;
        const gT = target.games[gameId] || {};
        if (gSrc.bestHeight != null) {
          gT.bestHeight = Math.max(gT.bestHeight || 0, Number(gSrc.bestHeight) || 0);
        }
        if (gSrc.bestLevel != null) {
          gT.bestLevel = Math.max(gT.bestLevel || 0, Number(gSrc.bestLevel) || 0);
        }
        if (gSrc.bestDistance != null) {
          gT.bestDistance = Math.max(gT.bestDistance || 0, Number(gSrc.bestDistance) || 0);
        }
        if (!gT.session && gSrc.session) gT.session = gSrc.session;
        target.games[gameId] = { ...gSrc, ...gT };
      }
    }
  }
}

function main() {
  if (!fs.existsSync(livePath)) {
    console.error("Missing live file:", livePath);
    process.exit(1);
  }

  const sources = collectSources();
  if (!sources.length) {
    console.error("No backup sources found.");
    process.exit(1);
  }

  console.log("Sources:", sources.map((s) => s.label).join(", "));

  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const preBackup = `${livePath}.bak-pre-cosmetics-${stamp}`;
  fs.copyFileSync(livePath, preBackup);
  console.log("Backup:", preBackup);

  const live = readJson(livePath);
  mergeUserStats(live, sources);

  console.log("Restoring Jump purchases...");
  const jumpFixed = mergeJumpCosmetics(live, sources);

  console.log("Restoring Rush ships...");
  const vaultFixed = mergeVaultShips(live, sources);

  if (!live.leaderboards) live.leaderboards = {};
  for (const gameId of ["nfg_snake_jump", "nfg_blocks", "nfg_vault_run"]) {
    live.leaderboards[gameId] = mergeBoard(live, sources, gameId);
  }

  fs.writeFileSync(livePath, JSON.stringify(live, null, 2));

  console.log("\nDone.");
  console.log(`  Jump cosmetic records updated: ${jumpFixed}`);
  console.log(`  Vault ship records updated: ${vaultFixed}`);
  for (const gameId of ["nfg_snake_jump", "nfg_blocks", "nfg_vault_run"]) {
    console.log(`  ${gameId} leaderboard: ${(live.leaderboards[gameId] || []).length} entries`);
  }
}

main();
