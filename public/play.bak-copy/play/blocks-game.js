import { api } from "./shared.js";
import { createBlocksEngine, drawPiece } from "./blocks-engine.js";

async function blocksApi(action, payload) {
  const { ok, data } = await api("/api/mobile/arcade/play", {
    method: "POST",
    body: { gameId: "nfg_blocks", action, payload },
  });
  const res = data || {};
  if (!ok && res.message) throw new Error(res.message);
  if (!ok && res.reason) throw new Error(String(res.reason).replace(/_/g, " "));
  return res;
}

export function mountBlocksGame(container, onWallet) {
  container.innerHTML = `
    <div class="blocks-fullscreen">
      <div class="blocks-topbar">
        <div class="blocks-brand">
          <span class="blocks-logo">🧱</span>
          <div>
            <div class="blocks-title">NFG Blocks</div>
            <div class="blocks-sub">Block Blast — clear rows &amp; columns</div>
          </div>
        </div>
        <div class="blocks-stats">
          <div class="blocks-stat"><span>Session</span><strong id="blkSession">0</strong></div>
          <div class="blocks-stat"><span>Next</span><strong id="blkReward">—</strong></div>
        </div>
      </div>
      <div class="blocks-progress">
        <div class="blocks-level" id="blkLevel">Level 1</div>
        <div class="blocks-bar"><div class="blocks-bar-fill" id="blkBar"></div></div>
        <div class="blocks-lines" id="blkLines">0 / 6 lines</div>
      </div>
      <div class="blocks-board-wrap" id="blkBoardWrap">
        <canvas id="blkCanvas" aria-label="NFG Blocks grid"></canvas>
      </div>
      <div class="blocks-tray" id="blkTray">
        <div class="blocks-tray-label">Pick a shape · drag onto the board</div>
        <div class="blocks-tray-slots">
          <button type="button" class="blocks-tray-slot" data-idx="0" aria-label="Piece 1"></button>
          <button type="button" class="blocks-tray-slot" data-idx="1" aria-label="Piece 2"></button>
          <button type="button" class="blocks-tray-slot" data-idx="2" aria-label="Piece 3"></button>
        </div>
      </div>
      <div class="blocks-drag-ghost hidden" id="blkGhost" aria-hidden="true"></div>
      <div class="blocks-toast hidden" id="blkToast"></div>
    </div>
  `;

  const canvas = container.querySelector("#blkCanvas");
  const boardWrap = container.querySelector("#blkBoardWrap");
  const traySlots = [...container.querySelectorAll(".blocks-tray-slot")];
  const ghostEl = container.querySelector("#blkGhost");
  const ctx = canvas.getContext("2d");
  const engine = createBlocksEngine(8);
  let sessionActive = false;
  let busy = false;
  let drag = null;

  function fmt(n) {
    return Math.floor(Number(n) || 0).toLocaleString();
  }

  function showToast(msg, kind = "info") {
    const el = container.querySelector("#blkToast");
    if (!el) return;
    el.textContent = msg;
    el.className = `blocks-toast blocks-toast--${kind}`;
    el.classList.remove("hidden");
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => el.classList.add("hidden"), 2600);
  }

  function resize() {
    const w = boardWrap?.clientWidth || window.innerWidth;
    engine.setCellSize(Math.floor((Math.min(w, 420) - 20) / 8));
    const total = engine.getCellSize() * 8 + 20;
    canvas.width = total;
    canvas.height = total;
    canvas.style.width = `${total}px`;
    canvas.style.height = `${total}px`;
    renderTray();
    redraw();
  }

  function renderTray() {
    const tray = engine.getTray();
    const sel = engine.getSelected();
    const cell = 16;
    traySlots.forEach((slot, i) => {
      const piece = tray[i];
      slot.classList.toggle("active", i === sel);
      slot.classList.toggle("empty", !piece);
      slot.disabled = !piece || busy;
      let mini = slot.querySelector("canvas");
      if (!mini) {
        mini = document.createElement("canvas");
        slot.innerHTML = "";
        slot.appendChild(mini);
      }
      if (!piece) {
        slot.textContent = "";
        return;
      }
      const rows = piece.shape.length;
      const cols = piece.shape[0].length;
      const pw = cols * cell + 8;
      const ph = rows * cell + 8;
      mini.width = pw;
      mini.height = ph;
      mini.style.width = `${pw}px`;
      mini.style.height = `${ph}px`;
      const mctx = mini.getContext("2d");
      mctx.clearRect(0, 0, pw, ph);
      drawPiece(mctx, piece, pw / 2, ph / 2, cell);
    });
  }

  function updateHud(data = {}) {
    const level = data.level ?? engine.getLevel();
    const target = data.linesTarget ?? engine.getLinesTarget();
    const cleared = engine.getLinesCleared();
    const sess = data.sessionPoints ?? engine.getSessionPoints();
    container.querySelector("#blkLevel").textContent = `Level ${level}`;
    container.querySelector("#blkLines").textContent = `${cleared} / ${target} lines`;
    container.querySelector("#blkSession").textContent = `${fmt(sess)} pts`;
    container.querySelector("#blkReward").textContent =
      data.levelRewardPreview != null ? `+${fmt(data.levelRewardPreview)}` : "—";
    const pct = target ? Math.min(100, (cleared / target) * 100) : 0;
    container.querySelector("#blkBar").style.width = `${pct}%`;
  }

  function redraw(ghost = null) {
    engine.drawGrid(ctx, { ghost });
  }

  async function startGame() {
    if (busy) return;
    busy = true;
    try {
      const data = await blocksApi("start");
      sessionActive = true;
      engine.reset();
      engine.setMetrics(data.level || 1, data.linesTarget || 6, data.sessionPoints || 0);
      updateHud(data);
      renderTray();
      showToast(data.message || "Drag shapes onto the board!", "info");
      if (onWallet) onWallet(data);
      resize();
    } catch (e) {
      showToast(e.message || "Could not start", "err");
    } finally {
      busy = false;
    }
  }

  async function levelClear() {
    const data = await blocksApi("level_clear");
    engine.setSessionPoints(data.sessionPoints || 0);
    engine.afterLevelClear(data);
    updateHud(data);
    renderTray();
    showToast(data.message || `+${fmt(data.gained)} pts!`, "win");
    if (onWallet) onWallet(data);
    redraw();
  }

  async function gameOver() {
    sessionActive = false;
    const data = await blocksApi("game_over");
    updateHud(data);
    showToast(data.message || "No moves left", "err");
    if (onWallet) onWallet(data);
    setTimeout(() => startGame(), 1200);
  }

  async function tryPlace(trayIdx, row, col) {
    if (!sessionActive || busy) return false;
    const out = engine.place(trayIdx, row, col);
    renderTray();
    redraw();
    if (!out.ok) return false;
    if (out.cleared > 0) showToast(`${out.cleared} line${out.cleared > 1 ? "s" : ""} cleared!`, "info");
    updateHud();
    if (out.levelComplete) {
      busy = true;
      try {
        await levelClear();
      } catch (e) {
        showToast(e.message, "err");
      } finally {
        busy = false;
      }
    } else if (out.gameOver) {
      busy = true;
      try {
        await gameOver();
      } catch (e) {
        showToast(e.message, "err");
      } finally {
        busy = false;
      }
    }
    return true;
  }

  function showDragGhost(piece, clientX, clientY) {
    if (!piece || !ghostEl) return;
    const cell = engine.getCellSize() * 0.55;
    const rows = piece.shape.length;
    const cols = piece.shape[0].length;
    const w = cols * cell;
    const h = rows * cell;
    ghostEl.style.width = `${w}px`;
    ghostEl.style.height = `${h}px`;
    ghostEl.innerHTML = "";
    const g = document.createElement("canvas");
    g.width = w;
    g.height = h;
    drawPiece(g.getContext("2d"), piece, w / 2, h / 2, cell);
    ghostEl.appendChild(g);
    ghostEl.classList.remove("hidden");
    ghostEl.style.left = `${clientX - w / 2}px`;
    ghostEl.style.top = `${clientY - h / 2}px`;
  }

  function hideDragGhost() {
    ghostEl?.classList.add("hidden");
  }

  function gridGhostAt(clientX, clientY) {
    if (!drag) return null;
    const piece = engine.getTray()[drag.trayIdx];
    const cell = engine.clientToGrid(canvas, clientX, clientY);
    if (!piece || !cell) return null;
    return { piece, row: cell.row, col: cell.col };
  }

  function beginDrag(trayIdx, clientX, clientY) {
    const piece = engine.getTray()[trayIdx];
    if (!piece || !sessionActive || busy) return;
    engine.selectTray(trayIdx);
    drag = { trayIdx, pointerId: null };
    renderTray();
    showDragGhost(piece, clientX, clientY);
  }

  function moveDrag(clientX, clientY) {
    if (!drag) return;
    const piece = engine.getTray()[drag.trayIdx];
    if (!piece) return;
    const cell = engine.getCellSize();
    const w = piece.shape[0].length * cell * 0.55;
    const h = piece.shape.length * cell * 0.55;
    ghostEl.style.left = `${clientX - w / 2}px`;
    ghostEl.style.top = `${clientY - h / 2}px`;
    redraw(gridGhostAt(clientX, clientY));
  }

  async function endDrag(clientX, clientY) {
    if (!drag) return;
    const idx = drag.trayIdx;
    const cell = engine.clientToGrid(canvas, clientX, clientY);
    hideDragGhost();
    drag = null;
    if (cell) await tryPlace(idx, cell.row, cell.col);
    else redraw();
  }

  traySlots.forEach((slot) => {
    slot.addEventListener("click", () => {
      const idx = Number(slot.dataset.idx);
      if (engine.getTray()[idx]) {
        engine.selectTray(idx);
        renderTray();
      }
    });
  });

  function onPointerDown(e) {
    if (!sessionActive || busy) return;
    const trayBtn = e.target.closest(".blocks-tray-slot");
    if (trayBtn && !trayBtn.disabled) {
      e.preventDefault();
      drag = { trayIdx: Number(trayBtn.dataset.idx), pointerId: e.pointerId };
      try {
        trayBtn.setPointerCapture(e.pointerId);
      } catch {
        /* ignore */
      }
      beginDrag(drag.trayIdx, e.clientX, e.clientY);
      return;
    }
    const cell = engine.clientToGrid(canvas, e.clientX, e.clientY);
    const sel = engine.getSelected();
    if (cell && sel >= 0) tryPlace(sel, cell.row, cell.col);
  }

  function onPointerMove(e) {
    if (!drag || drag.pointerId !== e.pointerId) return;
    e.preventDefault();
    moveDrag(e.clientX, e.clientY);
  }

  function onPointerUp(e) {
    if (!drag || drag.pointerId !== e.pointerId) return;
    endDrag(e.clientX, e.clientY);
    try {
      e.target.releasePointerCapture?.(e.pointerId);
    } catch {
      /* ignore */
    }
  }

  container.addEventListener("pointerdown", onPointerDown);
  container.addEventListener("pointermove", onPointerMove, { passive: false });
  container.addEventListener("pointerup", onPointerUp);
  container.addEventListener("pointercancel", onPointerUp);

  async function ensureSession() {
    try {
      const data = await blocksApi("status");
      if (data.sessionActive) {
        sessionActive = true;
        engine.setMetrics(data.level || 1, data.linesTarget || 6, data.sessionPoints || 0);
        engine.newBoard();
        updateHud(data);
        renderTray();
        resize();
        return;
      }
    } catch (e) {
      showToast(e.message || "Could not load session", "err");
      return;
    }
    await startGame();
  }

  window.addEventListener("resize", resize);
  resize();
  ensureSession();

  return { startGame, ensureSession };
}
