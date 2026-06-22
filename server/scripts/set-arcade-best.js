#!/usr/bin/env node
/**
 * Set a skill-game personal best + leaderboard entry in arcade-state.json.
 *
 * Usage (on the game PC, from repo root):
 *   node server/scripts/set-arcade-best.js sameya.bx 39860 nfg_snake_jump
 */
const { setArcadeSkillBest } = require("../mobile-arcade");

const user = process.argv[2];
const score = Number(process.argv[3]);
const gameId = process.argv[4] || "nfg_snake_jump";

if (!user || !Number.isFinite(score) || score <= 0) {
  console.error("Usage: node server/scripts/set-arcade-best.js <user> <score> [gameId]");
  process.exit(1);
}

const result = setArcadeSkillBest(gameId, user, score, null);
if (!result.ok) {
  console.error("Failed:", result.reason || result.message || result);
  process.exit(1);
}

console.log(
  `OK — @${result.userId} ${result.gameId} best set to ${result.best.toLocaleString()}`
);
