/** NFG Jump — TikTok DM emoji bounce: avatar in circle, touch steer, auto bounce. */

const GRAVITY = 0.38;
const BOUNCE_VEL = -10.2;
const MOVE_SPEED = 5.5;
const PLAYER_R = 22;

export function createJumpEngine(opts = {}) {
  let width = opts.width || 360;
  let height = opts.height || 640;
  let player = { x: 0, y: 0, vy: 0, onGround: false };
  let platforms = [];
  let cameraY = 0;
  let peakMeters = 0;
  let running = false;
  let lastMilestoneSent = 0;
  let steerX = null;
  let touching = false;

  function setSize(w, h) {
    width = Math.max(280, Math.floor(w));
    height = Math.max(400, Math.floor(h));
    player.x = width / 2;
  }

  function reset() {
    player = { x: width / 2, y: -PLAYER_R, vy: 0, onGround: true };
    platforms = [{ x: width / 2 - 70, y: 0, w: 140, h: 14, type: "safe", vx: 0 }];
    for (let i = 1; i < 28; i++) platforms.push(spawnPlatform(i * 52));
    cameraY = 0;
    peakMeters = 0;
    running = true;
    lastMilestoneSent = 0;
    steerX = null;
    touching = false;
  }

  function spawnPlatform(dist) {
    const roll = Math.random();
    let type = "safe";
    if (roll > 0.82) type = "spike";
    else if (roll > 0.58) type = "moving";
    const w = 56 + Math.floor(Math.random() * 56);
    const maxX = Math.max(16, width - w - 16);
    const x = 16 + Math.random() * maxX;
    const vx = type === "moving" ? (Math.random() < 0.5 ? -1.45 : 1.45) : 0;
    return { x, y: -dist, w, h: 14, type, vx };
  }

  function metersFromY(y) {
    return Math.max(0, Math.floor(-y / 4));
  }

  function setTouch(steer, active) {
    steerX = steer;
    touching = active;
  }

  function step() {
    if (!running) return { alive: false, meters: peakMeters, milestoneDue: null };

    if (touching && steerX != null) {
      player.x += (steerX - player.x) * 0.28;
    }
    player.x = Math.max(PLAYER_R + 4, Math.min(width - PLAYER_R - 4, player.x));

    player.vy += GRAVITY;
    player.y += player.vy;
    player.onGround = false;

    for (const p of platforms) {
      if (p.type === "moving") {
        p.x += p.vx;
        if (p.x < 8 || p.x + p.w > width - 8) p.vx *= -1;
      }
    }

    for (const p of platforms) {
      const foot = player.y + PLAYER_R;
      const prevFoot = foot - player.vy;
      if (
        player.vy > 0 &&
        prevFoot <= p.y &&
        foot >= p.y - 2 &&
        player.x > p.x + 6 &&
        player.x < p.x + p.w - 6
      ) {
        if (p.type === "spike") {
          running = false;
          return { alive: false, meters: peakMeters, milestoneDue: null, died: true };
        }
        player.y = p.y - PLAYER_R;
        player.vy = BOUNCE_VEL;
        player.onGround = true;
        if (p.type === "moving") player.x += p.vx * 0.55;
      }
    }

    if (player.y > cameraY + height * 0.55) {
      running = false;
      return { alive: false, meters: peakMeters, milestoneDue: null, fell: true };
    }

    const meters = metersFromY(player.y);
    peakMeters = Math.max(peakMeters, meters);
    cameraY = Math.min(cameraY, player.y - height * 0.38);

    while (platforms.length < 34 || platforms[platforms.length - 1].y > cameraY - height * 0.85) {
      const top = platforms[platforms.length - 1];
      platforms.push(spawnPlatform(-top.y + 42 + Math.random() * 28));
    }

    let milestoneDue = null;
    const next = (lastMilestoneSent + 1) * 2500;
    if (peakMeters >= next) {
      lastMilestoneSent += 1;
      milestoneDue = peakMeters;
    }

    return { alive: true, meters: peakMeters, milestoneDue, player, platforms, cameraY };
  }

  function drawPlatform(ctx, p) {
    const { x, y, w, h, type } = p;
    if (type === "spike") {
      ctx.fillStyle = "#3f1218";
      roundRect(ctx, x, y, w, h, 6);
      ctx.fill();
      ctx.fillStyle = "#ef4444";
      const spikes = Math.max(3, Math.floor(w / 14));
      const sw = w / spikes;
      for (let i = 0; i < spikes; i++) {
        ctx.beginPath();
        ctx.moveTo(x + i * sw, y);
        ctx.lineTo(x + i * sw + sw / 2, y - 10);
        ctx.lineTo(x + (i + 1) * sw, y);
        ctx.closePath();
        ctx.fill();
      }
      ctx.strokeStyle = "rgba(255,107,107,0.5)";
      ctx.lineWidth = 1;
      roundRect(ctx, x, y, w, h, 6);
      ctx.stroke();
      return;
    }
    if (type === "moving") {
      const g = ctx.createLinearGradient(x, y, x + w, y);
      g.addColorStop(0, "#38bdf8");
      g.addColorStop(1, "#818cf8");
      ctx.fillStyle = g;
      roundRect(ctx, x, y, w, h, 8);
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,0.35)";
      ctx.font = "10px system-ui";
      ctx.textAlign = "center";
      ctx.fillText("↔", x + w / 2, y + h - 3);
      return;
    }
    const g = ctx.createLinearGradient(x, y, x, y + h);
    g.addColorStop(0, "#4ade80");
    g.addColorStop(1, "#16a34a");
    ctx.fillStyle = g;
    roundRect(ctx, x, y, w, h, 8);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,0.18)";
    ctx.lineWidth = 1;
    roundRect(ctx, x, y, w, h, 8);
    ctx.stroke();
  }

  function drawPlayer(ctx, player, avatarImg, displayInitial) {
    const px = player.x;
    const py = player.y;
    const r = PLAYER_R;

    ctx.save();
    ctx.beginPath();
    ctx.ellipse(px, py + r + 4, r * 0.7, 6, 0, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(0,0,0,0.35)";
    ctx.fill();
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.arc(px, py, r + 3, 0, Math.PI * 2);
    ctx.strokeStyle = "#4fd1ff";
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(px, py, r, 0, Math.PI * 2);
    ctx.closePath();
    ctx.clip();
    if (avatarImg && avatarImg.complete && avatarImg.naturalWidth > 0) {
      ctx.drawImage(avatarImg, px - r, py - r, r * 2, r * 2);
    } else {
      const g = ctx.createLinearGradient(px - r, py - r, px + r, py + r);
      g.addColorStop(0, "#8b5cf6");
      g.addColorStop(1, "#ec4899");
      ctx.fillStyle = g;
      ctx.fillRect(px - r, py - r, r * 2, r * 2);
      ctx.fillStyle = "#eef6ff";
      ctx.font = `bold ${Math.floor(r * 1.1)}px system-ui`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(String(displayInitial || "?").charAt(0).toUpperCase(), px, py + 1);
    }
    ctx.restore();
  }

  function draw(ctx, frame, avatarImg, displayInitial) {
    const grad = ctx.createLinearGradient(0, 0, 0, height);
    grad.addColorStop(0, "#0a1020");
    grad.addColorStop(0.5, "#070b12");
    grad.addColorStop(1, "#0f1b2a");
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, width, height);

    ctx.save();
    ctx.translate(0, -frame.cameraY);
    for (const p of frame.platforms) drawPlatform(ctx, p);
    drawPlayer(ctx, frame.player, avatarImg, displayInitial);
    ctx.restore();

    ctx.fillStyle = "rgba(238,247,255,0.92)";
    ctx.font = "bold 15px system-ui";
    ctx.textAlign = "left";
    ctx.fillText(`${frame.meters || 0} m`, 14, 28);
    ctx.font = "11px system-ui";
    ctx.fillStyle = "rgba(159,179,201,0.9)";
    ctx.fillText("Touch left/right to steer", 14, height - 16);
  }

  function stop() {
    running = false;
    return peakMeters;
  }

  return { setSize, reset, setTouch, step, draw, stop, getPeak: () => peakMeters };
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
