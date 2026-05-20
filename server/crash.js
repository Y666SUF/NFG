/**
 * Crash multiplier generation (stream-friendly, not cryptographic).
 * Higher values of HOUSE_EDGE favor the house slightly.
 */
const HOUSE_EDGE = 0.03;
const MAX_MULTIPLIER = 500;

function nextCrashMultiplier() {
  const r = Math.random();
  if (r < 0.005) {
    return 1 + Math.floor(Math.random() * 50) / 100;
  }
  const e = 1 - HOUSE_EDGE;
  const m = e / (1 - r * 0.9999);
  const capped = Math.min(MAX_MULTIPLIER, m);
  return Math.max(1.01, Math.floor(capped * 100) / 100);
}

module.exports = { nextCrashMultiplier, HOUSE_EDGE, MAX_MULTIPLIER };
