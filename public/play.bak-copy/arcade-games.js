import { api, fmt, esc } from "./shared.js";

const RANK_LABELS = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
const SUIT_SYM = { spades: "♠", hearts: "♥", diamonds: "♦", clubs: "♣" };
const SUIT_COLOR = { spades: "#e8eef6", hearts: "#f87171", diamonds: "#f87171", clubs: "#e8eef6" };

async function play(gameId, action, payload = {}) {
  const { ok, data } = await api("/api/mobile/arcade/play", {
    method: "POST",
    body: { gameId, action, payload },
  });
  const res = data || {};
  if (!ok && res.message) throw new Error(res.message);
  if (!ok && res.reason) throw new Error(String(res.reason).replace(/_/g, " "));
  return res;
}

function cardHTML(rank, suit, large = false) {
  const label = RANK_LABELS[rank] || String(rank);
  const sym = SUIT_SYM[suit] || "•";
  const color = SUIT_COLOR[suit] || "#fff";
  const red = suit === "hearts" || suit === "diamonds";
  return `<div class="playing-card${large ? " playing-card--lg" : ""}${red ? " playing-card--red" : ""}">
    <span class="card-corner card-corner-tl" style="color:${color}">${label}<small>${sym}</small></span>
    <span class="card-rank" style="color:${color}">${label}</span>
    <span class="card-suit" style="color:${color}">${sym}</span>
    <span class="card-corner card-corner-br" style="color:${color}">${label}<small>${sym}</small></span>
  </div>`;
}

function stakeRow(defaultVal = 1200) {
  return `<label class="field">Stake <input class="a-stake" type="number" value="${defaultVal}" min="100" step="100" /></label>`;
}

function resultBanner(res) {
  const won = res.won || res.win;
  const cls = won ? "result-win" : res.bust || res.mineHit ? "result-lose" : "result-neutral";
  return `<div class="game-result ${cls}">${esc(res.message || (won ? `+${res.gained || 0} pts` : "Round over"))}</div>`;
}

export function mountDiceGame(panel, msgEl, onWallet) {
  panel.innerHTML = `
    <div class="vault-game-card dice-game">
      <div class="vault-game-head">
        <span class="vault-game-icon">🎲</span>
        <div>
          <h3 class="vault-game-title">Roll Line</h3>
          <p class="vault-game-sub">Under or Over the line · 0.00–99.99</p>
        </div>
      </div>
      ${stakeRow(1200)}
      <div class="dice-mode-row">
        <button type="button" class="dice-mode active" data-mode="under">UNDER</button>
        <button type="button" class="dice-mode" data-mode="over">OVER</button>
      </div>
      <div class="dice-line-panel">
        <div class="dice-line-label">Target line <strong class="a-target-val">50.00</strong></div>
        <div class="dice-line-track">
          <div class="dice-line-win" id="diceWinZone"></div>
          <div class="dice-line-marker" id="diceMarker"></div>
          <input class="a-target dice-slider" type="range" min="2" max="98" value="50" />
        </div>
        <div class="dice-line-ticks"><span>0</span><span>50</span><span>99</span></div>
      </div>
      <div class="dice-roll-stage">
        <div class="dice-roll-glow"></div>
        <div class="dice-result-pill" id="diceResultPill">—</div>
        <div class="dice-face" id="diceFace">—</div>
        <div class="dice-roll-hint muted">Roll lands on the line — win if inside your zone</div>
      </div>
      <button type="button" class="btn primary block vault-cta a-roll">ROLL</button>
      <div class="a-out"></div>
    </div>
  `;
  let mode = "under";
  panel.querySelectorAll(".dice-mode").forEach((b) => {
    b.addEventListener("click", () => {
      mode = b.dataset.mode;
      panel.querySelectorAll(".dice-mode").forEach((x) => x.classList.toggle("active", x === b));
      syncTarget();
    });
  });
  const slider = panel.querySelector(".a-target");
  const winZone = panel.querySelector("#diceWinZone");
  const marker = panel.querySelector("#diceMarker");
  const syncTarget = () => {
    const val = Number(slider.value);
    panel.querySelectorAll(".a-target-val").forEach((el) => {
      el.textContent = val.toFixed(2);
    });
    const pct = ((val - 2) / 96) * 100;
    marker.style.left = `${pct}%`;
    if (mode === "under") {
      winZone.style.left = "0%";
      winZone.style.width = `${pct}%`;
      winZone.className = "dice-line-win dice-line-win--under";
    } else {
      winZone.style.left = `${pct}%`;
      winZone.style.width = `${100 - pct}%`;
      winZone.className = "dice-line-win dice-line-win--over";
    }
  };
  slider.addEventListener("input", syncTarget);
  syncTarget();
  panel.querySelector(".a-roll").addEventListener("click", async () => {
    const face = panel.querySelector("#diceFace");
    const stage = panel.querySelector(".dice-roll-stage");
    face.classList.add("rolling");
    stage.classList.add("rolling");
    try {
      const res = await play("nfg_dice", "play", {
        stake: Number(panel.querySelector(".a-stake").value),
        mode,
        target: Number(slider.value),
      });
      face.classList.remove("rolling");
      stage.classList.remove("rolling");
      const roll = Number(res.roll ?? res.actual ?? 0).toFixed(2);
      face.textContent = roll;
      face.classList.toggle("win", !!res.won);
      face.classList.toggle("lose", !res.won);
      const pill = panel.querySelector("#diceResultPill");
      if (pill) {
        pill.textContent = roll;
        pill.classList.toggle("win", !!res.won);
        pill.classList.toggle("lose", !res.won);
      }
      panel.querySelector(".a-out").innerHTML = resultBanner(res);
      if (onWallet) onWallet(res.wallet || res);
    } catch (e) {
      face.classList.remove("rolling");
      stage?.classList.remove("rolling");
      msgEl.textContent = e.message;
    }
  });
}

export function mountHiloGame(panel, msgEl, onWallet) {
  panel.innerHTML = `
    <div class="vault-game-card hilo-game">
      <div class="vault-game-head">
        <span class="vault-game-icon">🃏</span>
        <div>
          <h3 class="vault-game-title">Higher / Lower</h3>
          <p class="vault-game-sub">Chain guesses · cash out anytime</p>
        </div>
      </div>
      ${stakeRow(1500)}
      <button type="button" class="btn primary block vault-cta h-start">DEAL CARD</button>
      <div class="hilo-table">
        <div class="hilo-felt">
          <div class="hilo-mult-pill"><span id="hiloMult">×1.00</span> · streak <span id="hiloStreak">0</span></div>
          <div id="hiloCard" class="hilo-card-slot"><span class="hilo-deal-hint">Tap Deal to start</span></div>
        </div>
        <div class="hilo-actions hidden" id="hiloActions">
          <button type="button" class="hilo-btn h-hi">▲ HIGHER</button>
          <button type="button" class="hilo-btn h-lo">▼ LOWER</button>
          <button type="button" class="btn secondary block h-cash">Cash out</button>
        </div>
      </div>
      <div class="h-out"></div>
    </div>
  `;
  const actions = panel.querySelector("#hiloActions");
  const render = (res) => {
    const rank = res.cardRank ?? res.nextCardRank;
    const suit = res.cardSuit ?? res.nextCardSuit;
    if (rank) panel.querySelector("#hiloCard").innerHTML = cardHTML(rank, suit, true);
    panel.querySelector("#hiloMult").textContent = `×${Number(res.multiplier || 1).toFixed(2)}`;
    panel.querySelector("#hiloStreak").textContent = String(res.streak || 0);
    actions.classList.toggle("hidden", !res.sessionActive);
    if (res.message) panel.querySelector(".h-out").innerHTML = resultBanner(res);
    if (onWallet) onWallet(res.wallet || res);
  };
  panel.querySelector(".h-start").addEventListener("click", async () => {
    try {
      render(await play("nfg_hilo", "start", { stake: Number(panel.querySelector(".a-stake").value) }));
    } catch (e) {
      msgEl.textContent = e.message;
    }
  });
  panel.querySelector(".h-hi").addEventListener("click", () => guess("hi"));
  panel.querySelector(".h-lo").addEventListener("click", () => guess("lo"));
  panel.querySelector(".h-cash").addEventListener("click", async () => {
    try {
      render(await play("nfg_hilo", "cashout"));
    } catch (e) {
      msgEl.textContent = e.message;
    }
  });
  async function guess(direction) {
    try {
      render(await play("nfg_hilo", "guess", { direction }));
    } catch (e) {
      msgEl.textContent = e.message;
    }
  }
  play("nfg_hilo", "status").then(render).catch(() => {});
}

export function mountMinesGame(panel, msgEl, onWallet) {
  let session = null;
  let minePositions = [];
  panel.innerHTML = `
    <div class="game-intro muted">Reveal gems — avoid mines. Cash out anytime.</div>
    ${stakeRow(2000)}
    <label class="field">Mines
      <select class="m-count"><option value="3">3 mines</option><option value="5">5 mines</option><option value="8">8 mines</option></select>
    </label>
    <div class="mines-hud"><span id="mMult">×1.00</span><button type="button" class="btn accent2 m-cash">Cash out</button></div>
    <button type="button" class="btn primary block m-start">Start</button>
    <div class="mines-grid" id="mGrid"></div>
    <div class="m-out"></div>
  `;
  const grid = panel.querySelector("#mGrid");

  function renderGrid(revealed = [], bustIdx = -1) {
    grid.innerHTML = "";
    for (let i = 0; i < 25; i++) {
      const b = document.createElement("button");
      b.type = "button";
      const isMine = minePositions.includes(i);
      const open = revealed.includes(i) || (bustIdx === i && isMine);
      if (open) {
        b.textContent = isMine ? "💣" : "💎";
        b.classList.add(isMine ? "boom" : "gem");
        b.disabled = true;
      } else if (!session) {
        b.disabled = true;
      } else {
        b.textContent = "";
        b.addEventListener("click", () => reveal(i));
      }
      grid.appendChild(b);
    }
  }

  async function reveal(index) {
    try {
      const res = await play("nfg_mines", "reveal", { index });
      session = res.sessionActive ? res : null;
      if (res.minePositions) minePositions = res.minePositions;
      panel.querySelector("#mMult").textContent = `×${Number(res.multiplier || 1).toFixed(2)}`;
      renderGrid(res.revealed || [], res.mineHit ? res.mineHitIndex : -1);
      if (res.message) panel.querySelector(".m-out").innerHTML = resultBanner(res);
      if (onWallet) onWallet(res.wallet || res);
      if (!res.ok || !res.sessionActive) session = null;
    } catch (e) {
      msgEl.textContent = e.message;
    }
  }

  panel.querySelector(".m-start").addEventListener("click", async () => {
    try {
      const res = await play("nfg_mines", "start", {
        stake: Number(panel.querySelector(".a-stake").value),
        mines: Number(panel.querySelector(".m-count").value),
      });
      session = res.sessionActive ? res : null;
      minePositions = [];
      panel.querySelector("#mMult").textContent = `×${Number(res.multiplier || 1).toFixed(2)}`;
      renderGrid(res.revealed || []);
      if (onWallet) onWallet(res.wallet || res);
    } catch (e) {
      msgEl.textContent = e.message;
    }
  });

  panel.querySelector(".m-cash").addEventListener("click", async () => {
    try {
      const res = await play("nfg_mines", "cashout");
      session = null;
      if (res.minePositions) minePositions = res.minePositions;
      renderGrid(res.revealed || []);
      panel.querySelector(".m-out").innerHTML = resultBanner(res);
      if (onWallet) onWallet(res.wallet || res);
    } catch (e) {
      msgEl.textContent = e.message;
    }
  });

  renderGrid();
}

export function mountPlinkoGame(panel, msgEl, onWallet) {
  panel.innerHTML = `
    <div class="game-intro muted">Drop the ball — risk tier sets the payout spread.</div>
    ${stakeRow(1800)}
    <div class="seg-control">
      <button type="button" class="seg active" data-risk="low">Low</button>
      <button type="button" class="seg" data-risk="med">Med</button>
      <button type="button" class="seg" data-risk="high">High</button>
    </div>
    <button type="button" class="btn primary block p-drop">Drop</button>
    <div class="plinko-board"><canvas id="plinkoCanvas" width="300" height="320"></canvas></div>
    <div class="p-out"></div>
  `;
  let risk = "med";
  const canvas = panel.querySelector("#plinkoCanvas");
  const ctx = canvas.getContext("2d");
  const buckets = 11;

  panel.querySelectorAll(".seg").forEach((b) => {
    b.addEventListener("click", () => {
      risk = b.dataset.risk;
      panel.querySelectorAll(".seg").forEach((x) => x.classList.toggle("active", x === b));
    });
  });

  function drawBoard(highlight = -1) {
    ctx.clearRect(0, 0, 300, 320);
    ctx.fillStyle = "#0f1b2a";
    ctx.fillRect(0, 0, 300, 320);
    for (let row = 0; row < 8; row++) {
      for (let col = 0; col <= row; col++) {
        const x = 150 + (col - row / 2) * 28;
        const y = 30 + row * 28;
        ctx.fillStyle = "rgba(79,209,255,0.5)";
        ctx.beginPath();
        ctx.arc(x, y, 4, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    for (let i = 0; i < buckets; i++) {
      const x = 20 + i * 24;
      ctx.fillStyle = i === highlight ? "#5eead4" : "rgba(255,255,255,0.08)";
      ctx.fillRect(x, 268, 22, 40);
    }
  }

  async function animateDrop(targetIdx) {
    let x = 150;
    let y = 8;
    for (let step = 0; step < 24; step++) {
      await new Promise((r) => setTimeout(r, 45));
      y += 10;
      x += (Math.random() - 0.5) * 18;
      drawBoard();
      ctx.fillStyle = "#fbbf24";
      ctx.beginPath();
      ctx.arc(x, y, 7, 0, Math.PI * 2);
      ctx.fill();
    }
    drawBoard(targetIdx);
  }

  drawBoard();
  panel.querySelector(".p-drop").addEventListener("click", async () => {
    try {
      const res = await play("nfg_plinko", "play", {
        stake: Number(panel.querySelector(".a-stake").value),
        risk,
      });
      await animateDrop(res.segmentIndex ?? 5);
      panel.querySelector(".p-out").innerHTML = resultBanner(res);
      if (onWallet) onWallet(res.wallet || res);
    } catch (e) {
      msgEl.textContent = e.message;
    }
  });
}

export function mountWheelGame(panel, msgEl, onWallet) {
  panel.innerHTML = `
    <div class="game-intro muted">Spin the vault wheel — jackpots are rare.</div>
    ${stakeRow(2500)}
    <button type="button" class="btn primary block w-spin">Spin</button>
    <div class="wheel-wrap"><canvas id="wheelCanvas" width="280" height="280"></canvas><div class="wheel-pointer">▼</div></div>
    <div class="w-out"></div>
  `;
  const canvas = panel.querySelector("#wheelCanvas");
  const ctx = canvas.getContext("2d");
  const labels = ["LOSE", "½", "1.5×", "2×", "3×", "JACK"];
  const colors = ["#374151", "#64748b", "#8b5cf6", "#3b82f6", "#ec4899", "#fbbf24"];
  let angle = 0;

  function drawWheel(rot = 0, highlight = -1) {
    const cx = 140;
    const cy = 140;
    const r = 120;
    ctx.clearRect(0, 0, 280, 280);
    const n = labels.length;
    const slice = (Math.PI * 2) / n;
    for (let i = 0; i < n; i++) {
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.fillStyle = i === highlight ? "#5eead4" : colors[i];
      ctx.arc(cx, cy, r, rot + i * slice, rot + (i + 1) * slice);
      ctx.closePath();
      ctx.fill();
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(rot + i * slice + slice / 2);
      ctx.fillStyle = "#fff";
      ctx.font = "bold 11px Outfit";
      ctx.fillText(labels[i], r * 0.55, 4);
      ctx.restore();
    }
    ctx.fillStyle = "#0f1b2a";
    ctx.beginPath();
    ctx.arc(cx, cy, 28, 0, Math.PI * 2);
    ctx.fill();
  }

  drawWheel();
  panel.querySelector(".w-spin").addEventListener("click", async () => {
    try {
      const res = await play("nfg_wheel", "spin", { stake: Number(panel.querySelector(".a-stake").value) });
      const idx = res.segmentIndex ?? 0;
      const spins = 4 + Math.random();
      const target = spins * Math.PI * 2 + ((labels.length - idx) / labels.length) * Math.PI * 2;
      const start = angle;
      const dur = 2200;
      const t0 = performance.now();
      function frame(now) {
        const t = Math.min(1, (now - t0) / dur);
        const ease = 1 - Math.pow(1 - t, 3);
        angle = start + (target - start) * ease;
        drawWheel(angle);
        if (t < 1) requestAnimationFrame(frame);
        else {
          drawWheel(angle, idx);
          panel.querySelector(".w-out").innerHTML = resultBanner(res);
        }
      }
      requestAnimationFrame(frame);
      if (onWallet) onWallet(res.wallet || res);
    } catch (e) {
      msgEl.textContent = e.message;
    }
  });
}

export function mountTowerGame(panel, msgEl, onWallet) {
  panel.innerHTML = `
    <div class="tower-shell">
      <div class="tower-panel" id="towerRoot">
        <div class="tower-loading muted">Loading Dragon Tower…</div>
      </div>
      <div class="tower-sticky hidden" id="towerSticky">
        <button type="button" class="btn tower-flee-btn" id="towerFleeBtn">🏃 Flee / Reset run</button>
      </div>
    </div>
  `;
  const root = panel.querySelector("#towerRoot");
  const sticky = panel.querySelector("#towerSticky");
  const fleeBtn = panel.querySelector("#towerFleeBtn");
  let inRun = false;

  async function refresh(action, payload) {
    const res = await play("nfg_tower", action, payload);
    render(res);
    if (onWallet) onWallet(res.wallet || res);
    return res;
  }

  const doFlee = () => {
    refresh("flee").catch((e) => (msgEl.textContent = e.message));
  };

  fleeBtn?.addEventListener("click", doFlee);

  function render(res) {
    const t = res.tower || {};
    const hero = t.hero || {};
    const combat = t.combat;
    inRun = !!(combat || res.sessionActive || res.runActive);
    sticky?.classList.toggle("hidden", !inRun);

    if (t.needsCreation) {
      sticky?.classList.add("hidden");
      root.innerHTML = `
        <div class="vault-game-card">
          <div class="vault-game-head"><span class="vault-game-icon">🐉</span><div><h3 class="vault-game-title">Dragon Tower</h3><p class="vault-game-sub">Create your hero first</p></div></div>
          <label class="field">Hero name <input id="tName" value="Adventurer" /></label>
          <button type="button" class="btn primary block vault-cta" id="tCreate">Create hero</button>
        </div>`;
      root.querySelector("#tCreate").addEventListener("click", () =>
        refresh("customize", { heroName: root.querySelector("#tName").value, finalize: true }).catch((e) => (msgEl.textContent = e.message))
      );
      return;
    }

    const monster = combat?.monster;
    const playerHp = combat?.playerHp ?? hero.maxHp;
    const playerHpPct = Math.max(0, Math.min(100, (playerHp / (hero.maxHp || 1)) * 100));
    const monHpPct = Math.max(0, Math.min(100, ((monster?.hp || 0) / (monster?.maxHp || 1)) * 100));

    root.innerHTML = `
      <div class="tower-hero">
        <div class="tower-avatar">${hero.appearance?.heroName?.[0] || "⚔️"}</div>
        <div class="tower-hero-meta">
          <div class="tower-name">${esc(hero.appearance?.heroName || "Hero")} · Lv ${hero.level || 1}</div>
          <div class="tower-hp-bar tower-hp-bar--player"><div style="width:${playerHpPct}%"></div></div>
          <div class="muted">HP ${playerHp}/${hero.maxHp} · ATK ${hero.atk} · 🪙 ${hero.gold || 0}</div>
        </div>
      </div>
      ${
        combat
          ? `<div class="tower-combat">
          <div class="tower-monster">${monster?.emoji || "👹"} ${esc(monster?.name || "Monster")}</div>
          <div class="tower-hp-bar tower-hp-bar--monster"><div style="width:${monHpPct}%"></div></div>
          <div class="tower-floor">Floor ${combat.floor} · ${esc(combat.turn === "player" ? "Your turn" : "Monster turn")}</div>
          <div class="tower-actions">
            <button type="button" class="btn primary t-atk">⚔️ Attack</button>
            <button type="button" class="btn t-def">🛡 Defend</button>
            <button type="button" class="btn t-pot">🧪 Potion (${hero.potions || 0})</button>
            <button type="button" class="btn tower-flee-inline t-flee">🏃 Flee / Reset</button>
          </div>
          <div class="tower-log">${(combat.log || []).map((l) => `<div>${esc(l)}</div>`).join("")}</div>
        </div>`
          : `<div class="tower-idle">
          <p class="muted">Best floor reached: <strong>${hero.bestFloor || 0}</strong></p>
          <button type="button" class="btn primary block vault-cta t-enter">Enter tower</button>
        </div>`
      }
      <div class="t-out">${res.message ? resultBanner(res) : ""}</div>
    `;

    root.querySelector(".t-enter")?.addEventListener("click", () => refresh("enter").catch((e) => (msgEl.textContent = e.message)));
    root.querySelector(".t-atk")?.addEventListener("click", () => refresh("attack").catch((e) => (msgEl.textContent = e.message)));
    root.querySelector(".t-def")?.addEventListener("click", () => refresh("defend").catch((e) => (msgEl.textContent = e.message)));
    root.querySelector(".t-pot")?.addEventListener("click", () => refresh("potion").catch((e) => (msgEl.textContent = e.message)));
    root.querySelector(".t-flee")?.addEventListener("click", doFlee);
  }

  refresh("status").catch((e) => {
    msgEl.textContent = e.message;
    root.innerHTML = `<p class="muted">${esc(e.message)}</p>`;
  });
}
