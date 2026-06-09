/** NFG Jump — vertical bounce engine (ported from iOS SnakeJumpEngine). */
export class SnakeJumpEngine {
  static playerRadius = 22;
  static platformHeight = 14;
  static milestoneStep = 2500;
  static milestoneReward = 3000;
  static horizontalSpeed = 312;
  static boostTotalLift = 300;
  static boostImpulseVelocity = 1120;
  static baseGravity = 1220;
  static baseJumpVelocity = 800;
  static worldBufferAbove = 10000;
  static maxPlatformCount = 14;
  static materializeAhead = 580;

  constructor() {
    this.reset(320);
  }

  setMatchSeed(seed) {
    let state = (Math.floor(Number(seed) || 0) >>> 0) || 1;
    this._rng = () => {
      state = (state + 0x6d2b79f5) >>> 0;
      let t = state;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
    this.reset(this.lastViewWidth || 320);
  }

  reset(viewWidth = 320) {
    if (!this._rng) this._rng = Math.random;
    this.playerX = 0;
    this.playerY = 120;
    this.velocityX = 0;
    this.velocityY = 0;
    this.boostLiftRemaining = 0;
    this.platforms = [];
    this.powerUps = [];
    this.maxHeight = 0;
    this.milestonesClaimed = 0;
    this.alive = true;
    this.gameOver = false;
    this.elapsed = 0;
    this.cameraAnchorY = 0;
    this.lastSafeX = 0;
    this.lastSafeY = 40;
    this.nextSpawnY = 120;
    this.plannedTopY = 130;
    this.lastViewWidth = Math.max(280, viewWidth);
    if (!this._rng) this._rng = Math.random;
    this.seedWorld(this.lastViewWidth);
  }

  get currentHeight() {
    return Math.max(0, Math.floor(this.playerY - 80));
  }

  get difficultyTier() {
    return Math.max(0, Math.floor(this.maxHeight / 1800));
  }

  paceMultiplier(tier) {
    return 1 + Math.min(28, tier) * 0.075;
  }

  get nextMilestoneHeight() {
    return (this.milestonesClaimed + 1) * SnakeJumpEngine.milestoneStep;
  }

  get reachedNewMilestone() {
    return this.currentHeight >= this.nextMilestoneHeight;
  }

  tick(dt, { steer = 0, moveLeft = false, moveRight = false, viewWidth, viewHeight }) {
    if (!this.alive || this.gameOver) return;
    const step = Math.min(dt, 1 / 45);
    const tier = this.difficultyTier;
    const pace = this.paceMultiplier(tier);
    const simStep = step * pace;
    this.elapsed += simStep;
    this.lastViewWidth = Math.max(280, viewWidth);

    const gravity = SnakeJumpEngine.baseGravity + tier * 14;
    const jumpVelocity = SnakeJumpEngine.baseJumpVelocity + Math.min(16, tier) * 10;

    this.applyHorizontalInput(steer, simStep, moveLeft, moveRight);

    if (this.boostLiftRemaining > 0) {
      this.velocityY = Math.max(this.velocityY, SnakeJumpEngine.boostImpulseVelocity * pace);
      const uplift = Math.max(0, this.velocityY * simStep);
      this.boostLiftRemaining = Math.max(0, this.boostLiftRemaining - uplift);
    }

    this.velocityY -= gravity * simStep;
    this.playerX += this.velocityX * simStep;
    this.playerY += this.velocityY * simStep;

    const margin = 28;
    const halfW = Math.max(80, viewWidth * 0.5 - margin);
    this.playerX = Math.min(halfW, Math.max(-halfW, this.playerX));

    this.tryLand(jumpVelocity);
    this.collectPowerUps();

    if (this.currentHeight > this.maxHeight) this.maxHeight = this.currentHeight;

    const targetCam = this.playerY - viewHeight * 0.55;
    if (this.cameraAnchorY === 0 && viewHeight > 0) {
      this.cameraAnchorY = targetCam;
    } else {
      this.cameraAnchorY = Math.max(this.cameraAnchorY, targetCam);
    }

    this.trimPlatforms(this.cameraAnchorY - 60);
    this.advanceWorldPlan(this.playerY + SnakeJumpEngine.worldBufferAbove, 2);
    const playTop = this.playerY + Math.min(SnakeJumpEngine.materializeAhead, Math.max(480, viewHeight * 0.9));
    this.spawnUpTo(playTop, viewWidth, 1);
    this.capPlatformCount();

    const screenY = viewHeight - (this.playerY - this.cameraAnchorY);
    if (screenY >= viewHeight - SnakeJumpEngine.playerRadius - 10) {
      this.alive = false;
      this.gameOver = true;
    }
  }

  applyHorizontalInput(steer, dt, moveLeft, moveRight) {
    let targetVX = 0;
    if (moveLeft || steer < -0.12) targetVX = -SnakeJumpEngine.horizontalSpeed;
    else if (moveRight || steer > 0.12) targetVX = SnakeJumpEngine.horizontalSpeed;
    else if (Math.abs(steer) > 0.08) targetVX = steer * SnakeJumpEngine.horizontalSpeed;
    const blend = Math.min(1, Math.max(dt, 1 / 120) * 16);
    this.velocityX += (targetVX - this.velocityX) * blend;
  }

  tryLand(jumpVelocity) {
    if (this.velocityY > 0) return;
    const footY = this.playerY - SnakeJumpEngine.playerRadius;
    const candidates = [];
    const landBand = this.playerY + 120;
    for (let i = 0; i < this.platforms.length; i += 1) {
      const plat = this.platforms[i];
      if (plat.y > landBand || plat.y < this.playerY - 220) continue;
      const px = plat.centerX(this.elapsed);
      const half = plat.width * 0.5;
      const onX = this.playerX >= px - half + 6 && this.playerX <= px + half - 6;
      const distY = Math.abs(footY - plat.y);
      if (!onX || distY >= 20) continue;
      candidates.push({ i, distY, deadly: plat.kind === "deadly" });
    }
    if (!candidates.length) return;
    candidates.sort((a, b) => {
      if (a.deadly !== b.deadly) return a.deadly ? 1 : -1;
      return a.distY - b.distY;
    });
    const idx = candidates[0].i;
    const plat = this.platforms[idx];
    if (plat.kind === "deadly") {
      this.alive = false;
      this.gameOver = true;
      return;
    }
    if (plat.kind === "crumble") {
      if (plat.crumbleUsed) return;
      plat.crumbleUsed = true;
      this.platforms[idx] = plat;
    }
    this.playerY = plat.y + SnakeJumpEngine.playerRadius;
    this.velocityY = jumpVelocity;
    this.boostLiftRemaining = 0;
    this.lastSafeX = plat.centerX(this.elapsed);
    this.lastSafeY = plat.y;
  }

  collectPowerUps() {
    for (const pu of this.powerUps) {
      if (pu.collected) continue;
      const dx = this.playerX - pu.x;
      const dy = this.playerY - pu.y;
      if (dx * dx + dy * dy < 48 * 48) {
        pu.collected = true;
        this.boostLiftRemaining = SnakeJumpEngine.boostTotalLift;
        this.velocityY = SnakeJumpEngine.boostImpulseVelocity;
      }
    }
  }

  playableHalfWidth(viewWidth) {
    return Math.max(90, viewWidth * 0.42);
  }

  horizontalReach(tier, early) {
    return early ? 88 : Math.max(68, 98 - Math.min(tier, 16) * 2);
  }

  seedWorld(viewWidth) {
    this.platforms = [
      {
        id: crypto.randomUUID(),
        kind: "solid",
        x: 0,
        y: 40,
        width: 120,
        movePhase: 0,
        moveSpan: 0,
        moveSpeed: 0,
        crumbleUsed: false,
        headFacesRight: true,
        centerX: (t) => 0,
      },
    ];
    this.platforms[0].centerX = function (time) {
      return this.x;
    }.bind(this.platforms[0]);
    this.lastSafeX = 0;
    this.lastSafeY = 40;
    this.nextSpawnY = 130;
    this.plannedTopY = 130;
    this.spawnUpTo(520, viewWidth, 6);
    this.advanceWorldPlan(this.playerY + SnakeJumpEngine.worldBufferAbove, 24);
  }

  spawnUpTo(targetY, viewWidth, maxSteps = 8) {
    const maxX = this.playableHalfWidth(viewWidth);
    let guard = 0;
    while (this.nextSpawnY < targetY && guard < maxSteps) {
      this.spawnGuaranteedStep(maxX);
      guard += 1;
    }
  }

  spawnGuaranteedStep(maxX) {
    const climbTier = Math.max(0, Math.floor(this.nextSpawnY / 2250));
    const early = this.nextSpawnY < 480;
    const gap = early
      ? 102 + this._rng() * 16
      : 88 + this._rng() * 16 + Math.min(climbTier, 14) * 3;
    this.nextSpawnY += gap;
    const y = this.nextSpawnY;
    const hReach = this.horizontalReach(climbTier, early);
    const phase = this._rng() * Math.PI * 2;
    const headRight = this._rng() < 0.5;
    const movingShare = early ? 0.08 : Math.min(0.48, 0.1 + climbTier * 0.03);
    const useMoving = this._rng() < movingShare;
    const primaryKind = useMoving ? "moving" : "solid";
    let primaryWidth = early ? 88 + this._rng() * 16 : Math.max(62, 106 - Math.min(climbTier, 12) * 3);
    let anchor = this.lastSafeX + (this._rng() * 2 - 1) * hReach;
    let moveSpan = 0;
    let moveSpeed = 0;
    if (primaryKind === "moving") {
      const cfg = this.movingConfig(climbTier, primaryWidth, maxX, anchor, hReach, early);
      moveSpan = cfg.span;
      moveSpeed = cfg.speed;
      anchor = cfg.anchor;
    } else {
      anchor = Math.min(maxX - primaryWidth * 0.4, Math.max(-maxX + primaryWidth * 0.4, anchor));
    }
    this.appendPlatform(primaryKind, anchor, y, primaryWidth, moveSpan, moveSpeed, phase, headRight);
    this.lastSafeX = anchor;
    this.lastSafeY = y;
    if (!early && this.platforms.length < SnakeJumpEngine.maxPlatformCount - 2) {
      const avoidLo = useMoving ? anchor - moveSpan - 24 : anchor - primaryWidth * 0.5 - 28;
      const avoidHi = useMoving ? anchor + moveSpan + 24 : anchor + primaryWidth * 0.5 + 28;
      this.spawnDecoys(maxX, y, climbTier, avoidLo, avoidHi, hReach);
      const crumbleChance = Math.min(0.34, 0.06 + climbTier * 0.02);
      if (this._rng() < crumbleChance) {
        this.spawnOptionalCrumble(maxX, y + 16 + this._rng() * 10, climbTier, hReach);
      }
      if (this._rng() < Math.min(0.1, 0.04 + climbTier * 0.004)) {
        this.powerUps.push({
          id: crypto.randomUUID(),
          x: this.lastSafeX + (this._rng() * 2 - 1) * hReach * 0.5,
          y: y + 44 + this._rng() * 24,
          collected: false,
        });
      }
    }
  }

  movingConfig(tier, width, maxX, anchor, hReach, early) {
    const fullTravel = !early && this._rng() < 0.42;
    const playable = maxX - width * 0.5 - 12;
    let span = fullTravel ? Math.min(playable, 110) : Math.min(playable * 0.38, 64);
    span = Math.max(32, span - Math.min(tier, 10) * 2);
    const speed = 32 + this._rng() * 26 + Math.min(tier, 14) * 2.8;
    let a = Math.min(maxX - span, Math.max(-maxX + span, anchor));
    const lo = a - span;
    const hi = a + span;
    if (hi < this.lastSafeX - hReach || lo > this.lastSafeX + hReach) {
      a = Math.min(maxX - span, Math.max(-maxX + span, this.lastSafeX));
    }
    return { span, speed, anchor: a };
  }

  appendPlatform(kind, x, y, width, moveSpan = 0, moveSpeed = 0, phase = 0, headFacesRight = true) {
    const plat = {
      id: crypto.randomUUID(),
      kind,
      x,
      y,
      width,
      movePhase: phase,
      moveSpan,
      moveSpeed,
      crumbleUsed: false,
      headFacesRight,
    };
    plat.centerX = function (time) {
      if (this.kind !== "moving" || this.moveSpan <= 0 || this.moveSpeed <= 0) return this.x;
      const travel = this.moveSpan * 2;
      const period = travel / this.moveSpeed;
      if (period <= 0) return this.x;
      let ph = ((time + this.movePhase) % period) / period;
      if (ph < 0) ph += 1;
      const tri = ph < 0.5 ? ph * 2 : 2 - ph * 2;
      return this.x - this.moveSpan + tri * travel;
    }.bind(plat);
    this.platforms.push(plat);
  }

  spawnDecoys(maxX, y, tier, avoidLo, avoidHi, hReach) {
    const deadlyChance = Math.min(0.38, 0.1 + tier * 0.02);
    if (this._rng() >= deadlyChance) return;
    const decoyWidth = 68 + this._rng() * 22;
    const minSep = Math.max(48, hReach * 0.5);
    for (let attempt = 0; attempt < 6; attempt += 1) {
      const goLeft = this._rng() < 0.5;
      let x = goLeft
        ? avoidLo - minSep - (24 + this._rng() * 36)
        : avoidHi + minSep + (24 + this._rng() * 36);
      x = Math.min(maxX - decoyWidth * 0.4, Math.max(-maxX + decoyWidth * 0.4, x));
      const lo = x - decoyWidth * 0.5;
      const hi = x + decoyWidth * 0.5;
      if (hi > avoidLo - 16 && lo < avoidHi + 16) continue;
      if (hi >= this.lastSafeX - hReach && lo <= this.lastSafeX + hReach) continue;
      this.appendPlatform("deadly", x, y, decoyWidth, 0, 0, 0, !goLeft);
      return;
    }
  }

  spawnOptionalCrumble(maxX, y, tier, hReach) {
    const width = Math.max(58, 84 - Math.min(tier, 8) * 2);
    let anchor = this.lastSafeX + (this._rng() * 2 - 1) * hReach * 0.75;
    anchor = Math.min(maxX - width * 0.4, Math.max(-maxX + width * 0.4, anchor));
    const lo = anchor - width * 0.5;
    const hi = anchor + width * 0.5;
    if (hi < this.lastSafeX - hReach || lo > this.lastSafeX + hReach) return;
    this.appendPlatform("crumble", anchor, y, width, 0, 0, 0, anchor >= this.lastSafeX);
  }

  advanceWorldPlan(ceilingY, maxSteps) {
    const maxX = this.playableHalfWidth(this.lastViewWidth);
    let steps = 0;
    let planY = this.plannedTopY;
    let planSafeX = this.lastSafeX;
    while (planY < ceilingY && steps < maxSteps) {
      const step = this.planSpawnStep(planY, planSafeX, maxX);
      planY = step.y;
      planSafeX = step.safeX;
      steps += 1;
    }
    this.plannedTopY = Math.max(this.plannedTopY, planY);
  }

  planSpawnStep(baseY, safeX, maxX) {
    const climbTier = Math.max(0, Math.floor(baseY / 2250));
    const early = baseY < 480;
    const gap = early ? 102 + this._rng() * 16 : 88 + this._rng() * 16 + Math.min(climbTier, 14) * 3;
    const y = baseY + gap;
    const hReach = this.horizontalReach(climbTier, early);
    let anchor = safeX + (this._rng() * 2 - 1) * hReach;
    const movingShare = early ? 0.08 : Math.min(0.48, 0.1 + climbTier * 0.03);
    const useMoving = this._rng() < movingShare;
    const primaryWidth = early ? 88 + this._rng() * 16 : Math.max(62, 106 - Math.min(climbTier, 12) * 3);
    if (useMoving) {
      const cfg = this.movingConfig(climbTier, primaryWidth, maxX, anchor, hReach, early);
      anchor = cfg.anchor;
    } else {
      anchor = Math.min(maxX - primaryWidth * 0.4, Math.max(-maxX + primaryWidth * 0.4, anchor));
    }
    return { y, safeX: anchor, safeY: y };
  }

  trimPlatforms(belowY) {
    this.platforms = this.platforms.filter((p) => p.y >= belowY);
    this.powerUps = this.powerUps.filter((p) => p.y >= belowY - 60);
  }

  capPlatformCount() {
    if (this.platforms.length > SnakeJumpEngine.maxPlatformCount) {
      this.platforms.splice(0, this.platforms.length - SnakeJumpEngine.maxPlatformCount);
    }
  }

  platformColor(kind) {
    switch (kind) {
      case "deadly":
        return "#fb7185";
      case "crumble":
        return "#fbbf24";
      case "moving":
        return "#38bdf8";
      default:
        return "#4ade80";
    }
  }
}
