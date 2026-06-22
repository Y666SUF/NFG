import { api, esc } from "./shared.js";
import { mountBlocksGame } from "./blocks-game.js";
import { mountJumpGame } from "./jump-game.js";
import {
  mountDiceGame,
  mountHiloGame,
  mountMinesGame,
  mountPlinkoGame,
  mountWheelGame,
  mountTowerGame,
} from "./arcade-games.js";

function walletFrom(res) {
  if (!res) return null;
  if (res.wallet) return res.wallet;
  if (res.balance != null) return { balance: res.balance };
  return res;
}

function mountGame(game, bodyEl, onBalanceChange) {
  bodyEl.innerHTML = `<div class="arcade-game" id="arcadeGameRoot"></div>`;
  const root = bodyEl.querySelector("#arcadeGameRoot");
  const msgEl = document.createElement("p");
  msgEl.className = "arcade-msg";
  root.appendChild(msgEl);
  const onWallet = (w) => {
    const wallet = walletFrom(w);
    if (wallet && onBalanceChange) onBalanceChange(wallet);
  };

  const id = game.id;
  if (id === "nfg_snake_jump") {
    mountJumpGame(root, onWallet);
    return;
  }
  if (id === "nfg_blocks") {
    mountBlocksGame(root, onWallet);
    return;
  }

  const panel = document.createElement("div");
  panel.className = "arcade-panel";
  root.insertBefore(panel, msgEl);

  const mounts = {
    nfg_dice: mountDiceGame,
    nfg_hilo: mountHiloGame,
    nfg_mines: mountMinesGame,
    nfg_plinko: mountPlinkoGame,
    nfg_wheel: mountWheelGame,
    nfg_tower: mountTowerGame,
  };
  const mount = mounts[id];
  if (mount) mount(panel, msgEl, onWallet);
  else panel.innerHTML = `<p class="arcade-msg">This game is not available in browser yet.</p>`;
}

export function initArcade({ onBalanceChange } = {}) {
  const hub = document.getElementById("arcadeHub");
  const overlay = document.getElementById("arcadeOverlay");
  const body = document.getElementById("arcadeBody");
  const title = document.getElementById("arcadeTitle");
  let currentGame = null;

  function closeOverlay() {
    if (overlay) overlay.hidden = true;
    document.body.classList.remove("arcade-open");
    if (body) body.innerHTML = "";
    currentGame = null;
  }

  function openGame(game) {
    if (!overlay || !body) return;
    currentGame = game;
    document.body.classList.add("arcade-open");
    overlay.hidden = false;
    if (title) title.textContent = game.title || game.id;
    mountGame(game, body, onBalanceChange);
  }

  async function loadCatalog() {
    if (!hub) return;
    try {
      const { data } = await api("/api/mobile/arcade/catalog");
      const games = (data?.games || []).filter((g) => g && g.id);
      const missions = data?.missions || [];
      let html = `<div class="arcade-grid">`;
      for (const g of games) {
        html += `<button type="button" class="arcade-tile" data-id="${esc(g.id)}">
          <span class="arcade-icon">${g.icon || "🎮"}</span>
          <span class="arcade-tile-title">${esc(g.title || g.id)}</span>
          <span class="arcade-tile-sub">${esc(g.subtitle || "")}</span>
        </button>`;
      }
      html += `</div>`;
      if (missions.length) {
        html += `<div class="list-card"><h3>Missions</h3><ul class="mission-list">`;
        for (const m of missions.slice(0, 6)) {
          html += `<li>${esc(m.title || m.id || "Mission")}</li>`;
        }
        html += `</ul></div>`;
      }
      if (data?.message) {
        html += `<p class="arcade-earn">${esc(data.message)}</p>`;
      }
      hub.innerHTML = html;
      hub.querySelectorAll(".arcade-tile").forEach((btn) => {
        btn.addEventListener("click", () => {
          const id = btn.dataset.id;
          const game = games.find((g) => g.id === id);
          if (game) openGame(game);
        });
      });
    } catch (e) {
      hub.innerHTML = `<p class="arcade-msg">${esc(e.message || "Could not load Vault.")}</p>`;
    }
  }

  document.getElementById("arcadeBack")?.addEventListener("click", closeOverlay);
  document.getElementById("arcadeRefresh")?.addEventListener("click", () => {
    if (currentGame) openGame(currentGame);
    else loadCatalog();
  });
  window.addEventListener("arcade-tab", loadCatalog);

  return { loadCatalog, openGame, closeOverlay };
}
