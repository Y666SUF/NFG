import {
  arcadePlay,
  fetchArcadeCatalog,
  claimArcadeMission,
  fetchArcadeLeaderboard,
  formatCard,
  fmtPts,
  esc,
  showToast,
  isLoggedIn,
} from "./shared.js";
import { mountBlocksGame } from "./blocks-game.js";
import { mountJumpGame } from "./jump-game.js";

const WHEEL_SEGMENTS = ["LOSE", "½ back", "1.5×", "2×", "3×", "JACKPOT"];
const PLINKO_RISKS = ["low", "med", "high"];

let catalog = null;
let activeMount = null;

export function initArcade({ onBalanceChange }) {
  const hub = document.getElementById("arcadeHub");
  const overlay = document.getElementById("arcadeOverlay");
  const overlayBody = document.getElementById("arcadeBody");
  const overlayTitle = document.getElementById("arcadeTitle");
  const btnBack = document.getElementById("arcadeBack");
  const btnRefresh = document.getElementById("arcadeRefresh");

  if (!hub || !overlay) return { loadCatalog: () => {} };

  btnBack?.addEventListener("click", closeGame);
  btnRefresh?.addEventListener("click", () => loadCatalog(hub));

  window.addEventListener("arcade-tab", () => {
    if (isLoggedIn()) loadCatalog(hub);
  });

  async function loadCatalog(target) {
    if (!isLoggedIn()) {
      target.innerHTML = '<p class="fine">Link TikTok to play Vault Arcade.</p>';
      return;
    }
    try {
      catalog = await fetchArcadeCatalog();
      renderHub(target);
    } catch (e) {
      target.innerHTML = `<p class="err">${esc(e.message)}</p>`;
    }
  }

  function renderHub(target) {
    const games = catalog?.games || [];
    const missions = catalog?.missions || [];
    const earn = catalog?.earnLeft != null ? `${catalog.earnLeft.toLocaleString()} pts left today` : "";
    target.innerHTML = `
      <div class="arcade-earn">${esc(earn)} · Balance ${fmtPts(catalog?.balance)}</div>
      <div class="arcade-grid" id="arcadeGrid"></div>
      <div id="arcadeMissions"></div>
      <div id="arcadeLb"></div>
    `;
    const grid = target.querySelector("#arcadeGrid");
    games.forEach((g) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "arcade-tile";
      btn.innerHTML = `<span class="arcade-icon">${esc(g.icon || "🎮")}</span>
        <span class="arcade-tile-title">${esc(g.title || g.id)}</span>
        <span class="arcade-tile-sub">${esc(g.subtitle || "")}</span>`;
      btn.addEventListener("click", () => openGame(g));
      grid.appendChild(btn);
    });
    const mEl = target.querySelector("#arcadeMissions");
    if (missions.length) {
      mEl.innerHTML = `<h3>Missions</h3><ul class="mission-list"></ul>`;
      const ul = mEl.querySelector("ul");
      missions.forEach((m) => {
        const li = document.createElement("li");
        const done = m.done && !m.claimed;
        li.innerHTML = `${esc(m.title)} — ${m.progress || 0}/${m.goal}
          ${done ? `<button type="button" class="btn ghost sm" data-mid="${esc(m.id)}">Claim ${m.reward || 0}</button>` : m.claimed ? " ✓" : ""}`;
        if (done) {
          li.querySelector("button").addEventListener("click", async () => {
            try {
              catalog = await claimArcadeMission(m.id);
              onBalanceChange?.();
              renderHub(target);
              showToast("Mission claimed!");
            } catch (e) {
              showToast(e.message);
            }
          });
        }
        ul.appendChild(li);
      });
    }
    loadLeaderboards(target.querySelector("#arcadeLb"));
  }

  async function loadLeaderboards(el) {
    if (!el) return;
    const blocks = await fetchArcadeLeaderboard("nfg_blocks");
    const jump = await fetchArcadeLeaderboard("nfg_snake_jump");
    let html = "";
    if (blocks?.top?.length) {
      html += `<h3>NFG Blocks top</h3><ul class="board-list">${blocks.top
        .slice(0, 5)
        .map((r, i) => `<li>${i + 1}. ${esc(r.displayName || r.userId)} — Lv ${r.points}</li>`)
        .join("")}</ul>`;
    }
    if (jump?.top?.length) {
      html += `<h3>NFG Jump top</h3><ul class="board-list">${jump.top
        .slice(0, 5)
        .map((r, i) => `<li>${i + 1}. ${esc(r.displayName || r.userId)} — ${r.points}m</li>`)
        .join("")}</ul>`;
    }
    el.innerHTML = html;
  }

  async function openGame(game) {
    if (!isLoggedIn()) {
      showToast("Link TikTok first.");
      return;
    }
    overlay.hidden = false;
    overlayTitle.textContent = game.title || game.id;
    overlayBody.innerHTML = "";
    document.body.classList.add("arcade-open");
    if (activeMount) {
      activeMount.destroy();
      activeMount = null;
    }
    try {
      activeMount = await mountGame(game, overlayBody, onBalanceChange);
    } catch (e) {
      overlayBody.innerHTML = `<p class="err">${esc(e.message)}</p>`;
    }
  }

  function closeGame() {
    overlay.hidden = true;
    document.body.classList.remove("arcade-open");
    if (activeMount) {
      activeMount.destroy();
      activeMount = null;
    }
    if (catalog) loadCatalog(hub);
  }

  return { loadCatalog: () => loadCatalog(hub), closeGame };
}

async function mountGame(game, container, onBalanceChange) {
  const id = game.id;
  const status = await arcadePlay(id, "status", {});
  const ctx = {
    gameId: id,
    status,
    stake: status.suggestedStake || 1000,
    onBalanceChange,
    container,
  };
  switch (id) {
    case "nfg_dice":
      return mountDice(ctx);
    case "nfg_hilo":
      return mountHiLo(ctx);
    case "nfg_mines":
      return mountMines(ctx);
    case "nfg_plinko":
      return mountPlinko(ctx);
    case "nfg_wheel":
      return mountWheel(ctx);
    case "nfg_tower":
      return mountTower(ctx);
    case "nfg_blocks":
      return mountBlocks(ctx);
    case "nfg_snake_jump":
      return mountJump(ctx);
    default:
      throw new Error("Unknown game: " + id);
  }
}

function stakeInput(ctx, extra = "") {
  return `
    <label class="arcade-field">Points <input type="number" id="arcadeStake" min="${ctx.status.stakeMin || 100}" max="${ctx.status.stakeMax || 99999999}" value="${ctx.stake}" /></label>
    ${ctx.status.cooldownSecondsLeft > 0 ? `<p class="fine">Cooldown ${ctx.status.cooldownSecondsLeft}s</p>` : ""}
    ${extra}
    <p class="arcade-msg" id="arcadeMsg"></p>
  `;
}

function shell(title, inner) {
  const wrap = document.createElement("div");
  wrap.className = "arcade-game";
  wrap.innerHTML = inner;
  return wrap;
}

function msgEl(root) {
  return root.querySelector("#arcadeMsg");
}

async function play(ctx, action, payload = {}) {
  const res = await arcadePlay(ctx.gameId, action, payload);
  ctx.status = { ...ctx.status, ...res };
  if (res.balance != null) ctx.onBalanceChange?.();
  return res;
}

function mountDice(ctx) {
  const root = shell("dice", `
    ${stakeInput(ctx, `
      <label>Line <input type="range" id="diceTarget" min="2" max="98" value="50" /></label>
      <span id="diceTargetVal">50.00</span>
      <div class="btn-row">
        <button type="button" class="btn primary" data-mode="under">Roll Under</button>
        <button type="button" class="btn ghost" data-mode="over">Roll Over</button>
      </div>
    `)}
    <p class="arcade-result" id="diceResult"></p>
  `);
  ctx.container.appendChild(root);
  const target = root.querySelector("#diceTarget");
  const targetVal = root.querySelector("#diceTargetVal");
  target.addEventListener("input", () => {
    targetVal.textContent = Number(target.value).toFixed(2);
  });
  root.querySelectorAll("[data-mode]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      try {
        const stake = Number(root.querySelector("#arcadeStake").value);
        const res = await play(ctx, "play", {
          stake,
          mode: btn.dataset.mode,
          target: Number(target.value),
        });
        msgEl(root).textContent = res.message || "";
        root.querySelector("#diceResult").textContent = res.won
          ? `Rolled ${res.roll?.toFixed?.(2) ?? res.roll} — WIN +${res.gained || res.payout || 0}`
          : `Rolled ${res.roll?.toFixed?.(2) ?? res.roll} — lose`;
      } catch (e) {
        msgEl(root).textContent = e.message;
      }
    });
  });
  return { destroy: () => root.remove() };
}

function mountHiLo(ctx) {
  const root = shell("hilo", `
    ${stakeInput(ctx)}
    <div class="hilo-card" id="hiloCard">—</div>
    <p id="hiloMult">×1.00 · streak 0</p>
    <div class="btn-row" id="hiloStartRow">
      <button type="button" class="btn primary" id="hiloStart">Start round</button>
    </div>
    <div class="btn-row" id="hiloPlayRow" hidden>
      <button type="button" class="btn primary" data-dir="hi">Higher</button>
      <button type="button" class="btn ghost" data-dir="lo">Lower</button>
      <button type="button" class="btn ghost" id="hiloCash">Collect</button>
    </div>
    <p class="arcade-msg" id="arcadeMsg"></p>
  `);
  ctx.container.appendChild(root);
  const card = root.querySelector("#hiloCard");
  const mult = root.querySelector("#hiloMult");
  const startRow = root.querySelector("#hiloStartRow");
  const playRow = root.querySelector("#hiloPlayRow");

  function uiFrom(res) {
    if (res.sessionActive) {
      startRow.hidden = true;
      playRow.hidden = false;
      card.textContent = formatCard(res.cardRank, res.cardSuit);
      mult.textContent = `×${Number(res.multiplier || 1).toFixed(2)} · streak ${res.streak || 0}`;
    } else {
      startRow.hidden = false;
      playRow.hidden = true;
      if (res.cardRank) card.textContent = formatCard(res.cardRank, res.cardSuit);
    }
    msgEl(root).textContent = res.message || "";
  }
  uiFrom(ctx.status);

  root.querySelector("#hiloStart").addEventListener("click", async () => {
    try {
      const res = await play(ctx, "start", { stake: Number(root.querySelector("#arcadeStake").value) });
      uiFrom(res);
    } catch (e) {
      msgEl(root).textContent = e.message;
    }
  });
  root.querySelectorAll("[data-dir]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      try {
        const res = await play(ctx, "guess", { direction: btn.dataset.dir });
        uiFrom(res);
        if (res.bust) showToast("Wrong — round over");
      } catch (e) {
        msgEl(root).textContent = e.message;
      }
    });
  });
  root.querySelector("#hiloCash").addEventListener("click", async () => {
    try {
      const res = await play(ctx, "cashout");
      uiFrom(res);
    } catch (e) {
      msgEl(root).textContent = e.message;
    }
  });
  return { destroy: () => root.remove() };
}

function mountMines(ctx) {
  const root = shell("mines", `
    ${stakeInput(ctx, `<label>Mines <select id="minesCount"><option value="3">3</option><option value="5">5</option><option value="8">8</option></select></label>`)}
    <div class="mines-grid" id="minesGrid"></div>
    <div class="btn-row">
      <button type="button" class="btn primary" id="minesStart">Start</button>
      <button type="button" class="btn ghost" id="minesCash" hidden>Collect</button>
    </div>
    <p class="arcade-msg" id="arcadeMsg"></p>
  `);
  ctx.container.appendChild(root);
  const grid = root.querySelector("#minesGrid");
  const cashBtn = root.querySelector("#minesCash");

  function renderGrid(res) {
    grid.innerHTML = "";
    const revealed = new Set(res.revealed || []);
    const mines = new Set(res.minePositions || []);
    const active = res.sessionActive;
    for (let i = 0; i < 25; i += 1) {
      const cell = document.createElement("button");
      cell.type = "button";
      cell.className = "mines-cell";
      if (revealed.has(i)) {
        cell.classList.add("gem");
        cell.textContent = "💎";
      } else if (!active && mines.has(i)) {
        cell.classList.add("mine");
        cell.textContent = "💣";
      } else {
        cell.textContent = active ? "" : "";
        cell.addEventListener("click", async () => {
          if (!active) return;
          try {
            const r = await play(ctx, "reveal", { index: i });
            renderGrid(r);
            msgEl(root).textContent = r.message || "";
            if (r.bust) showToast("Mine hit!");
          } catch (e) {
            msgEl(root).textContent = e.message;
          }
        });
      }
      grid.appendChild(cell);
    }
    cashBtn.hidden = !active;
    if (res.multiplier) msgEl(root).textContent = `×${res.multiplier} — ${res.message || ""}`;
  }
  renderGrid(ctx.status);

  root.querySelector("#minesStart").addEventListener("click", async () => {
    try {
      const res = await play(ctx, "start", {
        stake: Number(root.querySelector("#arcadeStake").value),
        mines: Number(root.querySelector("#minesCount").value),
      });
      renderGrid(res);
    } catch (e) {
      msgEl(root).textContent = e.message;
    }
  });
  cashBtn.addEventListener("click", async () => {
    try {
      const res = await play(ctx, "cashout");
      renderGrid(res);
      showToast(res.message || "Collected");
    } catch (e) {
      msgEl(root).textContent = e.message;
    }
  });
  return { destroy: () => root.remove() };
}

function mountPlinko(ctx) {
  const root = shell("plinko", `
    ${stakeInput(ctx)}
    <div class="btn-row">
      ${PLINKO_RISKS.map((r) => `<button type="button" class="btn ghost" data-risk="${r}">${r.toUpperCase()}</button>`).join("")}
    </div>
    <p class="arcade-result" id="plinkoResult"></p>
    <p class="arcade-msg" id="arcadeMsg"></p>
  `);
  ctx.container.appendChild(root);
  root.querySelectorAll("[data-risk]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      try {
        const res = await play(ctx, "play", {
          stake: Number(root.querySelector("#arcadeStake").value),
          risk: btn.dataset.risk,
        });
        root.querySelector("#plinkoResult").textContent = `Bucket ${res.segmentIndex} · ×${res.multiplier} → ${fmtPts(res.gained || res.payout || 0)}`;
        msgEl(root).textContent = res.message || "";
      } catch (e) {
        msgEl(root).textContent = e.message;
      }
    });
  });
  return { destroy: () => root.remove() };
}

function mountWheel(ctx) {
  const root = shell("wheel", `
    ${stakeInput(ctx)}
    <div class="wheel-display" id="wheelDisplay">🎡</div>
    <button type="button" class="btn primary" id="wheelSpin">Spin</button>
    <p class="arcade-result" id="wheelResult"></p>
    <p class="arcade-msg" id="arcadeMsg"></p>
  `);
  ctx.container.appendChild(root);
  root.querySelector("#wheelSpin").addEventListener("click", async () => {
    try {
      const res = await play(ctx, "spin", { stake: Number(root.querySelector("#arcadeStake").value) });
      const label = res.segmentLabel || WHEEL_SEGMENTS[res.segmentIndex] || "?";
      root.querySelector("#wheelDisplay").textContent = label;
      root.querySelector("#wheelResult").textContent = res.message || `${label} · ×${res.multiplier}`;
      msgEl(root).textContent = res.won ? "Win!" : "";
    } catch (e) {
      msgEl(root).textContent = e.message;
    }
  });
  return { destroy: () => root.remove() };
}

function mountTower(ctx) {
  const root = document.createElement("div");
  root.className = "arcade-game tower-game";
  ctx.container.appendChild(root);

  async function refresh(action, payload = {}) {
    const res = action ? await play(ctx, action, payload) : ctx.status;
    render(res);
    return res;
  }

  function render(res) {
    const t = res.tower || {};
    const hero = t.hero || {};
    const combat = t.combat;
    const needsCreation = t.needsCreation;
    root.innerHTML = `
      <div class="tower-hero">
        <strong>${esc(hero.appearance?.heroName || "Hero")}</strong> Lv ${hero.level || 1}
        · ${hero.gold || 0} gold · ${hero.potions || 0} potions
        · HP ${combat?.playerHp ?? hero.maxHp}/${hero.maxHp}
      </div>
      ${needsCreation ? `
        <p>Create your hero:</p>
        <input id="towerName" placeholder="Hero name" maxlength="16" value="${esc(hero.appearance?.heroName || "")}" />
        <select id="towerBody"><option value="male">Male</option><option value="female">Female</option></select>
        <button type="button" class="btn primary" id="towerCreate">Create hero</button>
      ` : combat ? `
        <div class="tower-combat">
          <p>Floor ${combat.floor} — ${combat.monster?.emoji || ""} ${esc(combat.monster?.name || "Monster")}</p>
          <p>Monster HP ${combat.monster?.hp}/${combat.monster?.maxHp}</p>
          <div class="btn-row">
            <button type="button" class="btn primary" id="towerAtk">Attack</button>
            <button type="button" class="btn ghost" id="towerDef">Defend</button>
            <button type="button" class="btn ghost" id="towerPot">Potion</button>
            <button type="button" class="btn ghost" id="towerFlee">Flee</button>
          </div>
        </div>
      ` : `
        <div class="btn-row">
          <button type="button" class="btn primary" id="towerEnter">Enter tower</button>
        </div>
        <div class="tower-shop" id="towerShop"></div>
      `}
      <pre class="tower-log">${(combat?.log || []).map(esc).join("\n")}</pre>
      <p class="arcade-msg" id="arcadeMsg">${esc(res.message || "")}</p>
    `;

    const act = async (action, payload = {}) => {
      try {
        await refresh(action, payload);
      } catch (e) {
        const m = root.querySelector("#arcadeMsg");
        if (m) m.textContent = e.message;
      }
    };

    if (needsCreation) {
      root.querySelector("#towerCreate").addEventListener("click", () =>
        act("customize", {
          heroName: root.querySelector("#towerName").value,
          bodyStyle: root.querySelector("#towerBody").value,
          finalize: true,
        })
      );
    } else if (combat) {
      root.querySelector("#towerAtk")?.addEventListener("click", () => act("attack"));
      root.querySelector("#towerDef")?.addEventListener("click", () => act("defend"));
      root.querySelector("#towerPot")?.addEventListener("click", () => act("potion"));
      root.querySelector("#towerFlee")?.addEventListener("click", () => act("flee"));
    } else {
      root.querySelector("#towerEnter")?.addEventListener("click", () => act("enter"));
      const shop = (t.shop?.gear || []).filter((item) => item.unlocked !== false);
      const owned = new Set(hero.ownedGear || []);
      const shopEl = root.querySelector("#towerShop");
      if (shopEl && shop.length) {
        shopEl.innerHTML = "<h4>Shop</h4>";
        shop
          .filter((item) => !owned.has(item.id))
          .slice(0, 10)
          .forEach((item) => {
            const b = document.createElement("button");
            b.type = "button";
            b.className = "btn ghost sm";
            b.textContent = `${item.name} (${item.cost}g)`;
            b.addEventListener("click", () => act("buy", { itemId: item.id }));
            shopEl.appendChild(b);
          });
      }
    }
  }

  render(ctx.status);
  return { destroy: () => root.remove() };
}

function mountBlocks(ctx) {
  const host = document.createElement("div");
  ctx.container.appendChild(host);
  mountBlocksGame(host, (w) => {
    if (w?.balance != null) ctx.onBalanceChange?.();
  });
  return { destroy: () => host.remove() };
}

function mountJump(ctx) {
  const host = document.createElement("div");
  ctx.container.appendChild(host);
  mountJumpGame(host, (w) => {
    if (w?.balance != null) ctx.onBalanceChange?.();
  });
  return { destroy: () => host.remove() };
}
