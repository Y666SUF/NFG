/** Block Blast–style 8×8 puzzle — place tray pieces, clear rows/cols. */

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
];

const COLORS = ["#8b5cf6", "#ec4899", "#38bdf8", "#5eead4", "#fbbf24", "#f472b6"];

export function createBlocksEngine(size = 8) {
  let grid = emptyGrid(size);
  let tray = [];
  let selected = -1;
  let linesTarget = 6;
  let linesCleared = 0;
  let level = 1;

  function emptyGrid(n) {
    return Array.from({ length: n }, () => Array(n).fill(0));
  }

  function randomShape() {
    const shape = SHAPES[Math.floor(Math.random() * SHAPES.length)];
    const color = COLORS[Math.floor(Math.random() * COLORS.length)];
    return { shape, color };
  }

  function refillTray() {
    tray = [randomShape(), randomShape(), randomShape()];
    selected = tray.findIndex((p) => canPlaceAnywhere(p)) >= 0 ? 0 : -1;
  }

  function canPlaceAnywhere(piece) {
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        if (canPlace(piece, r, c)) return true;
      }
    }
    return false;
  }

  function reset() {
    grid = emptyGrid(size);
    linesTarget = 6 + (level - 1) * 2;
    linesCleared = 0;
    refillTray();
  }

  function canPlace(piece, row, col) {
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
    selected = Math.min(selected, tray.length - 1);

    const cleared = clearLines();
    linesCleared += cleared;

    let levelComplete = false;
    if (linesCleared >= linesTarget) {
      levelComplete = true;
      level += 1;
      linesTarget = 6 + (level - 1) * 2;
      linesCleared = 0;
      grid = emptyGrid(size);
      refillTray();
    }

    const anyFit = tray.some((p) => canPlaceAnywhere(p));
    return {
      ok: true,
      cleared,
      levelComplete,
      level: level - (levelComplete ? 1 : 0),
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
    for (const r of rows) grid[r] = Array(size).fill(0);
    for (const c of cols) {
      for (let r = 0; r < size; r++) grid[r][c] = 0;
    }
    return count;
  }

  function selectTray(idx) {
    if (idx >= 0 && idx < tray.length) selected = idx;
  }

  function draw(ctx, hover = null) {
    const cell = 32;
    const gridH = size * cell;
    ctx.fillStyle = "#0f1b2a";
    ctx.fillRect(0, 0, size * cell, gridH + 90);

    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        ctx.fillStyle = "rgba(255,255,255,0.04)";
        ctx.fillRect(c * cell, r * cell, cell, cell);
        ctx.strokeStyle = "rgba(255,255,255,0.06)";
        ctx.strokeRect(c * cell + 0.5, r * cell + 0.5, cell - 1, cell - 1);
        if (grid[r][c]) {
          ctx.fillStyle = grid[r][c];
          roundRect(ctx, c * cell + 3, r * cell + 3, cell - 6, cell - 6, 6);
          ctx.fill();
        }
      }
    }

    if (hover && selected >= 0 && tray[selected]) {
      const p = tray[selected];
      if (canPlace(p, hover.row, hover.col)) {
        for (let r = 0; r < p.shape.length; r++) {
          for (let c = 0; c < p.shape[r].length; c++) {
            if (!p.shape[r][c]) continue;
            ctx.fillStyle = "rgba(94,234,212,0.35)";
            roundRect(
              ctx,
              (hover.col + c) * cell + 3,
              (hover.row + r) * cell + 3,
              cell - 6,
              cell - 6,
              6
            );
            ctx.fill();
          }
        }
      }
    }

    const trayY = gridH + 12;
    tray.forEach((p, i) => {
      const tx = 8 + i * 84;
      const ty = trayY;
      ctx.fillStyle = i === selected ? "rgba(79,209,255,0.2)" : "rgba(255,255,255,0.05)";
      roundRect(ctx, tx - 4, ty - 4, 72, 56, 8);
      ctx.fill();
      if (i === selected) {
        ctx.strokeStyle = "#4fd1ff";
        ctx.lineWidth = 2;
        ctx.stroke();
      }
      for (let r = 0; r < p.shape.length; r++) {
        for (let c = 0; c < p.shape[r].length; c++) {
          if (!p.shape[r][c]) continue;
          ctx.fillStyle = p.color;
          roundRect(ctx, tx + c * 14, ty + r * 14, 12, 12, 3);
          ctx.fill();
        }
      }
    });

    ctx.fillStyle = "#9fb3c9";
    ctx.font = "12px Outfit, system-ui";
    ctx.fillText(`Level ${level} · ${linesCleared}/${linesTarget} lines`, 4, gridH + 82);
  }

  function cellFromEvent(canvas, clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    const x = (clientX - rect.left) * scaleX;
    const y = (clientY - rect.top) * scaleY;
    const cell = 32;
    if (y >= size * cell) {
      const trayY = size * cell + 12;
      const idx = Math.floor((x - 4) / 84);
      if (y >= trayY - 4 && y <= trayY + 52 && idx >= 0 && idx < tray.length) return { tray: idx };
      return null;
    }
    return { row: Math.floor(y / cell), col: Math.floor(x / cell) };
  }

  return {
    reset,
    place,
    selectTray,
    draw,
    cellFromEvent,
    getLevel: () => level,
    getLinesTarget: () => linesTarget,
    getSelected: () => selected,
    getTray: () => tray,
  };
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
