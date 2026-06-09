import {
  GRID_SIZE,
  freshState,
  canPlace,
  placePiece,
  pieceCells,
  colorFor,
  linesTarget,
  saveBlocksState,
  loadBlocksState,
} from "./blocks-engine.js";
import { getSession, esc } from "./shared.js";

export function mountBlocksGame(container, hooks) {
  let board = loadBlocksState(getSession().userId) || freshState(hooks.serverLevel || 1);
  let selected = null;
  let busy = false;

  const wrap = document.createElement("div");
  wrap.className = "skill-game blocks-game";
  wrap.innerHTML = `
    <div class="skill-hud" id="blocksHud"></div>
    <div class="blocks-grid-wrap" id="blocksGrid"></div>
    <div class="blocks-tray" id="blocksTray"></div>
    <p class="arcade-msg" id="blocksMsg"></p>
    <div class="btn-row">
      <button type="button" class="btn primary" id="blocksNew">New game</button>
    </div>
  `;
  container.appendChild(wrap);

  const hud = wrap.querySelector("#blocksHud");
  const gridEl = wrap.querySelector("#blocksGrid");
  const trayEl = wrap.querySelector("#blocksTray");
  const msgEl = wrap.querySelector("#blocksMsg");

  function setMsg(t) {
    msgEl.textContent = t || "";
  }

  function syncHud() {
    hud.innerHTML = `
      <span>Lv <strong>${board.level}</strong></span>
      <span>Lines ${board.linesThisLevel}/${board.linesTarget}</span>
      <span>Session ${(hooks.sessionPoints || 0).toLocaleString()} pts</span>
    `;
  }

  function renderGrid() {
    gridEl.innerHTML = "";
    gridEl.style.gridTemplateColumns = `repeat(${GRID_SIZE}, 1fr)`;
    for (let r = 0; r < GRID_SIZE; r += 1) {
      for (let c = 0; c < GRID_SIZE; c += 1) {
        const cell = document.createElement("button");
        cell.type = "button";
        cell.className = "blocks-cell";
        const v = board.grid[r][c];
        if (v != null) {
          cell.style.background = colorFor(v);
          cell.classList.add("filled");
        }
        cell.dataset.row = String(r);
        cell.dataset.col = String(c);
        if (selected && canPlace(selected, r, c, board.grid)) {
          cell.classList.add("hint");
        }
        cell.addEventListener("click", () => onCell(r, c));
        gridEl.appendChild(cell);
      }
    }
  }

  function renderTray() {
    trayEl.innerHTML = "";
    board.tray.forEach((piece, idx) => {
      const slot = document.createElement("button");
      slot.type = "button";
      slot.className = "blocks-piece-slot";
      if (!piece) {
        slot.classList.add("empty");
        slot.textContent = "—";
      } else {
        const mini = document.createElement("div");
        mini.className = "blocks-mini";
        const maxR = Math.max(...pieceCells(piece).map((x) => x[0]));
        const maxC = Math.max(...pieceCells(piece).map((x) => x[1]));
        mini.style.gridTemplateColumns = `repeat(${maxC + 1}, 10px)`;
        for (let r = 0; r <= maxR; r += 1) {
          for (let c = 0; c <= maxC; c += 1) {
            const dot = document.createElement("span");
            const on = pieceCells(piece).some(([pr, pc]) => pr === r && pc === c);
            dot.className = on ? "on" : "";
            if (on) dot.style.background = colorFor(piece.colorIndex);
            mini.appendChild(dot);
          }
        }
        slot.appendChild(mini);
        if (selected && selected.id === piece.id) slot.classList.add("sel");
        slot.addEventListener("click", () => {
          selected = selected && selected.id === piece.id ? null : piece;
          renderAll();
        });
      }
      trayEl.appendChild(slot);
    });
  }

  function renderAll() {
    board.linesTarget = linesTarget(board.level);
    syncHud();
    renderGrid();
    renderTray();
    saveBlocksState(getSession().userId, board);
  }

  async function onCell(row, col) {
    if (!selected || busy) return;
    const result = placePiece(board, selected, row, col);
    if (!result) return;
    selected = null;
    renderAll();
    if (result.clearedLines > 0) {
      setMsg(`+${result.clearedLines} line${result.clearedLines > 1 ? "s" : ""}!`);
    }
    if (board.linesThisLevel >= board.linesTarget) {
      busy = true;
      try {
        const res = await hooks.onLevelClear();
        board.level = res?.level || board.level + 1;
        board.linesThisLevel = 0;
        board.linesTarget = linesTarget(board.level);
        setMsg(res?.message || `Level cleared! +${res?.gained || 0} pts`);
        hooks.sessionPoints = res?.sessionPoints ?? hooks.sessionPoints;
      } catch (e) {
        setMsg(e.message);
      } finally {
        busy = false;
      }
      renderAll();
    }
    if (board.gameOver) {
      busy = true;
      try {
        const res = await hooks.onGameOver();
        setMsg(res?.message || "Board full — session ended.");
        board = freshState(res?.level || 1);
        hooks.sessionPoints = res?.sessionPoints ?? 0;
      } catch (e) {
        setMsg(e.message);
      } finally {
        busy = false;
      }
      renderAll();
    }
  }

  wrap.querySelector("#blocksNew").addEventListener("click", async () => {
    if (busy) return;
    busy = true;
    try {
      const res = await hooks.onStart();
      board = loadBlocksState(getSession().userId) || freshState(res?.level || 1);
      hooks.sessionPoints = res?.sessionPoints ?? 0;
      selected = null;
      setMsg(res?.message || "New game started!");
      renderAll();
    } catch (e) {
      setMsg(e.message);
    } finally {
      busy = false;
    }
  });

  if (hooks.sessionActive) {
    board = loadBlocksState(getSession().userId) || freshState(hooks.serverLevel || 1);
  }
  renderAll();

  return {
    destroy() {
      wrap.remove();
    },
    refresh(h) {
      Object.assign(hooks, h);
      if (h.serverLevel) board.level = h.serverLevel;
      renderAll();
    },
  };
}
