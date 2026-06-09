/** Client-side parallax sky for NFG Jump — new background tier every 7500m. */

const SKY_STOPS = [
  { h: 0, top: "#050810", mid: "#0a1220", bottom: "#070b14", star: 0.35, cloud: 0, glow: 0, ray: 0 },
  { h: 7500, top: "#1a1030", mid: "#2a1848", bottom: "#0f0a18", star: 0.45, cloud: 0.08, glow: 0, ray: 0 },
  { h: 15000, top: "#3d2858", mid: "#6b3a72", bottom: "#1a1028", star: 0.3, cloud: 0.18, glow: 0.05, ray: 0 },
  { h: 22500, top: "#5b7cff", mid: "#8eb5ff", bottom: "#2a4a8a", star: 0.12, cloud: 0.42, glow: 0.08, ray: 0.05 },
  { h: 30000, top: "#7dd3fc", mid: "#bae6fd", bottom: "#3b82c4", star: 0.08, cloud: 0.55, glow: 0.12, ray: 0.08 },
  { h: 37500, top: "#c084fc", mid: "#f0abfc", bottom: "#6d28d9", star: 0.55, cloud: 0.25, glow: 0.35, ray: 0.2 },
  { h: 45000, top: "#fde68a", mid: "#fef3c7", bottom: "#a855f7", star: 0.75, cloud: 0.15, glow: 0.65, ray: 0.45 },
  { h: 52500, top: "#fffbeb", mid: "#fef9c3", bottom: "#e9d5ff", star: 0.9, cloud: 0.08, glow: 0.95, ray: 0.85 },
  { h: 60000, top: "#ffffff", mid: "#fff7ed", bottom: "#fde68a", star: 1, cloud: 0.04, glow: 1, ray: 1 },
];

const STARS = buildStars(56);
const CLOUDS = buildClouds(10);

function buildStars(count) {
  const out = [];
  let seed = 90210;
  const rnd = () => {
    seed = (seed * 16807 + 0) % 2147483647;
    return seed / 2147483647;
  };
  for (let i = 0; i < count; i += 1) {
    out.push({
      x: rnd(),
      y: rnd(),
      r: 0.4 + rnd() * 1.6,
      phase: rnd() * Math.PI * 2,
      parallax: 0.04 + rnd() * 0.08,
    });
  }
  return out;
}

function buildClouds(count) {
  const out = [];
  let seed = 44012;
  const rnd = () => {
    seed = (seed * 48271 + 0) % 2147483647;
    return seed / 2147483647;
  };
  for (let i = 0; i < count; i += 1) {
    out.push({
      x: rnd(),
      y: rnd(),
      w: 0.18 + rnd() * 0.28,
      h: 0.04 + rnd() * 0.07,
      parallax: 0.12 + rnd() * 0.18,
      alpha: 0.25 + rnd() * 0.35,
    });
  }
  return out;
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function lerpColor(c1, c2, t) {
  const p = (hex) => {
    const h = hex.replace("#", "");
    return [
      parseInt(h.slice(0, 2), 16),
      parseInt(h.slice(2, 4), 16),
      parseInt(h.slice(4, 6), 16),
    ];
  };
  const a = p(c1);
  const b = p(c2);
  const mix = (i) => Math.round(lerp(a[i], b[i], t));
  const toHex = (n) => n.toString(16).padStart(2, "0");
  return `#${toHex(mix(0))}${toHex(mix(1))}${toHex(mix(2))}`;
}

function skyMix(height) {
  const h = Math.max(0, height);
  let low = SKY_STOPS[0];
  let high = SKY_STOPS[SKY_STOPS.length - 1];
  for (let i = 0; i < SKY_STOPS.length - 1; i += 1) {
    if (h >= SKY_STOPS[i].h && h < SKY_STOPS[i + 1].h) {
      low = SKY_STOPS[i];
      high = SKY_STOPS[i + 1];
      break;
    }
  }
  const span = Math.max(1, high.h - low.h);
  const t = Math.min(1, Math.max(0, (h - low.h) / span));
  return {
    top: lerpColor(low.top, high.top, t),
    mid: lerpColor(low.mid, high.mid, t),
    bottom: lerpColor(low.bottom, high.bottom, t),
    star: lerp(low.star, high.star, t),
    cloud: lerp(low.cloud, high.cloud, t),
    glow: lerp(low.glow, high.glow, t),
    ray: lerp(low.ray, high.ray, t),
  };
}

function wrapY(y, h) {
  let v = y % h;
  if (v < 0) v += h;
  return v;
}

export function drawJumpSky(ctx, w, h, height, cameraY, elapsed) {
  const sky = skyMix(height);

  const grad = ctx.createLinearGradient(0, 0, 0, h);
  grad.addColorStop(0, sky.top);
  grad.addColorStop(0.45, sky.mid);
  grad.addColorStop(1, sky.bottom);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, w, h);

  if (sky.glow > 0.02) {
    const cx = w * 0.5;
    const cy = h * 0.12;
    const rg = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(w, h) * 0.55);
    rg.addColorStop(0, `rgba(255, 251, 235, ${0.22 * sky.glow})`);
    rg.addColorStop(0.35, `rgba(254, 240, 138, ${0.12 * sky.glow})`);
    rg.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = rg;
    ctx.fillRect(0, 0, w, h);
  }

  if (sky.ray > 0.04) {
    ctx.save();
    ctx.globalAlpha = 0.08 * sky.ray;
    ctx.fillStyle = "#fffbeb";
    const cx = w * 0.5;
    for (let i = 0; i < 7; i += 1) {
      const angle = -Math.PI / 2 + (i - 3) * 0.12;
      ctx.beginPath();
      ctx.moveTo(cx, h * 0.08);
      ctx.lineTo(cx + Math.cos(angle) * w, h * 0.08 + Math.sin(angle) * h * 0.9);
      ctx.lineTo(cx + Math.cos(angle + 0.04) * w, h * 0.08 + Math.sin(angle + 0.04) * h * 0.9);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
  }

  if (sky.star > 0.05) {
    const tw = elapsed * 1.4;
    for (const s of STARS) {
      const sx = s.x * w;
      const sy = wrapY(s.y * h - cameraY * s.parallax, h);
      const pulse = 0.55 + 0.45 * Math.sin(tw + s.phase);
      const alpha = sky.star * pulse * (s.r > 1.2 ? 1 : 0.75);
      ctx.fillStyle = s.r > 1.3 ? `rgba(255, 251, 235, ${alpha})` : `rgba(255, 255, 255, ${alpha})`;
      ctx.beginPath();
      ctx.arc(sx, sy, s.r, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  if (sky.cloud > 0.04) {
    for (const c of CLOUDS) {
      const cx = c.x * w;
      const cy = wrapY(c.y * h - cameraY * c.parallax, h);
      const cw = c.w * w;
      const ch = c.h * h;
      ctx.fillStyle = `rgba(255, 255, 255, ${c.alpha * sky.cloud})`;
      ctx.beginPath();
      ctx.ellipse(cx, cy, cw * 0.5, ch * 0.5, 0, 0, Math.PI * 2);
      ctx.ellipse(cx - cw * 0.22, cy + ch * 0.08, cw * 0.34, ch * 0.42, 0, 0, Math.PI * 2);
      ctx.ellipse(cx + cw * 0.24, cy + ch * 0.05, cw * 0.38, ch * 0.38, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  if (sky.glow > 0.5) {
    ctx.save();
    ctx.globalAlpha = 0.35 * (sky.glow - 0.5) * 2;
    ctx.strokeStyle = "#fff";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(w * 0.5, h * 0.11, 18 + sky.glow * 8, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }
}
