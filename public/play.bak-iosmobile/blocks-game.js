import { api } from "./shared.js";
import { createBlocksEngine } from "./blocks-engine.js";

export function mountBlocksGame(container, onWallet) {
  container.innerHTML = `
    <div class="game-hud">
      <button type="button" class="btn primary" id="blkNew">New game</button>
      <span id="blkHud" class="muted"></span>
    </div>
    <p class="muted game-tip">Tap a piece below, then tap the grid to place. Clear rows or columns to level up.</p>
    <div class="game-canvas-wrap"><canvas id="blkCanvas" width="256" height="346"></canvas></div>
  `;

  const canvas = container.querySelector("#blkCanvas");
  const ctx = canvas.getContext("2d");
  const engine = createBlocksEngine(8);
  let sessionActive = false;
  let hover = null;

  function redraw() {
    engine.draw(ctx, hover);
  }

  async function startGame() {
    const res = await api("/api/mobile/arcade/play", {
      method: "POST",
      body: { gameId: "nfg_blocks", action: "start" },
    });
    sessionActive = true;
    engine.reset();
    redraw();
    container.querySelector("#blkHud").textContent = `Level 1 — clear ${engine.getLinesTarget()} lines`;
    if (onWallet) onWallet(res.wallet || res);
  }

  async function levelClear() {
    const res = await api("/api/mobile/arcade/play", {
      method: "POST",
      body: { gameId: "nfg_blocks", action: "level_clear" },
    });
    container.querySelector("#blkHud").textContent = `+${res.gained || 0} pts — level ${res.level || engine.getLevel()}`;
    if (onWallet) onWallet(res.wallet || res);
    engine.reset();
    redraw();
  }

  async function gameOver() {
    sessionActive = false;
    const res = await api("/api/mobile/arcade/play", {
      method: "POST",
      body: { gameId: "nfg_blocks", action: "game_over" },
    });
    container.querySelector("#blkHud").textContent = `No moves left — ${res.sessionPoints || 0} pts this session`;
    if (onWallet) onWallet(res.wallet || res);
  }

  canvas.addEventListener("pointermove", (e) => {
    const hit = engine.cellFromEvent(canvas, e.clientX, e.clientY);
    if (hit?.row != null) hover = hit;
    else hover = null;
    redraw();
  });

  canvas.addEventListener("pointerleave", () => {
    hover = null;
    redraw();
  });

  canvas.addEventListener("pointerdown", (e) => {
    if (!sessionActive) return;
    const hit = engine.cellFromEvent(canvas, e.clientX, e.clientY);
    if (!hit) return;
    if (hit.tray != null) {
      engine.selectTray(hit.tray);
      redraw();
      return;
    }
    const sel = engine.getSelected();
    if (sel < 0) {
      engine.selectTray(0);
      redraw();
      return;
    }
    const out = engine.place(sel, hit.row, hit.col);
    redraw();
    if (!out.ok) return;
    if (out.levelComplete) levelClear().catch((err) => alert(err.message));
    else if (out.gameOver) gameOver().catch((err) => alert(err.message));
  });

  container.querySelector("#blkNew").addEventListener("click", () => startGame().catch((e) => alert(e.message)));
  redraw();

  return { startGame };
}
