/** NFG Blocks — Block Blast: 8×8 grid, 3 tray pieces, row + column clears. */

const SHAPES = [
  [[1]],
  [[1, 1]],
  [[1, 1, 1]],
  [[1, 1, 1, 1]],
  [[1, 1], [1, 1]],
  [[1, 1, 1], [0, 1, 0]],
  [[1, 1, 0], [0, 1, 1]],
  [[0, 1, 1], [1, 1, 0]],
  [[1, 0, 0], [1, 1, 1]],
  [[0, 0, 1], [1, 1, 1]],
  [[1, 1, 1], [1, 0, 0]],
  [[1, 1, 1], [0, 0, 1]],
  [[1], [1], [1]],
  [[1], [1], [1], [1]],
  [[1, 0], [1, 0], [1, 1]],
  [[0, 1], [0, 1], [1, 1]],
  [[1, 1, 1], [1, 1, 1]],
];

const COLORS = ["#a855f7", "#ec4899", "#38bdf8", "#22d3ee", "#fbbf24", "#fb7185", "#4ade80", "#818cf8"];

export function createBlocksEngine(size = 8) {
  let grid = emptyGrid(size);
  let tray = [];
  let selected = -1;
  let level = 1;
  let linesTarget = 6;
  let linesCleared = 0;
  let sessionPoints = 0;
  let cellSize = 36;

  function emptyGrid(n) {
    return Array.from({ length: n }, () => Array(n).fill(null));
  }

  function randomPiece() {
    const shape = SHAPES[Math.floor(Math.random() * SHAPES.length)];
    const color = COLORS[Math.floor(Math.random() * COLORS.length)];
    return { shape, color };
  }

  function refillTray() {
    tray = [randomPiece(), randomPiece(), randomPiece()];
    if (selected >= tray.length) selected = tray.length ? 0 : -1;
  }

  function setMetrics(nextLevel, nextTarget, nextSessionPts = sessionPoints) {
    level = Math.max(1, Math.floor(Number(nextLevel) || 1));
    linesTarget = Math.max(1, Math.floor(Number(nextTarget) || blockBlastLinesTarget(level)));
    linesCleared = 0;
    sessionPoints = Math.max(0, Math.floor(Number(nextSessionPts) || 0));
  }

  function blockBlastLinesTarget(lv) {
    return 6 + (Math.max(1, lv) - 1) * 2;
  }

  function resetBoard(keepLevel = true) {
    grid = emptyGrid(size);
    if (!keepLevel) {
      level = 1;
      linesTarget = 6;
      linesCleared = 0;
    }
    refillTray();
    selected = tray.length ? 0 : -1;
  }

  function reset() {
    resetBoard(false);
    sessionPoints = 0;
  }

  function newBoard() {
    grid = emptyGrid(size);
    refillTray();
    selected = tray.length ? 0 : -1;
  }

  function canPlaceAnywhere(piece) {
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        if (canPlace(piece, r, c)) return true;
      }
    }
    return false;
  }

  function canPlace(piece, row, col) {
    if (!piece) return false;
    for (let r = 0; r < piece.shape.length; r++) {
      for (let c = 0; c < piece.shape[r].length; c++) {
        if (!piece.shape[r][c]) continue;
        const rr = row + r;
        const cc = col + c;
        if (rr < 0 || rr >= size || cc < 0 || cc >= size) return false;
        if (grid[rr][cc]) return false;
      }
    }
    return true;
  }

  function place(trayIdx, row, col) {
    const piece = tray[trayIdx];
    if (!piece || !canPlace(piece, row, col)) return { ok: false };

    for (let r = 0; r < piece.shape.length; r++) {
      for (let c = 0; c < piece.shape[r].length; c++) {
        if (!piece.shape[r][c]) continue;
        grid[row + r][col + c] = piece.color;
      }
    }
    tray.splice(trayIdx, 1);
    if (!tray.length) refillTray();
    selected = tray.length ? Math.min(selected, tray.length - 1) : -1;
    if (selected < 0 && tray.length) selected = 0;

    const cleared = clearLines();
    linesCleared += cleared;

    const levelComplete = linesCleared >= linesTarget;
    const anyFit = tray.some((p) => canPlaceAnywhere(p));
    return {
      ok: true,
      cleared,
      levelComplete,
      level,
      linesCleared,
      linesTarget,
      gameOver: !anyFit,
    };
  }

  function clearLines() {
    const rows = new Set();
    const cols = new Set();
    for (let r = 0; r < size; r++) {
      if (grid[r].every((v) => v)) rows.add(r);
    }
    for (let c = 0; c < size; c++) {
      let full = true;
      for (let r = 0; r < size; r++) {
        if (!grid[r][c]) {
          full = false;
          break;
        }
      }
      if (full) cols.add(c);
    }
    const count = rows.size + cols.size;
    if (!count) return 0;
    for (const r of rows) grid[r] = Array(size).fill(null);
    for (const c of cols) {
      for (let r = 0; r < size; r++) grid[r][c] = null;
    }
    return count;
  }

  function afterLevelClear(serverData) {
    const cleared = Math.max(1, Math.floor(Number(serverData?.level) || level));
    const nextLevel = cleared + 1;
    setMetrics(
      nextLevel,
      serverData?.linesTarget ?? blockBlastLinesTarget(nextLevel),
      serverData?.sessionPoints ?? sessionPoints
    );
    grid = emptyGrid(size);
    refillTray();
    selected = 0;
  }

  function setCellSize(px) {
    cellSize = Math.max(32, Math.min(56, Math.floor(px)));
  }

  function gridPixelSize() {
    const pad = 10;
    return { pad, gridPx: size * cellSize, total: size * cellSize + pad * 2 };
  }

  function clientToGrid(canvas, clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    const x = clientX - rect.left;
    const y = clientY - rect.top;
    const { pad, gridPx } = gridPixelSize();
    if (x < pad || y < pad || x > pad + gridPx || y > pad + gridPx) return null;
    return {
      row: Math.floor((y - pad) / cellSize),
      col: Math.floor((x - pad) / cellSize),
    };
  }

  function selectTray(idx) {
    if (idx >= 0 && idx < tray.length) selected = idx;
  }

  function drawGrid(ctx, opts = {}) {
    const { ghost = null } = opts;
    const { pad, gridPx, total } = gridPixelSize();
    if (ctx.canvas.width !== total) ctx.canvas.width = total;
    if (ctx.canvas.height !== total) ctx.canvas.height = total;

    const grad = ctx.createLinearGradient(0, 0, 0, total);
    grad.addColorStop(0, "#0c1424");
    grad.addColorStop(1, "#070b12");
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, total, total);

    ctx.fillStyle = "rgba(15,27,42,0.98)";
    roundRect(ctx, pad - 2, pad - 2, gridPx + 4, gridPx + 4, 14);
    ctx.fill();
    ctx.strokeStyle = "rgba(79,209,255,0.3)";
    ctx.lineWidth = 2;
    ctx.stroke();

    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        const x = pad + c * cellSize;
        const y = pad + r * cellSize;
        ctx.fillStyle = "rgba(255,255,255,0.04)";
        roundRect(ctx, x + 2, y + 2, cellSize - 4, cellSize - 4, 6);
        ctx.fill();
        if (grid[r][c]) {
          drawBlock(ctx, x + 3, y + 3, cellSize - 6, grid[r][c]);
        }
      }
    }

    if (ghost?.piece && ghost.row != null && ghost.col != null && canPlace(ghost.piece, ghost.row, ghost.col)) {
      for (let r = 0; r < ghost.piece.shape.length; r++) {
        for (let c = 0; c < ghost.piece.shape[r].length; c++) {
          if (!ghost.piece.shape[r][c]) continue;
          const x = pad + (ghost.col + c) * cellSize + 3;
          const y = pad + (ghost.row + r) * cellSize + 3;
          ctx.fillStyle = "rgba(94,234,212,0.4)";
          roundRect(ctx, x, y, cellSize - 6, cellSize - 6, 6);
          ctx.fill();
        }
      }
    }
  }

  return {
    reset,
    resetBoard,
    newBoard,
    place,
    selectTray,
    setMetrics,
    afterLevelClear,
    setCellSize,
    clientToGrid,
    drawGrid,
    drawPiece,
    getLevel: () => level,
    getLinesTarget: () => linesTarget,
    getLinesCleared: () => linesCleared,
    getSelected: () => selected,
    getTray: () => tray,
    getCellSize: () => cellSize,
    getSessionPoints: () => sessionPoints,
    setSessionPoints: (n) => {
      sessionPoints = Math.max(0, Number(n) || 0);
    },
    canPlaceAnywhere: () => tray.some((p) => canPlaceAnywhere(p)),
    canPlace,
  };
}

export function drawPiece(ctx, piece, cx, cy, cell) {
  if (!piece) return;
  const rows = piece.shape.length;
  const cols = piece.shape[0].length;
  const ox = cx - (cols * cell) / 2;
  const oy = cy - (rows * cell) / 2;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < piece.shape[r].length; c++) {
      if (!piece.shape[r][c]) continue;
      drawBlock(ctx, ox + c * cell, oy + r * cell, cell - 2, piece.color);
    }
  }
}

function drawBlock(ctx, x, y, w, color) {
  const g = ctx.createLinearGradient(x, y, x + w, y + w);
  g.addColorStop(0, lighten(color, 0.15));
  g.addColorStop(1, color);
  ctx.fillStyle = g;
  roundRect(ctx, x, y, w, w, Math.min(8, w * 0.22));
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.22)";
  ctx.lineWidth = 1;
  ctx.stroke();
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

function lighten(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.min(255, ((n >> 16) & 255) + 255 * amt);
  const g = Math.min(255, ((n >> 8) & 255) + 255 * amt);
  const b = Math.min(255, (n & 255) + 255 * amt);
  return `rgb(${r | 0},${g | 0},${b | 0})`;
}
