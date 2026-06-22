/** Crash chart — ports iOS CrashChartView monotonic rise + stream rocket head. */

const CHART_W = 400;
const CHART_H = 200;
const PAD_X = 24;
const PAD_Y = 16;

export function monotonicRisePoints(history, phase, width, height) {
  const vals = seriesValues(history, phase);
  if (!vals.length) return [];

  const innerW = Math.max(1, width - PAD_X * 2);
  const innerH = Math.max(1, height - PAD_Y * 2);
  const minMult = 1;
  let runningPeak = Math.max(1.12, vals[0]);
  const points = [];

  for (let i = 0; i < vals.length; i++) {
    const value = Math.max(vals[i], minMult);
    runningPeak = Math.max(runningPeak, value);
    const x = PAD_X + (innerW * i) / Math.max(vals.length - 1, 1);
    const t = (value - minMult) / (runningPeak - minMult);
    const y = height - PAD_Y - innerH * Math.min(Math.max(t, 0), 1);
    points.push({ x, y });
  }

  for (let i = 1; i < points.length; i++) {
    if (points[i].y > points[i - 1].y) points[i].y = points[i - 1].y;
  }
  return points;
}

function seriesValues(history, phase) {
  if (phase === "betting" || phase === "idle" || !history?.length) return [1];
  const out = [];
  for (const v of history) {
    const clamped = Math.max(Number(v) || 1, 1);
    if (out.length && clamped < out[out.length - 1] - 0.0001) continue;
    out.push(clamped);
  }
  return out.length ? out : [1];
}

export function mountCrashChart(root) {
  root.innerHTML = `
    <div class="chart-wrap">
      <div class="chart-watermark" aria-hidden="true"><span class="wm-nfg">NFG</span><span class="wm-crash">CRASH</span></div>
      <svg class="chart-svg" viewBox="0 0 ${CHART_W} ${CHART_H}" preserveAspectRatio="none" aria-hidden="true">
        <defs>
          <linearGradient id="playAreaGrad" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stop-color="rgba(94,234,212,0.45)"/>
            <stop offset="100%" stop-color="rgba(94,234,212,0)"/>
          </linearGradient>
          <linearGradient id="playLineGrad" x1="0" y1="1" x2="1" y2="0">
            <stop offset="0%" stop-color="#8b5cf6"/>
            <stop offset="100%" stop-color="#ec4899"/>
          </linearGradient>
          <filter id="playLineGlow"><feGaussianBlur stdDeviation="2"/><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
        </defs>
        <path id="playArea" fill="url(#playAreaGrad)" d=""/>
        <path id="playLine" fill="none" stroke="url(#playLineGrad)" stroke-width="2.5" stroke-linecap="round" filter="url(#playLineGlow)" d=""/>
        <g id="playRocket" transform="translate(24,176)">
          <text font-size="18" text-anchor="middle" dominant-baseline="middle">🚀</text>
        </g>
      </svg>
      <div id="playCrashFlash" class="chart-crash-flash hidden"></div>
    </div>`;

  const line = root.querySelector("#playLine");
  const area = root.querySelector("#playArea");
  const rocket = root.querySelector("#playRocket");
  const flash = root.querySelector("#playCrashFlash");

  function draw(history, phase, multiplier) {
    const pts = monotonicRisePoints(history, phase, CHART_W, CHART_H);
    const h = CHART_H;
    const ended = phase === "ended";

    if (pts.length < 2) {
      const y = h - 16;
      line.setAttribute("d", `M ${PAD_X} ${y} L ${CHART_W - PAD_X} ${y}`);
      line.setAttribute("stroke", "rgba(255,255,255,0.14)");
      line.removeAttribute("filter");
      area.setAttribute("d", "");
      rocket.setAttribute("transform", `translate(${PAD_X},${y})`);
      flash.classList.add("hidden");
      return;
    }

    let d = `M ${pts[0].x} ${pts[0].y}`;
    for (let i = 1; i < pts.length; i++) d += ` L ${pts[i].x} ${pts[i].y}`;
    line.setAttribute("d", d);
    const last = pts[pts.length - 1];
    area.setAttribute(
      "d",
      `${d} L ${last.x} ${h - PAD_Y} L ${pts[0].x} ${h - PAD_Y} Z`
    );

    if (ended) {
      line.setAttribute("stroke", "#ff6b6b");
      line.removeAttribute("filter");
      flash.classList.remove("hidden");
    } else {
      line.setAttribute("stroke", "url(#playLineGrad)");
      line.setAttribute("filter", "url(#playLineGlow)");
      flash.classList.add("hidden");
    }

    rocket.setAttribute("transform", `translate(${last.x - 9},${last.y - 10})`);
  }

  return { draw };
}
