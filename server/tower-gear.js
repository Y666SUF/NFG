/**
 * Dragon Tower — 6-slot gear catalog (head, body, legs, shield, weapon, cape).
 * Each item has a unique `visual` id consumed by the iOS layered avatar renderer.
 */
const TOWER_SLOTS = ["head", "body", "legs", "shield", "weapon", "cape"];

const TOWER_GEAR = [
  // HEAD (5)
  { id: "cloth_hood", slot: "head", name: "Cloth Hood", cost: 0, minLevel: 1, atk: 0, def: 1, hp: 0, visual: "cloth_hood" },
  { id: "dealer_cap", slot: "head", name: "Dealer Cap", cost: 2200, minLevel: 2, atk: 0, def: 3, hp: 8, visual: "dealer_cap", casino: true },
  { id: "chip_crown", slot: "head", name: "Chip Crown", cost: 4800, minLevel: 5, atk: 1, def: 6, hp: 18, visual: "chip_crown", casino: true },
  { id: "lucky_helmet", slot: "head", name: "Lucky Helmet", cost: 7200, minLevel: 9, atk: 2, def: 10, hp: 30, visual: "lucky_helmet", casino: true },
  { id: "dragon_mask", slot: "head", name: "Dragon Mask", cost: 11000, minLevel: 14, atk: 3, def: 14, hp: 48, visual: "dragon_mask", casino: true },

  // BODY (5)
  { id: "gambler_tunic", slot: "body", name: "Gambler's Tunic", cost: 0, minLevel: 1, atk: 0, def: 0, hp: 0, visual: "gambler_tunic" },
  { id: "felt_vest", slot: "body", name: "Felt Vest", cost: 1400, minLevel: 3, atk: 0, def: 5, hp: 22, visual: "felt_vest" },
  { id: "chip_mail", slot: "body", name: "Chip Mail", cost: 5200, minLevel: 6, atk: 1, def: 11, hp: 48, visual: "chip_mail", casino: true },
  { id: "high_roller_plate", slot: "body", name: "High Roller Plate", cost: 8800, minLevel: 10, atk: 2, def: 18, hp: 82, visual: "high_roller_plate", casino: true },
  { id: "royal_jacket", slot: "body", name: "Royal Jacket", cost: 12500, minLevel: 15, atk: 3, def: 24, hp: 115, visual: "royal_jacket", casino: true },

  // LEGS (5)
  { id: "worn_trousers", slot: "legs", name: "Worn Trousers", cost: 0, minLevel: 1, atk: 0, def: 0, hp: 0, visual: "worn_trousers" },
  { id: "chip_greaves", slot: "legs", name: "Chip Greaves", cost: 3800, minLevel: 3, atk: 0, def: 4, hp: 14, visual: "chip_greaves", casino: true },
  { id: "ace_boots", slot: "legs", name: "Ace Boots", cost: 5600, minLevel: 6, atk: 0, def: 7, hp: 28, visual: "ace_boots", casino: true },
  { id: "roller_chaps", slot: "legs", name: "Roller Chaps", cost: 8200, minLevel: 10, atk: 1, def: 11, hp: 50, visual: "roller_chaps", casino: true },
  { id: "dragon_greaves", slot: "legs", name: "Dragon Greaves", cost: 11800, minLevel: 14, atk: 2, def: 16, hp: 68, visual: "dragon_greaves", casino: true },

  // SHIELD (5)
  { id: "chip_buckler", slot: "shield", name: "Chip Buckler", cost: 0, minLevel: 1, atk: 0, def: 2, hp: 0, visual: "chip_buckler" },
  { id: "bronze_guard", slot: "shield", name: "Bronze Guard", cost: 1600, minLevel: 4, atk: 0, def: 6, hp: 10, visual: "bronze_guard" },
  { id: "ace_tower", slot: "shield", name: "Ace Tower Shield", cost: 6000, minLevel: 7, atk: 0, def: 11, hp: 20, visual: "ace_tower", casino: true },
  { id: "jackpot_barrier", slot: "shield", name: "Jackpot Barrier", cost: 9500, minLevel: 11, atk: 0, def: 17, hp: 36, visual: "jackpot_barrier", casino: true },
  { id: "house_wall", slot: "shield", name: "House Wall", cost: 13200, minLevel: 16, atk: 0, def: 24, hp: 55, visual: "house_wall", casino: true },

  // WEAPON (5)
  { id: "rusty_dagger", slot: "weapon", name: "Rusty Dagger", cost: 0, minLevel: 1, atk: 0, def: 0, hp: 0, visual: "rusty_dagger" },
  { id: "chip_blade", slot: "weapon", name: "Chip Blade", cost: 4200, minLevel: 3, atk: 8, def: 0, hp: 0, visual: "chip_blade", casino: true },
  { id: "dice_saber", slot: "weapon", name: "Dice Saber", cost: 6800, minLevel: 6, atk: 14, def: 0, hp: 0, visual: "dice_saber", casino: true },
  { id: "ace_cutlass", slot: "weapon", name: "Ace Cutlass", cost: 9800, minLevel: 10, atk: 24, def: 0, hp: 0, visual: "ace_cutlass", casino: true },
  { id: "jackpot_lance", slot: "weapon", name: "Jackpot Lance", cost: 14500, minLevel: 15, atk: 38, def: 0, hp: 0, visual: "jackpot_lance", casino: true },

  // CAPE (5)
  { id: "novice_cloak", slot: "cape", name: "Novice Cloak", cost: 0, minLevel: 1, atk: 0, def: 1, hp: 0, visual: "novice_cloak" },
  { id: "velvet_cape", slot: "cape", name: "Velvet Cape", cost: 1800, minLevel: 2, atk: 0, def: 3, hp: 8, visual: "velvet_cape" },
  { id: "chip_mantle", slot: "cape", name: "Chip Mantle", cost: 4500, minLevel: 5, atk: 1, def: 5, hp: 16, visual: "chip_mantle", casino: true },
  { id: "high_roller_cape", slot: "cape", name: "High Roller Cape", cost: 7800, minLevel: 9, atk: 2, def: 8, hp: 32, visual: "high_roller_cape", casino: true },
  { id: "dragon_wings", slot: "cape", name: "Dragon Wings", cost: 12800, minLevel: 14, atk: 3, def: 12, hp: 52, visual: "dragon_wings", casino: true },
];

const STARTER_GEAR = {
  head: "cloth_hood",
  body: "gambler_tunic",
  legs: "worn_trousers",
  shield: "chip_buckler",
  weapon: "rusty_dagger",
  cape: "novice_cloak",
};

// ---- Procedurally generated higher tiers (deep-grind content) ----
// Each slot keeps its hand-made low tiers above, then gains many more
// progressively pricier tiers. `visual` encodes a tier band the iOS
// renderer turns into a colour ramp (bronze → celestial).
const GEN_MATERIALS = [
  "Bronze", "Iron", "Steel", "Obsidian", "Golden",
  "Platinum", "Crystal", "Dragonbone", "Void", "Celestial",
];
const GEN_SLOT_NOUN = {
  head: "Helm", body: "Plate", legs: "Greaves",
  shield: "Aegis", weapon: "Blade", cape: "Mantle",
};
const GEN_ROMAN = ["I", "II", "III"];
const GEN_TIERS_PER_SLOT = 30;

function genGearStats(slot, t) {
  switch (slot) {
    case "weapon": return { atk: 32 + t * 6, def: 0, hp: 0 };
    case "head": return { atk: t >= 18 ? 2 : 0, def: 13 + t * 2, hp: 36 + t * 5 };
    case "body": return { atk: t >= 22 ? 3 : 0, def: 20 + t * 3, hp: 95 + t * 11 };
    case "legs": return { atk: 0, def: 13 + t * 2, hp: 52 + t * 7 };
    case "shield": return { atk: 0, def: 20 + t * 3, hp: 44 + t * 5 };
    case "cape": return { atk: 2 + Math.floor(t / 6), def: 10 + t * 2, hp: 40 + t * 5 };
    default: return { atk: 0, def: t, hp: t };
  }
}

for (const slot of TOWER_SLOTS) {
  for (let t = 1; t <= GEN_TIERS_PER_SLOT; t++) {
    const band = Math.min(GEN_MATERIALS.length - 1, Math.floor((t - 1) / 3));
    const material = GEN_MATERIALS[band];
    const noun = GEN_SLOT_NOUN[slot] || "Relic";
    const roman = GEN_ROMAN[(t - 1) % GEN_ROMAN.length];
    const stats = genGearStats(slot, t);
    // Generated tiers: cheap early grind gear; mid tiers stay below casino; late tiers exceed it.
    const cost = t <= 12
      ? Math.round((320 * Math.pow(1.24, t - 1)) / 25) * 25
      : Math.round((14000 * Math.pow(1.16, t - 12)) / 50) * 50;
    TOWER_GEAR.push({
      id: `${slot}_gen_${t}`,
      slot,
      name: `${material} ${noun} ${roman}`,
      cost,
      minLevel: 12 + (t - 1) * 3,
      atk: stats.atk,
      def: stats.def,
      hp: stats.hp,
      visual: `gen_${slot}_t${t}_b${band}`,
    });
  }
}

// ---- Consumables (potions / healing), bought with tower gold ----
const TOWER_CONSUMABLES = [
  { id: "potion_1", name: "Health Potion", cost: 60, potions: 1, desc: "Heals 40% of max HP when used in battle." },
  { id: "potion_5", name: "Potion Bundle", cost: 260, potions: 5, desc: "Five health potions at a bulk discount." },
  { id: "potion_15", name: "Potion Crate", cost: 700, potions: 15, desc: "Fifteen potions — stock up for deep runs." },
];
const CONSUMABLE_BY_ID = Object.fromEntries(TOWER_CONSUMABLES.map((c) => [c.id, c]));

function getTowerConsumable(id) {
  return CONSUMABLE_BY_ID[String(id || "").trim()] || null;
}

const GEAR_BY_ID = Object.fromEntries(TOWER_GEAR.map((g) => [g.id, g]));

function getTowerGear(id) {
  return GEAR_BY_ID[id] || GEAR_BY_ID[STARTER_GEAR.weapon];
}

function getTowerGearBySlot(slot) {
  const s = String(slot || "").toLowerCase();
  return TOWER_GEAR.filter((g) => g.slot === s);
}

function defaultTowerEquipment() {
  return { ...STARTER_GEAR };
}

function normalizeTowerEquipment(raw) {
  const eq = raw && typeof raw === "object" ? raw : {};
  const out = defaultTowerEquipment();
  for (const slot of TOWER_SLOTS) {
    const id = String(eq[slot] || out[slot] || "").trim();
    const item = GEAR_BY_ID[id];
    if (item && item.slot === slot) out[slot] = id;
  }
  return out;
}

function migrateTowerHeroGear(hero) {
  if (!hero.equipment || typeof hero.equipment !== "object") {
    hero.equipment = defaultTowerEquipment();
    if (hero.weaponId && GEAR_BY_ID[hero.weaponId]) hero.equipment.weapon = hero.weaponId;
    if (hero.armorId && GEAR_BY_ID[hero.armorId]) hero.equipment.body = hero.armorId;
  } else {
    hero.equipment = normalizeTowerEquipment(hero.equipment);
  }

  if (!Array.isArray(hero.ownedGear)) {
    const legacy = [
      ...(Array.isArray(hero.ownedWeapons) ? hero.ownedWeapons : []),
      ...(Array.isArray(hero.ownedArmors) ? hero.ownedArmors : []),
      ...Object.values(hero.equipment),
    ].filter((id) => GEAR_BY_ID[id]);
    hero.ownedGear = [...new Set(legacy)];
  }

  for (const id of Object.values(hero.equipment)) {
    if (GEAR_BY_ID[id] && !hero.ownedGear.includes(id)) hero.ownedGear.push(id);
  }

  // Keep legacy fields in sync for older clients
  hero.weaponId = hero.equipment.weapon;
  hero.armorId = hero.equipment.body;
  hero.ownedWeapons = hero.ownedGear.filter((id) => GEAR_BY_ID[id]?.slot === "weapon");
  hero.ownedArmors = hero.ownedGear.filter((id) => GEAR_BY_ID[id]?.slot === "body");

  return hero;
}

function towerHeroVisuals(equipment) {
  const eq = normalizeTowerEquipment(equipment);
  const visuals = {};
  for (const slot of TOWER_SLOTS) {
    visuals[slot] = getTowerGear(eq[slot]).visual;
  }
  return visuals;
}

function towerHeroStatsFromGear(hero) {
  const lvl = Math.max(1, Math.floor(Number(hero.level) || 1));
  let bonusAtk = 0;
  let bonusDef = 0;
  let bonusHp = 0;
  for (const slot of TOWER_SLOTS) {
    const g = getTowerGear(hero.equipment[slot]);
    bonusAtk += g.atk || 0;
    bonusDef += g.def || 0;
    bonusHp += g.hp || 0;
  }
  const maxHp = 90 + (lvl - 1) * 14 + bonusHp;
  const atk = 10 + (lvl - 1) * 3 + bonusAtk;
  const def = 4 + (lvl - 1) * 2 + bonusDef;
  return { maxHp, atk, def, bonusAtk, bonusDef, bonusHp };
}

function towerShopForLevel(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  return TOWER_GEAR.map((item) => ({
    ...item,
    unlocked: lv >= (item.minLevel || 1),
    locked: lv < (item.minLevel || 1),
  }));
}

function towerShopBySlot(level) {
  const catalog = towerShopForLevel(level);
  const bySlot = {};
  for (const slot of TOWER_SLOTS) {
    bySlot[slot] = catalog.filter((g) => g.slot === slot);
  }
  return bySlot;
}

module.exports = {
  TOWER_SLOTS,
  TOWER_GEAR,
  TOWER_CONSUMABLES,
  STARTER_GEAR,
  getTowerGear,
  getTowerConsumable,
  getTowerGearBySlot,
  defaultTowerEquipment,
  normalizeTowerEquipment,
  migrateTowerHeroGear,
  towerHeroVisuals,
  towerHeroStatsFromGear,
  towerShopForLevel,
  towerShopBySlot,
};
