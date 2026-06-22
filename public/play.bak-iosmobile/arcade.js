import { api, fmt } from "./shared.js";
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

export async function loadVaultCatalog() {
  const data = await api("/api/mobile/arcade/catalog");
  return (data.games || []).filter((g) => g && g.id);
}

export function renderVaultGrid(gridEl, games, onPick) {
  gridEl.innerHTML = "";
  for (const g of games) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "vault-tile";
    btn.innerHTML = `<div class="icon">${g.icon || "🎮"}</div><div class="title">${g.title || g.id}</div><div class="sub">${g.subtitle || ""}</div>`;
    btn.addEventListener("click", () => onPick(g));
    gridEl.appendChild(btn);
  }
}

export function openVaultGame(game, mountEl, msgEl, onWallet) {
  mountEl.classList.remove("hidden");
  mountEl.innerHTML = `
    <button type="button" class="btn vault-back" id="vaultBack">← All games</button>
    <h3 class="vault-game-title">${game.title || game.id}</h3>
    <div id="vaultInner" class="vault-inner"></div>`;
  const inner = mountEl.querySelector("#vaultInner");
  mountEl.querySelector("#vaultBack").addEventListener("click", () => {
    mountEl.classList.add("hidden");
    mountEl.innerHTML = "";
  });

  const id = game.id;
  if (id === "nfg_snake_jump") {
    mountJumpGame(inner, onWallet);
    return;
  }
  if (id === "nfg_blocks") {
    mountBlocksGame(inner, onWallet);
    return;
  }

  inner.innerHTML = `<div class="arcade-panel" id="arcadePanel"></div>`;
  const panel = inner.querySelector("#arcadePanel");

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
  else panel.innerHTML = `<p class="muted">This game is not available in browser yet.</p>`;
}

export function updateVaultBalance(el, wallet) {
  if (!wallet) return;
  el.textContent = `Balance ${fmt(wallet.balance)} pts · Vault ready`;
}
