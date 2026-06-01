/**
 * Dragon Tower — 6-slot gear catalog (head, body, legs, shield, weapon, cape).
 * Each item has a unique `visual` id consumed by the iOS layered avatar renderer.
 */
const TOWER_SLOTS = ["head", "body", "legs", "shield", "weapon", "cape"];

const TOWER_GEAR = [
  // HEAD (5)
  { id: "cloth_hood", slot: "head", name: "Cloth Hood", cost: 0, minLevel: 1, atk: 0, def: 1, hp: 0, visual: "cloth_hood" },
  { id: "dealer_cap", slot: "head", name: "Dealer Cap", cost: 45, minLevel: 2, atk: 0, def: 2, hp: 5, visual: "dealer_cap" },
  { id: "chip_crown", slot: "head", name: "Chip Crown", cost: 120, minLevel: 5, atk: 0, def: 4, hp: 12, visual: "chip_crown" },
  { id: "lucky_helmet", slot: "head", name: "Lucky Helmet", cost: 280, minLevel: 9, atk: 1, def: 7, hp: 22, visual: "lucky_helmet" },
  { id: "dragon_mask", slot: "head", name: "Dragon Mask", cost: 620, minLevel: 14, atk: 2, def: 11, hp: 35, visual: "dragon_mask" },

  // BODY (5)
  { id: "gambler_tunic", slot: "body", name: "Gambler's Tunic", cost: 0, minLevel: 1, atk: 0, def: 0, hp: 0, visual: "gambler_tunic" },
  { id: "felt_vest", slot: "body", name: "Felt Vest", cost: 65, minLevel: 3, atk: 0, def: 4, hp: 18, visual: "felt_vest" },
  { id: "chip_mail", slot: "body", name: "Chip Mail", cost: 160, minLevel: 6, atk: 0, def: 8, hp: 38, visual: "chip_mail" },
  { id: "high_roller_plate", slot: "body", name: "High Roller Plate", cost: 380, minLevel: 10, atk: 1, def: 14, hp: 65, visual: "high_roller_plate" },
  { id: "royal_jacket", slot: "body", name: "Royal Jacket", cost: 750, minLevel: 15, atk: 2, def: 20, hp: 95, visual: "royal_jacket" },

  // LEGS (5)
  { id: "worn_trousers", slot: "legs", name: "Worn Trousers", cost: 0, minLevel: 1, atk: 0, def: 0, hp: 0, visual: "worn_trousers" },
  { id: "chip_greaves", slot: "legs", name: "Chip Greaves", cost: 55, minLevel: 3, atk: 0, def: 3, hp: 10, visual: "chip_greaves" },
  { id: "ace_boots", slot: "legs", name: "Ace Boots", cost: 140, minLevel: 6, atk: 0, def: 5, hp: 20, visual: "ace_boots" },
  { id: "roller_chaps", slot: "legs", name: "Roller Chaps", cost: 320, minLevel: 10, atk: 0, def: 9, hp: 40, visual: "roller_chaps" },
  { id: "dragon_greaves", slot: "legs", name: "Dragon Greaves", cost: 680, minLevel: 14, atk: 1, def: 13, hp: 55, visual: "dragon_greaves" },

  // SHIELD (5)
  { id: "chip_buckler", slot: "shield", name: "Chip Buckler", cost: 0, minLevel: 1, atk: 0, def: 2, hp: 0, visual: "chip_buckler" },
  { id: "bronze_guard", slot: "shield", name: "Bronze Guard", cost: 70, minLevel: 4, atk: 0, def: 5, hp: 8, visual: "bronze_guard" },
  { id: "ace_tower", slot: "shield", name: "Ace Tower Shield", cost: 175, minLevel: 7, atk: 0, def: 9, hp: 15, visual: "ace_tower" },
  { id: "jackpot_barrier", slot: "shield", name: "Jackpot Barrier", cost: 400, minLevel: 11, atk: 0, def: 14, hp: 28, visual: "jackpot_barrier" },
  { id: "house_wall", slot: "shield", name: "House Wall", cost: 820, minLevel: 16, atk: 0, def: 20, hp: 45, visual: "house_wall" },

  // WEAPON (5)
  { id: "rusty_dagger", slot: "weapon", name: "Rusty Dagger", cost: 0, minLevel: 1, atk: 0, def: 0, hp: 0, visual: "rusty_dagger" },
  { id: "chip_blade", slot: "weapon", name: "Chip Blade", cost: 75, minLevel: 3, atk: 5, def: 0, hp: 0, visual: "chip_blade" },
  { id: "dice_saber", slot: "weapon", name: "Dice Saber", cost: 180, minLevel: 6, atk: 10, def: 0, hp: 0, visual: "dice_saber" },
  { id: "ace_cutlass", slot: "weapon", name: "Ace Cutlass", cost: 400, minLevel: 10, atk: 18, def: 0, hp: 0, visual: "ace_cutlass" },
  { id: "jackpot_lance", slot: "weapon", name: "Jackpot Lance", cost: 850, minLevel: 15, atk: 28, def: 0, hp: 0, visual: "jackpot_lance" },

  // CAPE (5)
  { id: "novice_cloak", slot: "cape", name: "Novice Cloak", cost: 0, minLevel: 1, atk: 0, def: 1, hp: 0, visual: "novice_cloak" },
  { id: "velvet_cape", slot: "cape", name: "Velvet Cape", cost: 50, minLevel: 2, atk: 0, def: 2, hp: 5, visual: "velvet_cape" },
  { id: "chip_mantle", slot: "cape", name: "Chip Mantle", cost: 130, minLevel: 5, atk: 0, def: 4, hp: 12, visual: "chip_mantle" },
  { id: "high_roller_cape", slot: "cape", name: "High Roller Cape", cost: 300, minLevel: 9, atk: 1, def: 6, hp: 25, visual: "high_roller_cape" },
  { id: "dragon_wings", slot: "cape", name: "Dragon Wings", cost: 700, minLevel: 14, atk: 2, def: 10, hp: 40, visual: "dragon_wings" },
];

const STARTER_GEAR = {
  head: "cloth_hood",
  body: "gambler_tunic",
  legs: "worn_trousers",
  shield: "chip_buckler",
  weapon: "rusty_dagger",
  cape: "novice_cloak",
};

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
  STARTER_GEAR,
  getTowerGear,
  getTowerGearBySlot,
  defaultTowerEquipment,
  normalizeTowerEquipment,
  migrateTowerHeroGear,
  towerHeroVisuals,
  towerHeroStatsFromGear,
  towerShopForLevel,
  towerShopBySlot,
};
