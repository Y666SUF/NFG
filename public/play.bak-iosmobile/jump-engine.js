/** Client-only NFG Jump physics (server credits milestones via REST). */
const GRAVITY = 0.42;
const JUMP_VEL = -9.5;
const MOVE_SPEED = 4.2;

export function createJumpEngine() {
  let player = { x: 80, y: 0, vy: 0, onGround: false, jumpsLeft: 1 };
  let platforms = [];
  let cameraY = 0;
  let peakMeters = 0;
  let running = false;
  let lastMilestoneSent = 0;

  function reset() {
    player = { x: 80, y: 0, vy: 0, onGround: true, jumpsLeft: 1 };
    platforms = [{ x: 40, y: 0, w: 120, h: 14, type: "safe", vx: 0 }];
    for (let i = 1; i < 24; i++) {
      platforms.push(spawnPlatform(i * 55));
    }
    cameraY = 0;
    peakMeters = 0;
    running = true;
    lastMilestoneSent = 0;
  }

  function spawnPlatform(height) {
    const types = ["safe", "safe", "yellow", "blue", "red"];
    const type = types[Math.floor(Math.random() * types.length)];
    const w = 50 + Math.floor(Math.random() * 50);
    const x = 20 + Math.random() * (280 - w);
    const vx = type === "blue" ? (Math.random() < 0.5 ? -1.2 : 1.2) : 0;
    return { x, y: -height, w, h: 12, type, vx };
  }

  function metersFromY(y) {
    return Math.max(0, Math.floor(-y / 4));
  }

  function step(input) {
    if (!running) return { alive: false, meters: peakMeters, milestoneDue: null };

    if (input.left) player.x -= MOVE_SPEED;
    if (input.right) player.x += MOVE_SPEED;
    player.x = Math.max(8, Math.min(292, player.x));

    if (input.jump && player.onGround && player.jumpsLeft > 0) {
      player.vy = JUMP_VEL;
      player.onGround = false;
      player.jumpsLeft -= 1;
    }

    player.vy += GRAVITY;
    player.y += player.vy;
    player.onGround = false;

    for (const p of platforms) {
      if (p.type === "blue") p.x += p.vx;
      if (p.x < 0 || p.x + p.w > 320) p.vx *= -1;
    }

    for (const p of platforms) {
      const foot = player.y + 18;
      const prevFoot = foot - player.vy;
      if (
        player.vy > 0 &&
        prevFoot <= p.y &&
        foot >= p.y &&
        player.x + 10 > p.x &&
        player.x + 10 < p.x + p.w
      ) {
        if (p.type === "red") {
          running = false;
          return { alive: false, meters: peakMeters, milestoneDue: null, died: true };
        }
        player.y = p.y - 18;
        player.vy = 0;
        player.onGround = true;
        player.jumpsLeft = p.type === "yellow" ? 1 : 2;
        if (p.type === "blue") player.x += p.vx * 0.5;
      }
    }

    if (player.y > cameraY + 220) {
      running = false;
      return { alive: false, meters: peakMeters, milestoneDue: null, fell: true };
    }

    const meters = metersFromY(player.y);
    peakMeters = Math.max(peakMeters, meters);
    cameraY = Math.min(cameraY, player.y - 80);

    while (platforms.length < 30 || platforms[platforms.length - 1].y > cameraY - 400) {
      const top = platforms[platforms.length - 1];
      platforms.push(spawnPlatform(-top.y + 45 + Math.random() * 25));
    }

    let milestoneDue = null;
    const next = (lastMilestoneSent + 1) * 2500;
    if (peakMeters >= next) {
      lastMilestoneSent += 1;
      milestoneDue = peakMeters;
    }

    return { alive: true, meters: peakMeters, milestoneDue, player, platforms, cameraY };
  }

  function draw(ctx, frame) {
    const { player, platforms, cameraY } = frame;
    const grad = ctx.createLinearGradient(0, 0, 0, 480);
    grad.addColorStop(0, "#070b12");
    grad.addColorStop(1, "#0f1b2a");
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, 320, 480);
    ctx.save();
    ctx.translate(0, -cameraY);
    for (const p of platforms) {
      ctx.fillStyle =
        p.type === "safe"
          ? "#22c55e"
          : p.type === "yellow"
            ? "#eab308"
            : p.type === "blue"
              ? "#3b82f6"
              : "#ef4444";
      ctx.fillRect(p.x, p.y, p.w, p.h);
    }
    const px = player.x + 10;
    const py = player.y + 2;
    ctx.font = "22px system-ui";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("🚀", px, py);
    if (player.vy < -2) {
      ctx.globalAlpha = 0.5;
      ctx.fillText("🔥", px, py + 14);
      ctx.globalAlpha = 1;
    }
    ctx.restore();
    ctx.fillStyle = "#94a3b8";
    ctx.font = "14px system-ui";
    ctx.fillText(`${frame.meters || 0} m`, 10, 22);
  }

  function stop() {
    running = false;
    return peakMeters;
  }

  return { reset, step, draw, stop, getPeak: () => peakMeters };
}
