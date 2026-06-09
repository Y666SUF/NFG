export const JUMP_SHOP_CATALOG = [
  { id: "classic", name: "Classic", cost: 0, fill: "#596ff2", ring: "#f2c733", desc: "Default blue & gold", owned: true, equipped: true },
  { id: "neon_cyan", name: "Neon Dynasty", cost: 1_000_000, fill: "#22d3ee", ring: "#06b6d4", desc: "Radiant cyan prestige · leaderboard title" },
  { id: "solar_gold", name: "Solar Sovereign", cost: 3_500_000, fill: "#fbbf24", ring: "#fef08a", desc: "Golden sun royalty · leaderboard title" },
  { id: "violet_void", name: "Violet Voidlord", cost: 6_000_000, fill: "#a855f7", ring: "#e879f9", desc: "Purple nebula lord · leaderboard title" },
  { id: "emerald", name: "Emerald Elite", cost: 8_500_000, fill: "#34d399", ring: "#a7f3d0", desc: "Jungle elite rank · leaderboard title" },
  { id: "crimson", name: "Crimson Overlord", cost: 11_000_000, fill: "#ef4444", ring: "#fca5a5", desc: "Red-hot overlord · leaderboard title" },
  { id: "ghost", name: "Ghost Phantom", cost: 13_500_000, fill: "#f8fafc", ring: "#94a3b8", desc: "Minimal phantom · leaderboard title" },
  { id: "nfg_fire", name: "NFG Inferno", cost: 15_000_000, fill: "#ff6b35", ring: "#ffd700", desc: "Official NFG flame · ultimate leaderboard title" },
];

export function mergeJumpShop(serverItems, equippedId = "classic", ownedSkins = null) {
  if (Array.isArray(serverItems) && serverItems.length > 0) return serverItems;
  const owned = new Set(Array.isArray(ownedSkins) ? ownedSkins : ["classic"]);
  owned.add("classic");
  return JUMP_SHOP_CATALOG.map((item) => ({
    ...item,
    owned: owned.has(item.id) || item.cost === 0,
    equipped: item.id === equippedId,
  }));
}
