/** Canonical vault badge ids (!buy commands) and legacy id migration. */
const BADGE_LEGACY_ALIASES = {
  voidmark: "acespades",
  pulsecore: "chip",
  prism: "dice",
  nova: "bullion",
  eclipse: "lucky7",
  nebula: "ltc",
  sovereign: "bitcoin",
  astral: "ethereum",
  transcend: "whale",
  apex: "imperial",
};

const CANONICAL_BADGE_IDS = new Set([
  "acespades",
  "chip",
  "dice",
  "bullion",
  "lucky7",
  "ltc",
  "bitcoin",
  "ethereum",
  "whale",
  "imperial",
  "crown",
]);

function resolveBadgeId(raw) {
  const id = String(raw || "")
    .trim()
    .toLowerCase();
  if (!id || id === "none") return "none";
  return BADGE_LEGACY_ALIASES[id] || id;
}

module.exports = {
  BADGE_LEGACY_ALIASES,
  CANONICAL_BADGE_IDS,
  resolveBadgeId,
};
