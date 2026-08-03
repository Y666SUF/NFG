/** Canvas crash chart — storm sky, Patrick Star + Mjolnir flight (PC + play). */
const THEME = {
  accent: "#60a5fa",
  accent2: "#fbbf24",
  danger: "#ef4444",
  danger2: "#f97316",
  muted: "#94a3b8",
  border: "rgba(255,255,255,0.1)",
  space: "#060912",
  lineViolet: "#3b5998",
  linePink: "#d4a017",
};

const HERO_HIDE_MULT = 10;
const EARLY_FLIGHT_MULT = 5;

/** Front-loads travel so 1→5× climbs most of the chart; 10+ flies off-screen. */
function hammerFlightProgress(mult, yMax) {
  const m = Math.max(mult, 1);
  if (m <= EARLY_FLIGHT_MULT) {
    return ((m - 1) / (EARLY_FLIGHT_MULT - 1)) * 0.72;
  }
  if (m < HERO_HIDE_MULT) {
    const span = HERO_HIDE_MULT - EARLY_FLIGHT_MULT;
    return 0.72 + ((m - EARLY_FLIGHT_MULT) / span) * 0.18;
  }
  const tail = Math.max(yMax - HERO_HIDE_MULT, 1);
  return 0.9 + ((m - HERO_HIDE_MULT) / tail) * 0.55;
}

function shouldShowHero(mult) {
  return mult < HERO_HIDE_MULT;
}

function makeGridTicks(yMax) {
  const ticks = [1];
  let step;
  if (yMax < 2) step = 0.2;
  else if (yMax < 4) step = 0.5;
  else if (yMax < 8) step = 1;
  else if (yMax < 20) step = 2;
  else step = 5;
  let v = 1 + step;
  while (v < yMax * 0.92) {
    ticks.push(Math.round(v * 100) / 100);
    v += step;
  }
  return ticks;
}

class FlightLayout {
  constructor(width, height, yMax) {
    this.width = width;
    this.height = height;
    this.yMax = yMax;
    this.padX = 28;
    this.padY = 18;
    this.innerW = Math.max(1, width - this.padX * 2);
    this.innerH = Math.max(1, height - this.padY * 2);
    this.gridTicks = makeGridTicks(yMax);
  }

  point(mult, opts = {}) {
    const m = Math.max(mult, 1);
    const uncapped = !!(opts && opts.uncapped);
    let t = hammerFlightProgress(m, this.yMax);
    if (!uncapped) t = Math.min(t, 1);
    const tY = uncapped ? t : Math.min(t, 1);
    const tX =
      m >= HERO_HIDE_MULT && uncapped ? Math.min(t * 1.12, 1.35) : Math.min(t, 1);
    const x = this.padX + this.innerW * (0.08 + 0.84 * tX);
    const y = this.height - this.padY - this.innerH * tY;
    return { x, y };
  }

  flightAngle(mult, prevMult) {
    const m = Math.max(mult, 1.001);
    const prev = Math.max(Number(prevMult) || m - 0.06, 1);
    const p0 = this.point(prev, { uncapped: true });
    const p1 = this.point(m, { uncapped: true });
    const dx = p1.x - p0.x;
    const dy = p1.y - p0.y;
    if (Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) return 0;
    return Math.atan2(dx, -dy);
  }

  impactPoint(mult) {
    const peak = this.point(mult);
    return { x: peak.x, y: this.height - this.padY };
  }
}

function drawStormCloud(ctx, cx, cy, r) {
  ctx.fillStyle = "rgba(18, 24, 42, 0.88)";
  ctx.beginPath();
  ctx.arc(cx, cy, r * 0.58, 0, Math.PI * 2);
  ctx.arc(cx + r * 0.48, cy + r * 0.1, r * 0.46, 0, Math.PI * 2);
  ctx.arc(cx - r * 0.42, cy + r * 0.06, r * 0.4, 0, Math.PI * 2);
  ctx.fill();
}

function drawSkyScene(ctx, w, h) {
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, "#050810");
  sky.addColorStop(0.35, "#0c1224");
  sky.addColorStop(0.72, "#141c32");
  sky.addColorStop(1, "#1a2238");
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  const pulse = 0.5 + Math.sin(performance.now() * 0.002) * 0.25;
  const glow = ctx.createRadialGradient(w * 0.5, h * 0.35, 0, w * 0.5, h * 0.35, w * 0.55);
  glow.addColorStop(0, `rgba(59, 130, 246, ${0.08 * pulse})`);
  glow.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, w, h);

  drawStormCloud(ctx, w * 0.12, h * 0.16, 40);
  drawStormCloud(ctx, w * 0.45, h * 0.08, 34);
  drawStormCloud(ctx, w * 0.74, h * 0.28, 38);
  drawStormCloud(ctx, w * 0.3, h * 0.48, 28);
}

function drawLaunchSlingshot(ctx, x, y) {
  const runePulse = 0.55 + Math.sin(performance.now() * 0.004) * 0.35;
  ctx.fillStyle = "rgba(12, 16, 28, 0.92)";
  ctx.beginPath();
  ctx.ellipse(x, y + 12, 32, 11, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = `rgba(96, 165, 250, ${0.35 + runePulse * 0.4})`;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(x, y + 10, 22, Math.PI, 0);
  ctx.stroke();
  ctx.fillStyle = `rgba(251, 191, 36, ${0.25 + runePulse * 0.35})`;
  ctx.beginPath();
  ctx.moveTo(x, y - 8);
  ctx.lineTo(x - 6, y + 4);
  ctx.lineTo(x + 6, y + 4);
  ctx.closePath();
  ctx.fill();
}

const PATRICK_ASSET = {
  sources: ["/assets/patrick-star.png?v=2", "/assets/patrick-star.svg"],
  w: 128,
  h: 192,
};

let patrickSpritePromise = null;

function loadPatrickSprite() {
  if (!patrickSpritePromise) {
    patrickSpritePromise = new Promise((resolve) => {
      const sources = PATRICK_ASSET.sources;
      const tryNext = (i) => {
        if (i >= sources.length) return resolve(null);
        const img = new Image();
        img.decoding = "async";
        img.onload = () => resolve(img);
        img.onerror = () => tryNext(i + 1);
        img.src = sources[i];
      };
      tryNext(0);
    });
  }
  return patrickSpritePromise;
}

const patrickSpriteReady = loadPatrickSprite();

/** Patrick Star — static corner cameo; PNG/SVG normalized to ~128px wide. */
function drawPatrick(ctx, x, y, scale, _running, _mult, sprite) {
  const footX = x - 4 * scale;
  const footY = y + 2 * scale;
  const targetW = PATRICK_ASSET.w * scale * 0.72;

  if (sprite && sprite.complete && sprite.naturalWidth > 0) {
    const w = sprite.naturalWidth;
    const h = sprite.naturalHeight;
    const drawW = targetW;
    const drawH = targetW * (h / w);
    ctx.drawImage(sprite, footX - drawW / 2, footY - drawH, drawW, drawH);
    return;
  }

  drawPatrickFallback(ctx, footX, footY, targetW / PATRICK_ASSET.w);
}

function drawPatrickFallback(ctx, footX, footY, s) {
  const topY = footY - 192 * s;
  ctx.save();
  ctx.translate(footX, topY);
  ctx.scale(s, s);

  ctx.fillStyle = "#ff9f8a";
  ctx.strokeStyle = "#b85a48";
  ctx.lineWidth = 2.2;
  ctx.beginPath();
  ctx.moveTo(64, 6);
  ctx.bezierCurveTo(88, 6, 106, 46, 104, 88);
  ctx.bezierCurveTo(102, 122, 82, 140, 64, 140);
  ctx.bezierCurveTo(46, 140, 26, 122, 24, 88);
  ctx.bezierCurveTo(22, 46, 40, 6, 64, 6);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = "#c8eb5a";
  ctx.strokeStyle = "#6d9424";
  ctx.beginPath();
  ctx.moveTo(36, 118);
  ctx.bezierCurveTo(48, 136, 80, 136, 92, 118);
  ctx.lineTo(92, 148);
  ctx.bezierCurveTo(78, 158, 50, 158, 36, 148);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = "#fff";
  ctx.beginPath();
  ctx.ellipse(50, 52, 11, 14, 0, 0, Math.PI * 2);
  ctx.ellipse(78, 52, 11, 14, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#1a1010";
  ctx.beginPath();
  ctx.ellipse(52, 54, 4.5, 6, 0, 0, Math.PI * 2);
  ctx.ellipse(80, 54, 4.5, 6, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

/** Mjolnir at flight position — separate from Patrick. */
function drawMjolnir(ctx, x, y, angle, scale, flying, crashed) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  ctx.scale(scale, scale);
  const t = performance.now() * 0.001;
  const spin = flying && !crashed ? t * 8 : 0;

  if (flying && !crashed) {
    ctx.strokeStyle = `rgba(96, 165, 250, ${0.5 + Math.sin(t * 18) * 0.25})`;
    ctx.lineWidth = 2.5;
    ctx.shadowColor = "#3b82f6";
    ctx.shadowBlur = 16;
    for (let i = 0; i < 5; i++) {
      ctx.beginPath();
      ctx.moveTo(0, 14);
      ctx.lineTo(-12 + Math.sin(t * 20 + i) * 10, 26 + i * 8);
      ctx.lineTo(10 + i * 2, 36 + i * 6);
      ctx.stroke();
    }
    ctx.shadowBlur = 0;
  }

  ctx.save();
  ctx.rotate(spin);
  ctx.fillStyle = crashed ? "#4e342e" : "#5d4037";
  ctx.fillRect(-4, -6, 8, 38);
  ctx.fillStyle = crashed ? "#455a64" : "#78909c";
  ctx.strokeStyle = "#263238";
  ctx.lineWidth = 1.5;
  if (typeof ctx.roundRect === "function") {
    ctx.beginPath();
    ctx.roundRect(-18, -42, 36, 22, 5);
    ctx.fill();
    ctx.stroke();
  } else {
    ctx.fillRect(-18, -42, 36, 22);
  }
  ctx.fillStyle = crashed ? "#546e7a" : "#90a4ae";
  ctx.fillRect(-14, -38, 8, 14);
  ctx.fillRect(6, -38, 8, 14);
  if (!crashed) {
    ctx.fillStyle = `rgba(96, 165, 250, ${0.6 + Math.sin(t * 11) * 0.35})`;
    ctx.shadowColor = "#2563eb";
    ctx.shadowBlur = 14;
    ctx.fillRect(-6, -34, 12, 9);
    ctx.shadowBlur = 0;
  } else {
    ctx.strokeStyle = "rgba(251, 191, 36, 0.55)";
    ctx.strokeRect(-6, -34, 12, 9);
    for (let i = 0; i < 6; i++) {
      ctx.fillStyle = "rgba(251, 191, 36, 0.5)";
      ctx.beginPath();
      ctx.arc(-16 + i * 6, 8 + (i % 2) * 4, 2.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.restore();
  ctx.restore();
}

function drawFeatherBurst(ctx, x, y) {
  ctx.save();
  ctx.shadowColor = "#60a5fa";
  ctx.shadowBlur = 24;
  const core = ctx.createRadialGradient(x, y, 0, x, y, 72);
  core.addColorStop(0, "rgba(255,255,255,0.95)");
  core.addColorStop(0.25, "rgba(251, 191, 36, 0.75)");
  core.addColorStop(0.55, "rgba(59, 130, 246, 0.45)");
  core.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = core;
  ctx.beginPath();
  ctx.arc(x, y, 72, 0, Math.PI * 2);
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.strokeStyle = "rgba(191, 219, 254, 0.85)";
  ctx.lineWidth = 2.5;
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2 + performance.now() * 0.001;
    const len = 28 + (i % 3) * 14;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + Math.cos(a) * len, y + Math.sin(a) * len * 0.65);
    ctx.stroke();
  }
  ctx.restore();
}

export class CrashChartRenderer {
  constructor(canvas, wrap) {
    this.canvas = canvas;
    this.wrap = wrap;
    this.ctx = canvas.getContext("2d");
    this.phase = "idle";
    this.multiplier = 1;
    this.crashPoint = null;
    this.history = [1];
    this.crashPhase = "none";
    this.crashProgress = 0;
    this.frozenMult = 1;
    this.crashAnimStart = 0;
    this.raf = 0;
    this.viewYMax = 1.65;
    this.runningYMax = null;
    this.lastSize = { w: 0, h: 0 };
    this.getLiveMult = null;
    this.getLiveHistory = null;
    this.onFrame = null;
    this.smoothRocket = null;
    this.prevRocketPos = null;
    this.lastRocketMult = null;
    this.lastRocketAngle = 0;
    this.lastDrawTs = 0;
    this.starfieldKey = "";
    this.starfieldCanvas = null;
    this.patrickSprite = null;
    patrickSpriteReady.then((img) => {
      this.patrickSprite = img;
    });
    this.onResize = () => this.resize();
    window.addEventListener("resize", this.onResize);
    if (typeof ResizeObserver !== "undefined") {
      this.ro = new ResizeObserver(() => this.resize());
      this.ro.observe(this.wrap);
    }
    this.resize();
    this.loop();
  }

  destroy() {
    cancelAnimationFrame(this.raf);
    window.removeEventListener("resize", this.onResize);
    this.ro?.disconnect();
  }

  layoutHeight() {
    const vv = window.visualViewport;
    let h = vv?.height ?? window.innerHeight;
    const topbar = document.getElementById("topbar");
    const tabbar = document.getElementById("tabbar");
    const betDock = document.querySelector(".bet-dock");
    if (topbar && !topbar.hidden) h -= topbar.offsetHeight;
    if (tabbar && !tabbar.hidden) h -= tabbar.offsetHeight;
    if (betDock) h -= betDock.offsetHeight;
    const sceneHead = document.querySelector(".play-scene");
    if (sceneHead) {
      const chart = this.wrap;
      const headH = sceneHead.offsetHeight - (chart?.offsetHeight || 0);
      h -= Math.max(0, headH);
    }
    return Math.max(320, h);
  }

  chartHeight() {
    const rect = this.wrap.getBoundingClientRect();
    if (rect.height >= 80) return rect.height;
    const layoutH = this.layoutHeight();
    return Math.min(168, Math.max(120, layoutH * 0.26));
  }

  resize() {
    const rect = this.wrap.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const w = Math.max(260, rect.width);
    const h = this.chartHeight();
    this.canvas.style.width = `${w}px`;
    this.canvas.style.height = `${h}px`;
    this.canvas.width = Math.floor(w * dpr);
    this.canvas.height = Math.floor(h * dpr);
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.lastSize = { w, h };
  }

  update(state) {
    const prev = this.phase;
    this.phase = state.phase || "idle";
    this.multiplier = Number(state.multiplier) || 1;
    this.crashPoint = state.crashPoint;

    if (state.history) {
      this.history = state.history;
    } else if (this.phase === "running") {
      const m = this.multiplier;
      const last = this.history[this.history.length - 1];
      if (last == null || Math.abs(last - m) > 0.001) {
        this.history.push(m);
        if (this.history.length > 200) this.history.shift();
      }
    } else if (this.phase === "betting" || this.phase === "idle") {
      this.history = [1];
    } else if (this.phase === "ended") {
      const endM = this.crashPoint != null ? this.crashPoint : this.multiplier;
      const last = this.history[this.history.length - 1];
      if (last == null || Math.abs(last - endM) > 0.02) this.history.push(endM);
    }

    if (this.phase === "betting" || this.phase === "idle") {
      this.resetCrash();
      this.viewYMax = 1.65;
      this.runningYMax = null;
    } else if (this.phase === "running" && prev !== "running") {
      this.runningYMax = 15;
      this.smoothRocket = null;
      this.prevRocketPos = null;
      this.lastRocketMult = null;
      this.lastRocketAngle = 0;
    } else if (this.phase === "ended" && (prev === "running" || prev === "ended") && this.crashPhase === "none") {
      this.beginCrash();
    }

    this.wrap.dataset.phase = this.phase;
    if (this.crashPhase !== "none") this.wrap.dataset.phase = "ended";
  }

  resetCrash() {
    this.crashPhase = "none";
    this.crashProgress = 0;
    this.frozenMult = 1;
    this.lastRocketMult = null;
    this.prevRocketPos = null;
  }

  rocketAngleFromMotion(pos) {
    if (!this.prevRocketPos) return this.lastRocketAngle || 0;
    const dx = pos.x - this.prevRocketPos.x;
    const dy = pos.y - this.prevRocketPos.y;
    if (Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) return this.lastRocketAngle || 0;
    if (dy > 0.5) return this.lastRocketAngle || 0;
    const angle = Math.atan2(dx, -dy);
    this.lastRocketAngle = angle;
    return angle;
  }

  /** Fixed chart scale for the whole round + crash animation (avoid rescale jitter). */
  resolveViewYMax(_mult, running) {
    if (running || this.crashPhase !== "none") {
      if (!this.runningYMax) this.runningYMax = 15;
      return this.runningYMax;
    }
    const head = Math.max(_mult, 1);
    const target = Math.max(head * 1.22, 1.65);
    if (this.phase === "ended" || this.crashPhase !== "none") {
      this.viewYMax += (target - this.viewYMax) * 0.15;
    } else {
      this.viewYMax = target;
    }
    return Math.max(this.viewYMax, 1.5);
  }

  ensureStarfield(w, h) {
    const key = `${w}x${h}`;
    if (this.starfieldKey === key && this.starfieldCanvas) return this.starfieldCanvas;
    const dpr = window.devicePixelRatio || 1;
    const canvas = document.createElement("canvas");
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    const sctx = canvas.getContext("2d");
    sctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    drawSkyScene(sctx, w, h);
    this.starfieldKey = key;
    this.starfieldCanvas = canvas;
    return canvas;
  }

  beginCrash() {
    this.frozenMult = Math.max(this.crashPoint ?? this.multiplier, this.multiplier, 1);
    this.crashPhase = "falling";
    this.crashAnimStart = performance.now();
    setTimeout(() => {
      if (this.crashPhase === "falling") this.crashPhase = "exploded";
    }, 880);
    setTimeout(() => {
      if (this.crashPhase === "exploded") this.crashPhase = "wreckage";
    }, 1550);
  }

  displayMult() {
    if (this.crashPhase !== "none") return this.frozenMult;
    if (this.phase === "running") return Math.max(this.multiplier, 1);
    if (this.phase === "ended") return Math.max(this.crashPoint ?? this.multiplier, 1);
    return 1;
  }

  rocketPosition(layout, mult, running) {
    const m = running ? mult : this.displayMult();
    const useUncapped = running || this.crashPhase === "falling";
    const peak = layout.point(m, { uncapped: useUncapped });
    const impact = layout.impactPoint(m);
    if (this.crashPhase === "falling") {
      const t = Math.min(1, (performance.now() - this.crashAnimStart) / 850);
      const e = t * t;
      return { x: peak.x, y: peak.y + (impact.y - peak.y) * e };
    }
    if (this.crashPhase === "exploded" || this.crashPhase === "wreckage") return impact;
    return peak;
  }

  loop() {
    if (typeof this.onFrame === "function") this.onFrame(performance.now());
    this.draw();
    this.raf = requestAnimationFrame(() => this.loop());
  }

  draw() {
    const w = this.lastSize.w;
    const h = this.lastSize.h;
    if (!w || !h) return;
    const ctx = this.ctx;
    const now = performance.now();
    this.lastDrawTs = now;
    const liveHistory = typeof this.getLiveHistory === "function" ? this.getLiveHistory() : null;
    const history = liveHistory && liveHistory.length > 1 ? liveHistory : this.history;
    const mult =
      typeof this.getLiveMult === "function"
        ? Math.max(this.getLiveMult(), 1)
        : this.displayMult();
    const running = this.phase === "running" && this.crashPhase === "none";
    const crashAnim = this.crashPhase !== "none";
    const yMax = this.resolveViewYMax(mult, running);
    const layout = new FlightLayout(w, h, yMax);
    const crashed = this.phase === "ended" || this.crashPhase !== "none";

    const starCanvas = this.ensureStarfield(w, h);
    ctx.drawImage(starCanvas, 0, 0, w, h);

    if (running) {
      const g = ctx.createRadialGradient(w * 0.5, h, 0, w * 0.5, h, 220);
      g.addColorStop(0, "rgba(59, 130, 246, 0.1)");
      g.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);
    } else if (crashed) {
      const g = ctx.createRadialGradient(w * 0.3, h * 0.8, 0, w * 0.3, h * 0.8, 280);
      g.addColorStop(0, "rgba(255, 107, 107, 0.14)");
      g.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);
    }

    ctx.setLineDash([4, 6]);
    ctx.lineWidth = 1;
    ctx.strokeStyle = "rgba(100, 130, 180, 0.22)";
    for (const tick of layout.gridTicks) {
      const y = layout.point(tick).y;
      ctx.beginPath();
      ctx.moveTo(layout.padX, y);
      ctx.lineTo(w - layout.padX, y);
      ctx.stroke();
      ctx.fillStyle = "rgba(159, 179, 201, 0.75)";
      ctx.font = "9px ui-monospace, monospace";
      ctx.textAlign = "right";
      const label = tick >= 10 ? tick.toFixed(0) : tick >= 2 ? tick.toFixed(1) : tick.toFixed(2);
      ctx.fillText(`${label}×`, w - 8, y + 3);
    }
    ctx.setLineDash([]);

    const launch = layout.point(1);
    drawLaunchSlingshot(ctx, launch.x, launch.y + 8);

    const heroMult = crashAnim ? this.frozenMult : mult;
    const showHero = (running || crashAnim) && shouldShowHero(heroMult);
    const heroX = launch.x - 38;
    const heroY = h - layout.padY + 2;
    const heroScale = 1.12;
    if (showHero) {
      drawPatrick(ctx, heroX, heroY, heroScale, running, heroMult, this.patrickSprite);
    }

    if (history.length > 1 && (running || crashed)) {
      const grad = ctx.createLinearGradient(layout.padX, 0, w - layout.padX, 0);
      grad.addColorStop(0, THEME.lineViolet);
      grad.addColorStop(1, THEME.linePink);
      ctx.strokeStyle = grad;
      ctx.lineWidth = 2.5;
      ctx.shadowColor = crashed ? THEME.danger : THEME.accent;
      ctx.shadowBlur = 8;
      ctx.beginPath();
      history.forEach((m, i) => {
        const p = layout.point(m, { uncapped: running });
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
      });
      if (running) {
        const head = layout.point(mult, { uncapped: true });
        ctx.lineTo(head.x, head.y);
      }
      ctx.stroke();
      ctx.shadowBlur = 0;

      const fill = ctx.createLinearGradient(0, layout.padY, 0, h);
      fill.addColorStop(0, "rgba(59, 130, 246, 0.22)");
      fill.addColorStop(1, "rgba(59, 130, 246, 0)");
      ctx.fillStyle = fill;
      ctx.lineTo(layout.point(history[history.length - 1]).x, h - layout.padY);
      ctx.lineTo(layout.point(history[0]).x, h - layout.padY);
      ctx.closePath();
      ctx.globalAlpha = 0.5;
      ctx.fill();
      ctx.globalAlpha = 1;
    }

    let pos = this.rocketPosition(layout, mult, running);
    if (this.crashPhase === "none" && !running) {
      this.prevRocketPos = null;
    }
    const angle = running ? this.rocketAngleFromMotion(pos) : this.lastRocketAngle || 0;
    if (running) this.prevRocketPos = { x: pos.x, y: pos.y };
    if (running || crashAnim) {
      const hammerAngle = crashAnim ? angle + 1.55 : angle;
      drawMjolnir(
        ctx,
        pos.x,
        pos.y,
        hammerAngle,
        running ? 0.78 : 0.68,
        running && !crashAnim,
        crashAnim
      );
    }

    if (this.crashPhase === "exploded") {
      drawFeatherBurst(ctx, pos.x, pos.y);
    }

    if (this.crashPhase === "wreckage") {
      ctx.fillStyle = "rgba(30, 41, 59, 0.55)";
      ctx.beginPath();
      ctx.ellipse(pos.x, pos.y + 8, 32, 11, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(251, 191, 36, 0.35)";
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }
}
