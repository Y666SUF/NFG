/** Canvas crash chart — galaxy, rocket flight path, iOS-style (PC + play). */
const THEME = {
  accent: "#4fd1ff",
  accent2: "#7ee7c4",
  danger: "#ff6b6b",
  danger2: "#ec4899",
  muted: "#9fb3c9",
  border: "rgba(255,255,255,0.14)",
  space: "#030208",
  lineViolet: "#8b5cf6",
  linePink: "#ec4899",
};

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

  point(mult) {
    const m = Math.max(mult, 1);
    const denom = Math.max(this.yMax - 1, 0.12);
    const t = Math.min(Math.max((m - 1) / denom, 0), 1);
    const eased = Math.pow(t, 0.92);
    const x = this.padX + this.innerW * (0.08 + 0.84 * eased);
    const y = this.height - this.padY - this.innerH * t;
    return { x, y };
  }

  flightAngle(mult) {
    const m = Math.max(mult, 1.01);
    const p0 = this.point(Math.max(1, m - 0.08));
    const p1 = this.point(m);
    return Math.atan2(p1.x - p0.x, -(p1.y - p0.y));
  }

  impactPoint(mult) {
    const peak = this.point(mult);
    return { x: peak.x, y: this.height - this.padY };
  }
}

function drawStarfield(ctx, w, h) {
  ctx.fillStyle = THEME.space;
  ctx.fillRect(0, 0, w, h);

  const g1 = ctx.createRadialGradient(w * 0.22, h * 0.28, 0, w * 0.22, h * 0.28, w * 0.65);
  g1.addColorStop(0, "rgba(72, 38, 130, 0.22)");
  g1.addColorStop(0.45, "rgba(28, 48, 88, 0.14)");
  g1.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = g1;
  ctx.fillRect(0, 0, w, h);

  const g2 = ctx.createRadialGradient(w * 0.78, h * 0.42, 0, w * 0.78, h * 0.42, w * 0.58);
  g2.addColorStop(0, "rgba(96, 36, 92, 0.16)");
  g2.addColorStop(0.5, "rgba(24, 56, 96, 0.1)");
  g2.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = g2;
  ctx.fillRect(0, 0, w, h);

  const vignette = ctx.createRadialGradient(w * 0.5, h * 0.55, 0, w * 0.5, h * 0.55, Math.max(w, h) * 0.72);
  vignette.addColorStop(0, "rgba(0,0,0,0)");
  vignette.addColorStop(1, "rgba(0,0,0,0.55)");
  ctx.fillStyle = vignette;
  ctx.fillRect(0, 0, w, h);

  const scale = Math.min(w, h) < 200 ? 2.3 : 1.7;
  for (let i = 0; i < 220; i += 1) {
    const seed = i * 97 + 13;
    const x = ((Math.sin(seed) * 0.5 + 0.5) * w) | 0;
    const y = ((Math.cos(seed * 1.31) * 0.5 + 0.5) * h) | 0;
    const tier = i % 11;
    const r = (tier === 0 ? 2.6 : tier < 4 ? 1.7 : 1.0) * scale * 0.45;
    const alpha = tier === 0 ? 0.72 : 0.35 + (i % 7) * 0.04;
    ctx.fillStyle = i % 19 === 0 ? `rgba(235, 220, 255, ${alpha})` : `rgba(255,255,255,${alpha})`;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawRocket(ctx, x, y, angle, scale, thrust, crashed) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(crashed ? 1.65 : angle);
  ctx.scale(scale, scale);

  if (thrust && !crashed) {
    const flicker = 0.85 + Math.sin(performance.now() * 0.012) * 0.15;
    const g = ctx.createRadialGradient(0, 38, 0, 0, 52, 28);
    g.addColorStop(0, `rgba(255, 200, 80, ${0.9 * flicker})`);
    g.addColorStop(0.5, `rgba(255, 120, 40, ${0.55 * flicker})`);
    g.addColorStop(1, "rgba(255,80,0,0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.ellipse(0, 44, 10, 22, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  const body = ctx.createLinearGradient(-12, -30, 12, 30);
  body.addColorStop(0, "#e8eef8");
  body.addColorStop(0.45, "#9eb4d4");
  body.addColorStop(1, "#5a6d8a");
  ctx.fillStyle = body;
  ctx.beginPath();
  if (typeof ctx.roundRect === "function") ctx.roundRect(-11, -18, 22, 44, 5);
  else ctx.rect(-11, -18, 22, 44);
  ctx.fill();

  ctx.fillStyle = THEME.accent;
  ctx.beginPath();
  ctx.moveTo(0, -38);
  ctx.lineTo(-11, -18);
  ctx.lineTo(11, -18);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = "#4a5568";
  ctx.beginPath();
  ctx.moveTo(-11, 18);
  ctx.lineTo(-20, 30);
  ctx.lineTo(-11, 24);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(11, 18);
  ctx.lineTo(20, 30);
  ctx.lineTo(11, 24);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = "rgba(79, 209, 255, 0.35)";
  ctx.fillRect(-6, -4, 12, 10);

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
    this.lastSize = { w: 0, h: 0 };
    this.getLiveMult = null;
    this.getLiveHistory = null;
    this.onFrame = null;
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
  }

  /** Smooth vertical scale so the rocket climb does not jump when yMax grows. */
  resolveViewYMax(mult, running, historySrc = this.history) {
    const histPeak = historySrc.length ? Math.max(...historySrc) : 1;
    const head = Math.max(mult, histPeak, 1);
    const target = Math.max(head * 1.22, 1.65);
    if (running) {
      if (target > this.viewYMax) {
        this.viewYMax += (target - this.viewYMax) * 0.06;
      }
    } else if (this.phase === "ended" || this.crashPhase !== "none") {
      this.viewYMax += (target - this.viewYMax) * 0.12;
    } else {
      this.viewYMax = target;
    }
    return Math.max(this.viewYMax, head * 1.08, 1.5);
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

  rocketPosition(layout) {
    const mult = this.displayMult();
    const peak = layout.point(mult);
    const impact = layout.impactPoint(mult);
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
    const liveHistory = typeof this.getLiveHistory === "function" ? this.getLiveHistory() : null;
    const history = liveHistory && liveHistory.length > 1 ? liveHistory : this.history;
    const mult =
      typeof this.getLiveMult === "function"
        ? Math.max(this.getLiveMult(), 1)
        : this.displayMult();
    const running = this.phase === "running" && this.crashPhase === "none";
    const yMax = this.resolveViewYMax(mult, running, history);
    const layout = new FlightLayout(w, h, yMax);
    const crashed = this.phase === "ended" || this.crashPhase !== "none";

    drawStarfield(ctx, w, h);

    if (running) {
      const g = ctx.createRadialGradient(0, h, 0, 0, h, 260);
      g.addColorStop(0, "rgba(79, 209, 255, 0.08)");
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
    ctx.strokeStyle = "rgba(255,255,255,0.08)";
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
        const p = layout.point(m);
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
      });
      ctx.stroke();
      ctx.shadowBlur = 0;

      const fill = ctx.createLinearGradient(0, layout.padY, 0, h);
      fill.addColorStop(0, "rgba(94, 234, 212, 0.35)");
      fill.addColorStop(1, "rgba(94, 234, 212, 0)");
      ctx.fillStyle = fill;
      ctx.lineTo(layout.point(history[history.length - 1]).x, h - layout.padY);
      ctx.lineTo(layout.point(history[0]).x, h - layout.padY);
      ctx.closePath();
      ctx.globalAlpha = 0.5;
      ctx.fill();
      ctx.globalAlpha = 1;
    }

    const launch = layout.point(1);
    const lg = ctx.createRadialGradient(launch.x, launch.y + 10, 0, launch.x, launch.y + 10, 36);
    lg.addColorStop(0, "rgba(79, 209, 255, 0.45)");
    lg.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = lg;
    ctx.beginPath();
    ctx.ellipse(launch.x, launch.y + 10, 36, 12, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,0.12)";
    ctx.fillRect(launch.x - 24, launch.y + 4, 48, 8);

    const pos =
      running || (this.crashPhase === "none" && this.phase === "running")
        ? layout.point(mult)
        : this.rocketPosition(layout);
    const angle =
      this.crashPhase === "falling" ? 1.7 : layout.flightAngle(running ? mult : this.displayMult());
    const showRocket = this.crashPhase !== "wreckage";
    if (showRocket) {
      drawRocket(ctx, pos.x, pos.y, angle, running ? 0.52 : 0.48, running, this.crashPhase === "falling");
    }

    if (this.crashPhase === "exploded") {
      const g = ctx.createRadialGradient(pos.x, pos.y, 0, pos.x, pos.y, 74);
      g.addColorStop(0, "rgba(255,255,255,0.95)");
      g.addColorStop(0.35, "rgba(255, 107, 107, 0.75)");
      g.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(pos.x, pos.y, 74, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}
