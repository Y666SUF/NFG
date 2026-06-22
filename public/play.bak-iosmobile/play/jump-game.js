import { api } from "./shared.js";
import { createJumpEngine } from "./jump-engine.js";

export function mountJumpGame(container, onWallet) {
  container.innerHTML = `
    <div class="game-hud">
      <button type="button" class="btn" id="jmpNew">New run</button>
      <button type="button" class="btn" id="jmpEnd">End run</button>
      <span id="jmpHud" class="muted"></span>
    </div>
    <div class="game-canvas-wrap"><canvas id="jmpCanvas" width="320" height="480"></canvas></div>
    <p class="muted">Tap canvas or press Space to jump. ← → to move. +3,000 pts every 2,500m syncs to server.</p>
  `;

  const canvas = container.querySelector("#jmpCanvas");
  const ctx = canvas.getContext("2d");
  const engine = createJumpEngine();
  const input = { left: false, right: false, jump: false };
  let raf = 0;
  let sessionActive = false;
  let syncing = false;

  async function startRun() {
    const res = await api("/api/mobile/arcade/play", {
      method: "POST",
      body: { gameId: "nfg_snake_jump", action: "start" },
    });
    sessionActive = true;
    engine.reset();
    container.querySelector("#jmpHud").textContent = `Session pts: ${res.sessionPoints || 0}`;
    if (onWallet) onWallet(res.wallet || res);
    loop();
  }

  async function syncMilestone(height) {
    if (syncing) return;
    syncing = true;
    try {
      const res = await api("/api/mobile/arcade/play", {
        method: "POST",
        body: {
          gameId: "nfg_snake_jump",
          action: "milestone",
          payload: { height },
        },
      });
      container.querySelector("#jmpHud").textContent = `+${res.gained || 0} pts — session ${res.sessionPoints || 0}`;
      if (onWallet) onWallet(res.wallet || res);
    } finally {
      syncing = false;
    }
  }

  async function endRun(peak) {
    cancelAnimationFrame(raf);
    sessionActive = false;
    const res = await api("/api/mobile/arcade/play", {
      method: "POST",
      body: {
        gameId: "nfg_snake_jump",
        action: "game_over",
        payload: { height: peak },
      },
    });
    container.querySelector("#jmpHud").textContent = `Run over — ${peak}m peak, ${res.sessionPoints || 0} pts`;
    if (onWallet) onWallet(res.wallet || res);
  }

  function loop() {
    const frame = engine.step(input);
    input.jump = false;
    engine.draw(ctx, frame);
    if (frame.milestoneDue) syncMilestone(frame.milestoneDue);
    if (!frame.alive && sessionActive) {
      const peak = engine.stop();
      endRun(peak);
      return;
    }
    if (sessionActive) raf = requestAnimationFrame(loop);
  }

  container.querySelector("#jmpNew").addEventListener("click", () => startRun().catch((e) => alert(e.message)));
  container.querySelector("#jmpEnd").addEventListener("click", () => {
    if (!sessionActive) return;
    endRun(engine.getPeak());
  });

  const jump = () => {
    input.jump = true;
  };
  canvas.addEventListener("pointerdown", jump);
  window.addEventListener("keydown", (e) => {
    if (e.key === "ArrowLeft") input.left = true;
    if (e.key === "ArrowRight") input.right = true;
    if (e.key === " " || e.key === "ArrowUp") jump();
  });
  window.addEventListener("keyup", (e) => {
    if (e.key === "ArrowLeft") input.left = false;
    if (e.key === "ArrowRight") input.right = false;
  });

  return { startRun };
}
