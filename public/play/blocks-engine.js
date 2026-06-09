const SHAPES = [
  [[0, 0]],
  [[0, 0], [0, 1]],
  [[0, 0], [0, 1], [0, 2]],
  [[0, 0], [0, 1], [0, 2], [0, 3]],
  [[0, 0], [0, 1], [1, 0], [1, 1]],
  [[0, 0], [0, 1], [1, 0]],
  [[0, 0], [0, 1], [1, 1]],
  [[0, 0], [1, 0], [1, 1]],
  [[0, 1], [1, 0], [1, 1]],
  [[0, 0], [0, 1], [0, 2], [1, 1]],
  [[0, 0], [1, 0], [1, 1], [1, 2]],
  [[0, 2], [1, 0], [1, 1], [1, 2]],
  [[0, 0], [0, 1], [1, 1], [1, 2]],
  [[0, 1], [0, 2], [1, 0], [1, 1]],
  [[0, 0], [0, 1], [0, 2], [1, 0], [1, 2]],
];

const COLORS = ["#22d3ee", "#a78bfa", "#4ade80", "#fb7185", "#fbbf24", "#38bdf8"];
export const GRID_SIZE = 8;

function cells(shapeId, rotation) {
  const base = SHAPES[Math.max(0, Math.min(SHAPES.length - 1, shapeId))];
  let cells = base.map(([r, c]) => [r, c]);
  const turns = ((rotation % 4) + 4) % 4;
  for (let t = 0; t < turns; t += 1) {
    cells = cells.map(([r, c]) => [c, -r]);
    const minR = Math.min(...cells.map((x) => x[0]));
    const minC = Math.min(...cells.map((x) => x[1]));
    cells = cells.map(([r, c]) => [r - minR, c - minC]);
  }
  return cells;
}

function nextRandom(rng) {
  rng = (rng * 6364136223846793005n + 1n) & 0xffffffffffffffffn;
  return { rng, val: Number(rng >> 32n) };
}

function randomPiece(rng) {
  let r = { rng: BigInt(rng || 0x4e4647426c6b73) };
  let v;
  ({ rng: r.rng, val: v } = nextRandom(r.rng));
  const shapeId = v % SHAPES.length;
  ({ rng: r.rng, val: v } = nextRandom(r.rng));
  const rotation = v % 4;
  ({ rng: r.rng, val: v } = nextRandom(r.rng));
  const colorIndex = v % COLORS.length;
  return {
    id: crypto.randomUUID(),
    shapeId,
    rotation,
    colorIndex,
    rngSeed: Number(r.rng),
  };
}

export function linesTarget(level) {
  return Math.max(4, 6 + (Math.max(1, level) - 1) * 2);
}

export function freshState(level = 1) {
  const state = {
    grid: Array.from({ length: GRID_SIZE }, () => Array(GRID_SIZE).fill(null)),
    tray: [null, null, null],
    level: Math.max(1, level),
    linesThisLevel: 0,
    linesTarget: linesTarget(level),
    totalLines: 0,
    score: 0,
    gameOver: false,
    rngSeed: 0x4e4647426c6b73,
  };
  refillTray(state);
  return state;
}

export function refillTray(state) {
  if (!state.tray.every((p) => p == null)) return;
  for (let i = 0; i < 3; i += 1) {
    const p = randomPiece(state.rngSeed);
    state.rngSeed = p.rngSeed;
    delete p.rngSeed;
    state.tray[i] = p;
  }
}

export function canPlace(piece, row, col, grid) {
  for (const [dr, dc] of cells(piece.shapeId, piece.rotation)) {
    const r = row + dr;
    const c = col + dc;
    if (r < 0 || c < 0 || r >= GRID_SIZE || c >= GRID_SIZE) return false;
    if (grid[r][c] != null) return false;
  }
  return true;
}

function clearLines(state) {
  const rows = new Set();
  const cols = new Set();
  const clearedCells = [];
  for (let r = 0; r < GRID_SIZE; r += 1) {
    if (state.grid[r].every((v) => v != null)) rows.add(r);
  }
  for (let c = 0; c < GRID_SIZE; c += 1) {
    let full = true;
    for (let r = 0; r < GRID_SIZE; r += 1) {
      if (state.grid[r][c] == null) {
        full = false;
        break;
      }
    }
    if (full) cols.add(c);
  }
  for (const r of rows) {
    for (let c = 0; c < GRID_SIZE; c += 1) {
      clearedCells.push([r, c]);
      state.grid[r][c] = null;
    }
  }
  for (const c of cols) {
    for (let r = 0; r < GRID_SIZE; r += 1) {
      if (!clearedCells.some(([rr, cc]) => rr === r && cc === c)) clearedCells.push([r, c]);
      state.grid[r][c] = null;
    }
  }
  return rows.size + cols.size;
}

export function hasAnyMove(state) {
  for (const piece of state.tray.filter(Boolean)) {
    for (let r = 0; r < GRID_SIZE; r += 1) {
      for (let c = 0; c < GRID_SIZE; c += 1) {
        if (canPlace(piece, r, c, state.grid)) return true;
      }
    }
  }
  return false;
}

export function placePiece(state, piece, row, col) {
  if (!canPlace(piece, row, col, state.grid)) return null;
  for (const [dr, dc] of cells(piece.shapeId, piece.rotation)) {
    state.grid[row + dr][col + dc] = piece.colorIndex;
  }
  const idx = state.tray.findIndex((p) => p && p.id === piece.id);
  if (idx >= 0) state.tray[idx] = null;
  const cleared = clearLines(state);
  state.linesThisLevel += cleared;
  state.totalLines += cleared;
  state.score += cleared * 10 * state.level;
  refillTray(state);
  if (!hasAnyMove(state)) state.gameOver = true;
  return { clearedLines: cleared, gameOver: state.gameOver };
}

export function pieceCells(piece) {
  return cells(piece.shapeId, piece.rotation);
}

export function colorFor(index) {
  return COLORS[index % COLORS.length];
}

export function blocksStorageKey(userId) {
  const u = String(userId || "guest").trim().toLowerCase() || "guest";
  return `nfg_blocks_web_v1_${u}`;
}

export function saveBlocksState(userId, state) {
  if (state.gameOver || !state.tray.some(Boolean)) {
    localStorage.removeItem(blocksStorageKey(userId));
    return;
  }
  localStorage.setItem(blocksStorageKey(userId), JSON.stringify(state));
}

export function loadBlocksState(userId) {
  try {
    const raw = localStorage.getItem(blocksStorageKey(userId));
    if (!raw) return null;
    const s = JSON.parse(raw);
    if (!s || s.gameOver) return null;
    return s;
  } catch {
    return null;
  }
}
