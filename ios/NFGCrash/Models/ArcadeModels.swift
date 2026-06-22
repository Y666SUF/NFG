import Foundation

struct ArcadeCatalogResponse: Decodable {
    var ok: Bool?
    var earnedToday: Int?
    var earnCap: Int?
    var earnLeft: Int?
    var liveBonusMultiplier: Double?
    var isLive: Bool?
    var funPoints: Int?
    var balance: Int?
    var games: [ArcadeGameInfo]?
    var missions: [ArcadeMissionInfo]?
    var season: ArcadeSeasonInfo?

    init(
        ok: Bool? = nil,
        earnedToday: Int? = nil,
        earnCap: Int? = nil,
        earnLeft: Int? = nil,
        liveBonusMultiplier: Double? = nil,
        isLive: Bool? = nil,
        funPoints: Int? = nil,
        balance: Int? = nil,
        games: [ArcadeGameInfo]? = nil,
        missions: [ArcadeMissionInfo]? = nil,
        season: ArcadeSeasonInfo? = nil
    ) {
        self.ok = ok
        self.earnedToday = earnedToday
        self.earnCap = earnCap
        self.earnLeft = earnLeft
        self.liveBonusMultiplier = liveBonusMultiplier
        self.isLive = isLive
        self.funPoints = funPoints
        self.balance = balance
        self.games = games
        self.missions = missions
        self.season = season
    }
}

struct ArcadeGameInfo: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var playsPerDay: Int
    var icon: String
    var playsLeft: Int?
    var playsUsed: Int?
    var skillLevel: Int?
    var maxSkillLevel: Int?

    init(
        id: String,
        title: String,
        subtitle: String,
        playsPerDay: Int,
        icon: String,
        playsLeft: Int?,
        playsUsed: Int?
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.playsPerDay = playsPerDay
        self.icon = icon
        self.playsLeft = playsLeft
        self.playsUsed = playsUsed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title =
            (try? c.decode(String.self, forKey: .title))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? id
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        playsPerDay =
            c.flexInt(forKey: .playsPerDay)
            ?? c.flexInt(forKey: .plays_per_day)
            ?? 99
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "🎮"
        playsLeft = c.flexInt(forKey: .playsLeft) ?? c.flexInt(forKey: .plays_left)
        playsUsed = c.flexInt(forKey: .playsUsed) ?? c.flexInt(forKey: .plays_used)
        skillLevel = c.flexInt(forKey: .skillLevel) ?? c.flexInt(forKey: .skill_level)
        maxSkillLevel = c.flexInt(forKey: .maxSkillLevel) ?? c.flexInt(forKey: .max_skill_level)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, icon, name
        case playsPerDay, plays_per_day
        case playsLeft, plays_left
        case playsUsed, plays_used
        case skillLevel, skill_level, maxSkillLevel, max_skill_level
    }
}

struct ArcadeMissionInfo: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var goal: Int
    var progress: Int?
    var done: Bool?
    var claimed: Bool?

    init(
        id: String,
        title: String,
        goal: Int,
        progress: Int? = nil,
        done: Bool? = nil,
        claimed: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.progress = progress
        self.done = done
        self.claimed = claimed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Mission"
        goal = c.flexInt(forKey: .goal) ?? 1
        progress = c.flexInt(forKey: .progress)
        done = c.flexBool(forKey: .done)
        claimed = c.flexBool(forKey: .claimed)
    }
}

struct ArcadeSeasonInfo: Decodable, Hashable {
    var weekKey: String?
    var points: Int?
    var rank: Int?
    var totalPlayers: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekKey = try c.decodeIfPresent(String.self, forKey: .weekKey)
        points = c.flexInt(forKey: .points)
        rank = c.flexInt(forKey: .rank)
        totalPlayers = c.flexInt(forKey: .totalPlayers)
    }

    private enum CodingKeys: String, CodingKey {
        case weekKey, points, rank, totalPlayers
    }
}

// MARK: - Dragon Tower RPG

struct TowerCharacterAppearance: Hashable, Codable {
    var created: Bool
    var bodyStyle: String
    var skinTone: Int
    var hairStyle: Int
    var hairColor: Int
    var beard: Bool
    var heroName: String

    static let `default` = TowerCharacterAppearance(
        created: false, bodyStyle: "male", skinTone: 2, hairStyle: 1,
        hairColor: 3, beard: false, heroName: ""
    )

    init(created: Bool, bodyStyle: String, skinTone: Int, hairStyle: Int, hairColor: Int, beard: Bool, heroName: String) {
        self.created = created
        self.bodyStyle = bodyStyle
        self.skinTone = skinTone
        self.hairStyle = hairStyle
        self.hairColor = hairColor
        self.beard = beard
        self.heroName = heroName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        created = c.flexBool(forKey: .created) ?? false
        bodyStyle = try c.decodeIfPresent(String.self, forKey: .bodyStyle) ?? "male"
        skinTone = c.flexInt(forKey: .skinTone) ?? 2
        hairStyle = c.flexInt(forKey: .hairStyle) ?? 1
        hairColor = c.flexInt(forKey: .hairColor) ?? 3
        beard = c.flexBool(forKey: .beard) ?? false
        heroName = try c.decodeIfPresent(String.self, forKey: .heroName) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case created, bodyStyle, skinTone, hairStyle, hairColor, beard, heroName
    }
}

struct ArcadeTowerCombatEvent: Decodable, Hashable {
    var kind: String?
    var playerDamage: Int?
    var monsterDamage: Int?
    var xpGained: Int?
    var heal: Int?
    var killed: Bool?
    var levelUp: Bool?
    var blocked: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        playerDamage = c.flexInt(forKey: .playerDamage)
        monsterDamage = c.flexInt(forKey: .monsterDamage)
        xpGained = c.flexInt(forKey: .xpGained)
        heal = c.flexInt(forKey: .heal)
        killed = c.flexBool(forKey: .killed)
        levelUp = c.flexBool(forKey: .levelUp)
        blocked = c.flexBool(forKey: .blocked)
    }

    private enum CodingKeys: String, CodingKey {
        case kind, playerDamage, monsterDamage, xpGained, heal, killed, levelUp, blocked
    }
}

struct ArcadeTowerShopItem: Decodable, Hashable, Identifiable {
    var id: String
    var name: String
    var slot: String?
    var atk: Int?
    var def: Int?
    var hp: Int?
    var cost: Int
    var minLevel: Int?
    var visual: String?
    var unlocked: Bool?
    var locked: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        slot = try c.decodeIfPresent(String.self, forKey: .slot)
        atk = c.flexInt(forKey: .atk)
        def = c.flexInt(forKey: .def)
        hp = c.flexInt(forKey: .hp)
        cost = c.flexInt(forKey: .cost) ?? 0
        minLevel = c.flexInt(forKey: .minLevel)
        visual = try c.decodeIfPresent(String.self, forKey: .visual)
        unlocked = c.flexBool(forKey: .unlocked)
        locked = c.flexBool(forKey: .locked)
    }

    var resolvedSlot: String { slot ?? "body" }
    var resolvedVisual: String { visual ?? id }
    var requiredLevel: Int { minLevel ?? 1 }
    var isUnlocked: Bool { unlocked ?? true }

    private enum CodingKeys: String, CodingKey {
        case id, name, slot, atk, def, hp, cost, minLevel, visual, unlocked, locked
    }
}

struct TowerGearLoadout: Hashable, Codable {
    var head: String
    var body: String
    var legs: String
    var shield: String
    var weapon: String
    var cape: String

    static let starter = TowerGearLoadout(
        head: "cloth_hood", body: "gambler_tunic", legs: "worn_trousers",
        shield: "chip_buckler", weapon: "rusty_dagger", cape: "novice_cloak"
    )

    init(head: String, body: String, legs: String, shield: String, weapon: String, cape: String) {
        self.head = head
        self.body = body
        self.legs = legs
        self.shield = shield
        self.weapon = weapon
        self.cape = cape
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        head = try c.decodeIfPresent(String.self, forKey: .head) ?? Self.starter.head
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? Self.starter.body
        legs = try c.decodeIfPresent(String.self, forKey: .legs) ?? Self.starter.legs
        shield = try c.decodeIfPresent(String.self, forKey: .shield) ?? Self.starter.shield
        weapon = try c.decodeIfPresent(String.self, forKey: .weapon) ?? Self.starter.weapon
        cape = try c.decodeIfPresent(String.self, forKey: .cape) ?? Self.starter.cape
    }

    private enum CodingKeys: String, CodingKey {
        case head, body, legs, shield, weapon, cape
    }
}

struct ArcadeTowerMonster: Decodable, Hashable {
    var id: String?
    var name: String?
    var emoji: String?
    var theme: String?
    var hp: Int
    var maxHp: Int
    var atk: Int?
    var def: Int?
    var floor: Int?
    var isBoss: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
        theme = try c.decodeIfPresent(String.self, forKey: .theme)
        hp = c.flexInt(forKey: .hp) ?? 0
        maxHp = c.flexInt(forKey: .maxHp) ?? hp
        atk = c.flexInt(forKey: .atk)
        def = c.flexInt(forKey: .def)
        floor = c.flexInt(forKey: .floor)
        isBoss = c.flexBool(forKey: .isBoss)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, emoji, theme, hp, maxHp, atk, def, floor, isBoss
    }
}

struct ArcadeTowerHero: Decodable, Hashable {
    var level: Int
    var xp: Int
    var xpToNext: Int
    var gold: Int
    var potions: Int
    var bestFloor: Int
    var weaponId: String
    var weaponName: String
    var weaponAtk: Int
    var armorId: String
    var armorName: String
    var armorDef: Int
    var maxHp: Int
    var atk: Int
    var def: Int
    var ownedWeapons: [String]
    var ownedArmors: [String]
    var ownedGear: [String]
    var equipment: TowerGearLoadout?
    var visuals: TowerGearLoadout?
    var weaponVisual: String
    var armorVisual: String
    var appearance: TowerCharacterAppearance

    var resolvedLoadout: TowerGearLoadout {
        if let visuals { return visuals }
        if let equipment { return equipment }
        return TowerGearLoadout(
            head: "cloth_hood",
            body: armorVisual.isEmpty ? "gambler_tunic" : armorVisual,
            legs: "worn_trousers",
            shield: "chip_buckler",
            weapon: weaponVisual.isEmpty ? "rusty_dagger" : weaponVisual,
            cape: "novice_cloak"
        )
    }

    static let empty = ArcadeTowerHero(
        level: 1, xp: 0, xpToNext: 50, gold: 0, potions: 0, bestFloor: 0,
        weaponId: "rusty_dagger", weaponName: "Rusty Dagger", weaponAtk: 0,
        armorId: "gambler_tunic", armorName: "Gambler's Tunic", armorDef: 0,
        maxHp: 90, atk: 10, def: 4, ownedWeapons: [], ownedArmors: [], ownedGear: [],
        equipment: .starter, visuals: .starter,
        weaponVisual: "rusty_dagger", armorVisual: "gambler_tunic", appearance: .default
    )

    init(
        level: Int, xp: Int, xpToNext: Int, gold: Int, potions: Int, bestFloor: Int,
        weaponId: String, weaponName: String, weaponAtk: Int,
        armorId: String, armorName: String, armorDef: Int,
        maxHp: Int, atk: Int, def: Int,
        ownedWeapons: [String], ownedArmors: [String], ownedGear: [String],
        equipment: TowerGearLoadout?, visuals: TowerGearLoadout?,
        weaponVisual: String, armorVisual: String,
        appearance: TowerCharacterAppearance
    ) {
        self.level = level
        self.xp = xp
        self.xpToNext = xpToNext
        self.gold = gold
        self.potions = potions
        self.bestFloor = bestFloor
        self.weaponId = weaponId
        self.weaponName = weaponName
        self.weaponAtk = weaponAtk
        self.armorId = armorId
        self.armorName = armorName
        self.armorDef = armorDef
        self.maxHp = maxHp
        self.atk = atk
        self.def = def
        self.ownedWeapons = ownedWeapons
        self.ownedArmors = ownedArmors
        self.ownedGear = ownedGear
        self.equipment = equipment
        self.visuals = visuals
        self.weaponVisual = weaponVisual
        self.armorVisual = armorVisual
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = c.flexInt(forKey: .level) ?? 1
        xp = c.flexInt(forKey: .xp) ?? 0
        xpToNext = c.flexInt(forKey: .xpToNext) ?? 50
        gold = c.flexInt(forKey: .gold) ?? 0
        potions = c.flexInt(forKey: .potions) ?? 0
        bestFloor = c.flexInt(forKey: .bestFloor) ?? 0
        weaponId = try c.decodeIfPresent(String.self, forKey: .weaponId) ?? "rusty_dagger"
        weaponName = try c.decodeIfPresent(String.self, forKey: .weaponName) ?? "Rusty Dagger"
        weaponAtk = c.flexInt(forKey: .weaponAtk) ?? 0
        armorId = try c.decodeIfPresent(String.self, forKey: .armorId) ?? "gambler_tunic"
        armorName = try c.decodeIfPresent(String.self, forKey: .armorName) ?? "Gambler's Tunic"
        armorDef = c.flexInt(forKey: .armorDef) ?? 0
        maxHp = c.flexInt(forKey: .maxHp) ?? 90
        atk = c.flexInt(forKey: .atk) ?? 10
        def = c.flexInt(forKey: .def) ?? 4
        ownedWeapons = try c.decodeIfPresent([String].self, forKey: .ownedWeapons) ?? []
        ownedArmors = try c.decodeIfPresent([String].self, forKey: .ownedArmors) ?? []
        ownedGear = try c.decodeIfPresent([String].self, forKey: .ownedGear) ?? []
        equipment = try? c.decode(TowerGearLoadout.self, forKey: .equipment)
        visuals = try? c.decode(TowerGearLoadout.self, forKey: .visuals)
        weaponVisual = try c.decodeIfPresent(String.self, forKey: .weaponVisual) ?? "rusty_dagger"
        armorVisual = try c.decodeIfPresent(String.self, forKey: .armorVisual) ?? "gambler_tunic"
        if let app = try? c.decode(TowerCharacterAppearance.self, forKey: .appearance) {
            appearance = app
        } else {
            appearance = .default
        }
    }

    private enum CodingKeys: String, CodingKey {
        case level, xp, xpToNext, gold, potions, bestFloor
        case weaponId, weaponName, weaponAtk, armorId, armorName, armorDef
        case maxHp, atk, def, ownedWeapons, ownedArmors, ownedGear
        case equipment, visuals
        case weaponVisual, armorVisual, appearance
    }
}

struct ArcadeTowerCombat: Decodable, Hashable {
    var floor: Int
    var playerHp: Int
    var turn: String
    var defending: Bool
    var monster: ArcadeTowerMonster?
    var log: [String]
    var lastEvent: ArcadeTowerCombatEvent?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        floor = c.flexInt(forKey: .floor) ?? 1
        playerHp = c.flexInt(forKey: .playerHp) ?? 0
        turn = try c.decodeIfPresent(String.self, forKey: .turn) ?? "player"
        defending = c.flexBool(forKey: .defending) ?? false
        monster = try? c.decode(ArcadeTowerMonster.self, forKey: .monster)
        log = try c.decodeIfPresent([String].self, forKey: .log) ?? []
        lastEvent = try? c.decode(ArcadeTowerCombatEvent.self, forKey: .lastEvent)
    }

    private enum CodingKeys: String, CodingKey {
        case floor, playerHp, turn, defending, monster, log, lastEvent
    }
}

struct ArcadeTowerShop: Decodable, Hashable {
    var gear: [ArcadeTowerShopItem]
    var weapons: [ArcadeTowerShopItem]
    var armors: [ArcadeTowerShopItem]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gear = try c.decodeIfPresent([ArcadeTowerShopItem].self, forKey: .gear) ?? []
        weapons = try c.decodeIfPresent([ArcadeTowerShopItem].self, forKey: .weapons) ?? []
        armors = try c.decodeIfPresent([ArcadeTowerShopItem].self, forKey: .armors) ?? []
        if gear.isEmpty {
            gear = weapons + armors
        }
    }

    func items(for slot: String) -> [ArcadeTowerShopItem] {
        gear.filter { $0.resolvedSlot == slot }
    }

    private enum CodingKeys: String, CodingKey {
        case gear, weapons, armors
    }
}

struct ArcadeTowerState: Decodable, Hashable {
    var needsCreation: Bool
    var hero: ArcadeTowerHero
    var shop: ArcadeTowerShop?
    var combat: ArcadeTowerCombat?

    static let empty = ArcadeTowerState(needsCreation: true, hero: .empty, shop: nil, combat: nil)

    init(needsCreation: Bool, hero: ArcadeTowerHero, shop: ArcadeTowerShop?, combat: ArcadeTowerCombat?) {
        self.needsCreation = needsCreation
        self.hero = hero
        self.shop = shop
        self.combat = combat
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        needsCreation = c.flexBool(forKey: .needsCreation) ?? false
        hero = (try? c.decode(ArcadeTowerHero.self, forKey: .hero)) ?? .empty
        shop = try? c.decode(ArcadeTowerShop.self, forKey: .shop)
        combat = try? c.decode(ArcadeTowerCombat.self, forKey: .combat)
        if !needsCreation, !hero.appearance.created {
            needsCreation = true
        }
    }

    private enum CodingKeys: String, CodingKey {
        case needsCreation, hero, shop, combat
    }
}

struct VaultRunShipItem: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var cost: Int
    var hull: String
    var cockpit: String
    var trail: String
    var style: String
    var desc: String?
    var owned: Bool?
    var equipped: Bool?

    init(
        id: String,
        name: String,
        cost: Int,
        hull: String,
        cockpit: String,
        trail: String,
        style: String,
        desc: String? = nil,
        owned: Bool? = nil,
        equipped: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.cost = cost
        self.hull = hull
        self.cockpit = cockpit
        self.trail = trail
        self.style = style
        self.desc = desc
        self.owned = owned
        self.equipped = equipped
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        cost = c.flexInt(forKey: .cost) ?? 0
        hull = try c.decodeIfPresent(String.self, forKey: .hull) ?? "#62b8f8"
        cockpit = try c.decodeIfPresent(String.self, forKey: .cockpit) ?? "#35e0ff"
        trail = try c.decodeIfPresent(String.self, forKey: .trail) ?? "#22d3ee"
        style = try c.decodeIfPresent(String.self, forKey: .style) ?? "scout"
        desc = try c.decodeIfPresent(String.self, forKey: .desc)
        owned = c.flexBool(forKey: .owned)
        equipped = c.flexBool(forKey: .equipped)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, cost, hull, cockpit, trail, style, desc, owned, equipped
    }
}

struct ArcadePlayResponse: Decodable {
    var ok: Bool?
    var reason: String?
    var message: String?
    var game: String?
    var gained: Int?
    var balance: Int?
    var capped: Bool?
    var wallet: PlayerWallet?
    var arcade: ArcadeCatalogResponse?
    var grid: [String]?
    var won: Bool?
    var guess: Double?
    var actual: Double?
    var win: Bool?
    var opponentScore: Int?
    var score: Int?
    var doors: [Int]?
    var bust: Bool?
    var cleared: Bool?
    var funPoints: Int?
    var found: [String]?
    var complete: Bool?
    var targets: [String]?
    var missions: [ArcadeMissionInfo]?
    var pending: Int?
    var level: Int?
    var yourPoints: Int?
    var rank: Int?
    var top: [ArcadeLadderRow]?
    var streak: Int?
    var prize: Int?
    var active: ArcadeHeistActive?
    var attempts: Int?
    var maxAttempts: Int?
    var solved: Bool?
    var hasRound: Bool?
    var multiplier: Double?
    var crashAt: Double?
    var skillLevel: Int?
    var maxSkillLevel: Int?
    var playsLeft: Int?
    var playsPerDay: Int?
    var zoneWidth: Double?
    var practiceMode: Bool?
    var started: Bool?
    var suggestedRisk: Int?
    var weekKey: String?
    var totalPlayers: Int?
    var spunToday: Bool?
    var season: ArcadeSeasonInfo?
    var hint: String?
    var vaultHeat: Int?
    var vaultStatus: String?
    var direction: String?
    var mode: String?
    var digitLocks: [Bool]?
    var guessesLeft: Int?
    var closeWin: Bool?
    var lost: Int?
    var tax: Int?
    var grossPayout: Int?
    var stake: Int?
    var net: Int?
    var suggestedStake: Int?
    var stakeMin: Int?
    var stakeMax: Int?
    var unlimited: Bool?
    var runActive: Bool?
    var sessionActive: Bool?
    var segmentLabel: String?
    var segmentIndex: Int?
    var minesCount: Int?
    var revealed: [Int]?
    var coinSide: String?
    var roll: Double?
    var cooldownSecondsLeft: Int?
    var arcadeCooldownActive: Bool?
    var mineHitIndex: Int?
    var minePositions: [Int]?
    var livesRemaining: Int?
    var livesTotal: Int?
    var cardRank: Int?
    var cardSuit: String?
    var prevCardRank: Int?
    var prevCardSuit: String?
    var nextCardRank: Int?
    var nextCardSuit: String?
    var hiloCorrect: Bool?
    var stepMultiplier: Double?
    var tower: ArcadeTowerState?
    var sessionPoints: Int?
    var sessionLevels: Int?
    var linesTarget: Int?
    var levelRewardPreview: Int?
    var bestLevel: Int?
    var jumpShop: [JumpShopItem]?
    var equippedSkin: String?
    var ownedSkins: [String]?
    var skinFill: String?
    var skinRing: String?
    var sessionMilestones: Int?
    var totalJumpEarned: Int?
    var vsMatchId: String?
    var vsDeferred: Bool?
    var vaultShop: [VaultRunShipItem]?
    var equippedVaultShip: String?
    var ownedVaultShips: [String]?
    var shipHull: String?
    var shipCockpit: String?
    var shipTrail: String?
    var shipStyle: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.flexBool(forKey: .ok)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        if reason == nil {
            reason = try c.decodeIfPresent(String.self, forKey: .error)
        }
        message = try c.decodeIfPresent(String.self, forKey: .message)
        game = try c.decodeIfPresent(String.self, forKey: .game)
        gained = c.flexInt(forKey: .gained)
        balance = c.flexInt(forKey: .balance)
        capped = c.flexBool(forKey: .capped)
        wallet = try? c.decode(PlayerWallet.self, forKey: .wallet)
        arcade = try? c.decode(ArcadeCatalogResponse.self, forKey: .arcade)
        grid = try c.decodeIfPresent([String].self, forKey: .grid)
        won = c.flexBool(forKey: .won)
        guess = c.flexDouble(forKey: .guess)
        roll = c.flexDouble(forKey: .roll)
        actual = c.flexDouble(forKey: .actual) ?? roll
        win = c.flexBool(forKey: .win) ?? c.flexBool(forKey: .won)
        mode = try c.decodeIfPresent(String.self, forKey: .mode)
        if direction == nil, let mode {
            direction = mode
        }
        opponentScore = c.flexInt(forKey: .opponentScore)
        score = c.flexInt(forKey: .score)
        doors = try c.decodeIfPresent([Int].self, forKey: .doors)
        bust = c.flexBool(forKey: .bust)
        cleared = c.flexBool(forKey: .cleared)
        funPoints = c.flexInt(forKey: .funPoints)
        found = try c.decodeIfPresent([String].self, forKey: .found)
        complete = c.flexBool(forKey: .complete)
        targets = try c.decodeIfPresent([String].self, forKey: .targets)
        if let decoded = try? c.decode([ArcadeMissionInfo].self, forKey: .missions) {
            missions = decoded.filter { !$0.id.isEmpty }
        } else {
            missions = nil
        }
        pending = c.flexInt(forKey: .pending)
        level = c.flexInt(forKey: .level)
        yourPoints = c.flexInt(forKey: .yourPoints)
        rank = c.flexInt(forKey: .rank)
        if let decoded = try? c.decode([ArcadeLadderRow].self, forKey: .top) {
            top = decoded.filter { !$0.userId.isEmpty }
        } else {
            top = nil
        }
        streak = c.flexInt(forKey: .streak)
        prize = c.flexInt(forKey: .prize)
        active = try? c.decode(ArcadeHeistActive.self, forKey: .active)
        attempts = c.flexInt(forKey: .attempts)
        maxAttempts = c.flexInt(forKey: .maxAttempts)
        solved = c.flexBool(forKey: .solved)
        hasRound = c.flexBool(forKey: .hasRound)
        multiplier = c.flexDouble(forKey: .multiplier)
        crashAt = c.flexDouble(forKey: .crashAt)
        skillLevel = c.flexInt(forKey: .skillLevel)
        maxSkillLevel = c.flexInt(forKey: .maxSkillLevel)
        playsLeft = c.flexInt(forKey: .playsLeft)
        playsPerDay = c.flexInt(forKey: .playsPerDay)
        zoneWidth = c.flexDouble(forKey: .zoneWidth)
        practiceMode = c.flexBool(forKey: .practiceMode)
        started = c.flexBool(forKey: .started)
        suggestedRisk = c.flexInt(forKey: .suggestedRisk)
        weekKey = try c.decodeIfPresent(String.self, forKey: .weekKey)
        totalPlayers = c.flexInt(forKey: .totalPlayers)
        spunToday = c.flexBool(forKey: .spunToday)
        season = try? c.decode(ArcadeSeasonInfo.self, forKey: .season)
        lost = c.flexInt(forKey: .lost)
        tax = c.flexInt(forKey: .tax)
        grossPayout = c.flexInt(forKey: .grossPayout)
        stake = c.flexInt(forKey: .stake)
        net = c.flexInt(forKey: .net)
        suggestedStake = c.flexInt(forKey: .suggestedStake)
        stakeMin = c.flexInt(forKey: .stakeMin)
        stakeMax = c.flexInt(forKey: .stakeMax)
        unlimited = c.flexBool(forKey: .unlimited)
        runActive = c.flexBool(forKey: .runActive)
        sessionActive = c.flexBool(forKey: .sessionActive)
        segmentLabel = try c.decodeIfPresent(String.self, forKey: .segmentLabel)
        segmentIndex = c.flexInt(forKey: .segmentIndex)
            ?? c.flexInt(forKey: .segment_index)
        minesCount = c.flexInt(forKey: .minesCount)
        revealed = c.flexIntArray(forKey: .revealed)
        coinSide = try c.decodeIfPresent(String.self, forKey: .coinSide)
        cooldownSecondsLeft = c.flexInt(forKey: .cooldownSecondsLeft)
        arcadeCooldownActive = c.flexBool(forKey: .arcadeCooldownActive)
        mineHitIndex = c.flexInt(forKey: .mineHitIndex)
        minePositions = c.flexIntArray(forKey: .minePositions)
        livesRemaining = c.flexInt(forKey: .livesRemaining)
        livesTotal = c.flexInt(forKey: .livesTotal)
        cardRank = c.flexInt(forKey: .cardRank)
        cardSuit = try c.decodeIfPresent(String.self, forKey: .cardSuit)
        prevCardRank = c.flexInt(forKey: .prevCardRank)
        prevCardSuit = try c.decodeIfPresent(String.self, forKey: .prevCardSuit)
        nextCardRank = c.flexInt(forKey: .nextCardRank)
        nextCardSuit = try c.decodeIfPresent(String.self, forKey: .nextCardSuit)
        hiloCorrect = c.flexBool(forKey: .hiloCorrect)
        stepMultiplier = c.flexDouble(forKey: .stepMultiplier)
        tower = try? c.decode(ArcadeTowerState.self, forKey: .tower)
        sessionPoints = c.flexInt(forKey: .sessionPoints)
        sessionLevels = c.flexInt(forKey: .sessionLevels)
        linesTarget = c.flexInt(forKey: .linesTarget)
        levelRewardPreview = c.flexInt(forKey: .levelRewardPreview)
        bestLevel = c.flexInt(forKey: .bestLevel)
        jumpShop = try? c.decode([JumpShopItem].self, forKey: .jumpShop)
        equippedSkin = try c.decodeIfPresent(String.self, forKey: .equippedSkin)
        ownedSkins = try c.decodeIfPresent([String].self, forKey: .ownedSkins)
        skinFill = try c.decodeIfPresent(String.self, forKey: .skinFill)
        skinRing = try c.decodeIfPresent(String.self, forKey: .skinRing)
        sessionMilestones = c.flexInt(forKey: .sessionMilestones)
        if sessionMilestones == nil { sessionMilestones = sessionLevels }
        totalJumpEarned = c.flexInt(forKey: .totalJumpEarned)
        vsMatchId = try c.decodeIfPresent(String.self, forKey: .vsMatchId)
        vsDeferred = c.flexBool(forKey: .vsDeferred)
        vaultShop = try? c.decode([VaultRunShipItem].self, forKey: .vaultShop)
        equippedVaultShip = try c.decodeIfPresent(String.self, forKey: .equippedVaultShip)
        ownedVaultShips = try c.decodeIfPresent([String].self, forKey: .ownedVaultShips)
        shipHull = try c.decodeIfPresent(String.self, forKey: .shipHull)
        shipCockpit = try c.decodeIfPresent(String.self, forKey: .shipCockpit)
        shipTrail = try c.decodeIfPresent(String.self, forKey: .shipTrail)
        shipStyle = try c.decodeIfPresent(String.self, forKey: .shipStyle)
    }

    private enum CodingKeys: String, CodingKey {
        case ok, reason, error, message, game, gained, balance, capped, wallet, arcade
        case grid, won, guess, actual, roll, win, opponentScore, score, doors
        case bust, cleared, funPoints, found, complete, targets, missions
        case pending, level, yourPoints, rank, top, streak, prize, active
        case attempts, maxAttempts, solved, hasRound, multiplier, crashAt
        case skillLevel, maxSkillLevel, playsLeft, playsPerDay, zoneWidth
        case practiceMode, started, suggestedRisk, weekKey, totalPlayers, spunToday, season
        case hint, vaultHeat, vaultStatus, direction, mode, digitLocks, guessesLeft, closeWin
        case lost, stake, net, suggestedStake, stakeMin, stakeMax, unlimited, runActive, sessionActive
        case tax, grossPayout
        case segmentLabel, segmentIndex, segment_index
        case minesCount, revealed, coinSide
        case cooldownSecondsLeft, arcadeCooldownActive
        case mineHitIndex, minePositions, livesRemaining, livesTotal
        case cardRank, cardSuit, prevCardRank, prevCardSuit, nextCardRank, nextCardSuit
        case hiloCorrect, stepMultiplier, tower
        case sessionPoints, sessionLevels, linesTarget, levelRewardPreview, bestLevel
        case jumpShop, equippedSkin, ownedSkins, skinFill, skinRing, sessionMilestones, totalJumpEarned
        case vsMatchId, vsDeferred
        case vaultShop, equippedVaultShip, ownedVaultShips
        case shipHull, shipCockpit, shipTrail, shipStyle
    }
}

enum ArcadeErrors {
    static func userMessage(reason: String?, message: String?) -> String {
        let code = reason ?? message
        if let message, !message.isEmpty, !isReasonCode(message) {
            return message
        }
        return friendlyReason(code)
    }

    private static func isReasonCode(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t == "invalid_action" || t == "invalid action" || t.contains("invalid_action")
    }

    private static func friendlyReason(_ reason: String?) -> String {
        switch reason?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "invalid_action", "invalid action": return "That button isn't ready yet — follow the steps above."
        case "no_plays_left": return "No plays left today (max 5). Come back tomorrow."
        case "need_start": return "Start the round first."
        case "run_active": return "Finish the current round first."
        case "already_spun": return "You already used today's spin."
        case "already_solved": return "You already solved this today."
        case "nothing_to_collect": return "Nothing to collect yet — check back soon."
        case "insufficient_fun": return "Not enough fun points."
        case "cooldown": return "Arcade cooldown — wait a few seconds before the next staked round."
        case "unknown_game": return "This game is not on the server yet — update the PC server."
        case "no_round": return "Practice round loading — try again in a moment."
        case "bad_guess": return "Check your guess and try again."
        default:
            if let reason, !reason.isEmpty {
                return reason.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return "Something went wrong."
        }
    }
}

struct ArcadeHeistActive: Decodable, Hashable {
    var runId: String?
    var step: Int?
    var multiplier: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runId = try c.decodeIfPresent(String.self, forKey: .runId)
        step = c.flexInt(forKey: .step)
        multiplier = c.flexInt(forKey: .multiplier)
    }

    private enum CodingKeys: String, CodingKey {
        case runId, step, multiplier
    }
}

struct ArcadeLeaderboardResponse: Decodable {
    var ok: Bool?
    var gameId: String?
    var top: [ArcadeLadderRow]?
    var myRank: Int?
    var myScore: Int?
    var scoreLabel: String?
}

struct ArcadeLadderRow: Decodable, Identifiable, Hashable {
    var userId: String
    var displayName: String?
    var points: Int
    var jumpSkinId: String?
    var jumpSkinName: String?
    var jumpSkinFill: String?
    var jumpSkinRing: String?
    var id: String { userId }

    var label: String {
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        if userId.count > 14 { return String(userId.prefix(12)) + "…" }
        return userId.isEmpty ? "Player" : userId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId =
            (try? c.decode(String.self, forKey: .userId))
            ?? (try? c.decode(String.self, forKey: .user))
            ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        points = c.flexInt(forKey: .points) ?? 0
        jumpSkinId = try c.decodeIfPresent(String.self, forKey: .jumpSkinId)
        jumpSkinName = try c.decodeIfPresent(String.self, forKey: .jumpSkinName)
        jumpSkinFill = try c.decodeIfPresent(String.self, forKey: .jumpSkinFill)
        jumpSkinRing = try c.decodeIfPresent(String.self, forKey: .jumpSkinRing)
    }

    private enum CodingKeys: String, CodingKey {
        case userId, user, displayName, points
        case jumpSkinId, jumpSkinName, jumpSkinFill, jumpSkinRing
    }
}

// MARK: - Lenient JSON helpers (server may send numbers as doubles or omit keys)

private extension KeyedDecodingContainer {
    func flexInt(forKey key: Key) -> Int? {
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let v = try? decode(Double.self, forKey: key) { return Int(v) }
        if let s = try? decode(String.self, forKey: key), let v = Int(s) { return v }
        return nil
    }

    func flexDouble(forKey key: Key) -> Double? {
        if let v = try? decode(Double.self, forKey: key) { return v }
        if let v = try? decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? decode(String.self, forKey: key), let v = Double(s) { return v }
        return nil
    }

    func flexBool(forKey key: Key) -> Bool? {
        if let v = try? decode(Bool.self, forKey: key) { return v }
        if let v = try? decode(Int.self, forKey: key) { return v != 0 }
        if let s = try? decode(String.self, forKey: key) {
            switch s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: break
            }
        }
        return nil
    }

    func flexIntArray(forKey key: Key) -> [Int]? {
        if let v = try? decode([Int].self, forKey: key) { return v }
        if let v = try? decode([Double].self, forKey: key) { return v.map { Int($0) } }
        return nil
    }
}

/// Bundled arcade catalog (same NFG points as Crash).
enum ArcadeBundledCatalog {
    static let jumpGameId = "nfg_snake_jump"
    static let rushGameId = "nfg_vault_run"

    private static let skillGameIds: Set<String> = [jumpGameId, rushGameId, "nfg_blocks"]

    static let games: [ArcadeGameInfo] = [
        ArcadeGameInfo(id: "nfg_dice", title: "Roll Line", subtitle: "Under or over 0–100", playsPerDay: 0, icon: "🎯", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "nfg_hilo", title: "Hi-Lo", subtitle: "Higher or lower cards", playsPerDay: 0, icon: "🃏", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "nfg_mines", title: "Mines", subtitle: "Gems vs mines", playsPerDay: 0, icon: "💣", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "nfg_plinko", title: "Plinko", subtitle: "Drop for a multiplier", playsPerDay: 0, icon: "⚪", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "nfg_wheel", title: "Wheel", subtitle: "Spin to win or lose", playsPerDay: 0, icon: "🎡", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "nfg_blocks", title: "NFG Blocks", subtitle: "Block Blast puzzle — earn pts", playsPerDay: 0, icon: "🧱", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: jumpGameId, title: "NFG Jump", subtitle: "Bounce higher — skill climber + VS", playsPerDay: 0, icon: "⬆️", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: rushGameId, title: "NFG Rush", subtitle: "3-lane casino run — milestone pts", playsPerDay: 0, icon: "🏃", playsLeft: nil, playsUsed: nil),
    ]

    /// Games removed from the client hub (server may still list them).
    private static let hiddenGameIds: Set<String> = ["nfg_tower", "nfg_coinflip"]

    /// Skill games (Blocks, Jump, Rush) pinned to the bottom of the hub grid.
    static func hubDisplayOrder(_ games: [ArcadeGameInfo]) -> [ArcadeGameInfo] {
        let visible = games.filter { !hiddenGameIds.contains($0.id) }
        let regular = visible.filter { !skillGameIds.contains($0.id) }
        let skillOrder = ["nfg_blocks", jumpGameId, rushGameId]
        let skill = skillOrder.compactMap { id in visible.first(where: { $0.id == id }) }
        return regular + skill
    }

    /// Maps legacy server/catalog ids to the current client game id.
    static func normalizeGameId(_ id: String) -> String {
        switch id {
        case "nfg_limbo": return "nfg_hilo"
        default: return id
        }
    }

    static func merge(serverGames: [ArcadeGameInfo]?) -> [ArcadeGameInfo] {
        let fromServer = (serverGames ?? []).map { g -> ArcadeGameInfo in
            var copy = g
            copy.id = normalizeGameId(g.id)
            if g.id == "nfg_limbo" {
                if let hilo = games.first(where: { $0.id == "nfg_hilo" }) {
                    copy.title = hilo.title
                    copy.subtitle = hilo.subtitle
                    copy.icon = hilo.icon
                }
            }
            return copy
        }
        let filtered = fromServer.filter { !hiddenGameIds.contains($0.id) }
        if filtered.isEmpty { return games }
        return games.map { bundled in
            var merged = filtered.first(where: { $0.id == bundled.id }) ?? bundled
            merged.id = bundled.id
            merged.title = bundled.title
            merged.subtitle = bundled.subtitle
            merged.icon = bundled.icon
            merged.playsPerDay = 0
            merged.playsLeft = merged.playsLeft ?? 9999
            if merged.playsLeft ?? 0 < 100 {
                merged.playsLeft = 9999
            }
            return merged
        }
    }
}
