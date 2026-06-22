import * as shared from "./shared.js";
import { mountCrashChart } from "./crash-chart.js";
import { loadVaultCatalog, renderVaultGrid, openVaultGame, updateVaultBalance } from "./arcade.js";

let ws = null;
let gameState = null;
let linkPollTimer = null;
let wallet = { balance: 0 };
let multHistory = [1];
let lastPhase = null;
let lastRoundShown = 0;
let crashChart = null;

const $ = (sel) => document.querySelector(sel);
const tabNav = $("#tabNav");
const walletPill = $("#walletPill");
const liveBadge = $("#liveBadge");

function setLinked(on) {
  tabNav.querySelectorAll(".tab").forEach((t) => {
    if (t.dataset.tab === "link") return;
    t.disabled = !on;
  });
  if (on) {
    walletPill.classList.remove("hidden");
    showTab("crash");
    initCrashChart();
    connectWS();
    refreshWallet();
    loadBoard();
    loadTopProfiles();
    loadChat();
    initVault();
  }
}

function initCrashChart() {
  if (crashChart) return;
  const mount = $("#crashChartMount");
  if (!mount) return;
  crashChart = mountCrashChart(mount);
}

function showTab(name) {
  document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t.dataset.tab === name));
  document.querySelectorAll(".panel").forEach((p) => p.classList.toggle("active", p.id === `panel-${name}`));
  if (name === "board") loadBoard();
  if (name === "crash") loadTopProfiles();
}

tabNav.addEventListener("click", (e) => {
  const btn = e.target.closest(".tab");
  if (!btn || btn.disabled) return;
  showTab(btn.dataset.tab);
});

$("#btnViewBoard")?.addEventListener("click", () => showTab("board"));

async function refreshWallet() {
  try {
    wallet = await shared.api("/api/mobile/me");
    walletPill.textContent = `${shared.fmt(wallet.balance)} pts`;
    $("#entriesBalance").textContent = `${shared.fmt(wallet.balance)} pts`;
    updateVaultBalance($("#vaultBalance"), wallet);
  } catch {
    walletPill.textContent = "Wallet?";
  }
}

async function startLink() {
  $("#linkStatus").textContent = "Generating code…";
  const res = await shared.api("/api/mobile/link/start", {
    method: "POST",
    body: { deviceId: shared.getDeviceId() },
    auth: false,
  });
  $("#linkCodeBox").classList.remove("hidden");
  $("#linkCommand").textContent = res.tiktokCommand || `!link ${res.code}`;
  let left = res.expiresInSeconds || 600;
  $("#linkTimer").textContent = `Expires in ${left}s`;
  clearInterval(linkPollTimer);
  linkPollTimer = setInterval(async () => {
    left -= 2;
    $("#linkTimer").textContent = left > 0 ? `Expires in ${left}s` : "Expired — tap Get link code again";
    try {
      const st = await shared.api(`/api/mobile/link/status/${res.code}`, { auth: false });
      if (st.status === "linked" && st.token) {
        clearInterval(linkPollTimer);
        shared.saveSession({ token: st.token, userId: st.userId, displayName: st.displayName || st.userId });
        $("#linkStatus").textContent = `Linked as @${st.userId}`;
        setLinked(true);
      }
    } catch {
      /* ignore poll errors */
    }
  }, 2000);
}

async function appReviewLogin() {
  const code = prompt("App Review password:");
  if (!code) return;
  const res = await shared.api("/api/mobile/auth/app-review", {
    method: "POST",
    body: { deviceId: shared.getDeviceId(), code },
    auth: false,
  });
  shared.saveSession({ token: res.token, userId: res.userId, displayName: res.displayName });
  $("#linkStatus").textContent = res.message || "Review account signed in";
  setLinked(true);
}

function connectWS() {
  if (ws) ws.close();
  ws = new WebSocket(shared.wsURL());
  ws.onopen = () => {
    liveBadge.textContent = "Online";
    liveBadge.classList.add("live");
  };
  ws.onclose = () => {
    liveBadge.textContent = "Reconnecting…";
    liveBadge.classList.remove("live");
    setTimeout(connectWS, 3000);
  };
  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.type === "state" && msg.payload) {
        gameState = msg.payload;
        renderCrash();
      }
      if (msg.type === "app_chat" && msg.payload) appendChat(msg.payload);
      if (msg.type === "app_chat_delete" && msg.payload?.messageId) {
        document.querySelector(`[data-mid="${msg.payload.messageId}"]`)?.remove();
      }
    } catch {
      /* ignore */
    }
  };
}

function phaseLabel(phase) {
  const map = { idle: "Idle", betting: "Betting", running: "Flying", ended: "Crashed" };
  return map[phase] || String(phase || "—");
}

function renderTaxPot(state) {
  const amount = Math.max(0, Math.floor(Number(state?.taxPot?.potAmount || 0)));
  const resetSec = Math.max(0, Math.floor(Number(state?.taxPot?.secondsUntilReset || 0)));
  const resetText = resetSec > 0 ? ` · reset ${fmtCountdown(resetSec)} UK` : "";
  $("#taxPotBanner").textContent = `Tax Pot: ${amount.toLocaleString()} pts${resetText}`;
}

function fmtCountdown(sec) {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return m > 0 ? `${m}m ${s}s` : `${s}s`;
}

function renderTopProfiles(rows) {
  const el = $("#topProfiles");
  const top = (rows || []).slice(0, 5);
  if (!top.length) {
    el.innerHTML = `<div class="top-profile-empty">Top players show here</div>`;
    return;
  }
  el.innerHTML = top
    .map((row, i) => {
      const bal = Number(row.balance || 0);
      const name = shared.esc(row.displayName || row.user || "?");
      const sf = row.superFan ? `<span class="sf-badge">★</span>` : "";
      return `<article class="top-card">
        <span class="top-pos">#${i + 1}</span>
        <span class="top-name">${name}${sf}</span>
        <span class="top-pts">${bal.toLocaleString()}</span>
      </article>`;
    })
    .join("");
}

async function loadTopProfiles() {
  try {
    const res = await shared.api("/api/balances?limit=5", { auth: false });
    renderTopProfiles(res.balances || []);
  } catch {
    /* ignore */
  }
}

function renderEntries(state) {
  const bets = [...(state.openBets || []), ...(state.queuedBets || [])];
  const list = $("#entriesList");
  if (!bets.length) {
    list.innerHTML = `<div class="entry-empty muted">No entries this round</div>`;
    return;
  }
  const openHtml = (state.openBets || [])
    .map(
      (b) =>
        `<div class="entry-row"><span>${shared.esc(b.displayName || b.user)}</span><span class="entry-amt">${shared.fmt(b.amount)} → ${Number(b.cashout).toFixed(2)}×</span></div>`
    )
    .join("");
  const queued = state.queuedBets || [];
  const queuedHtml = queued.length
    ? `<div class="entry-queued-label">Queued — next round</div>${queued
        .map(
          (b) =>
            `<div class="entry-row queued"><span>${shared.esc(b.displayName || b.user)}</span><span class="entry-amt">${shared.fmt(b.amount)} → ${Number(b.cashout).toFixed(2)}×</span></div>`
        )
        .join("")}`
    : "";
  list.innerHTML = openHtml + queuedHtml;
}

function showRoundPopup(result) {
  if (!result || result.roundId === lastRoundShown) return;
  lastRoundShown = result.roundId;
  const session = shared.getSession();
  const uid = session?.userId;
  const win = (result.wins || []).find((w) => w.user === uid);
  const loss = (result.losses || []).find((l) => l.user === uid);
  if (!win && !loss) return;

  const popup = $("#roundPopup");
  const title = $("#roundPopupTitle");
  const body = $("#roundPopupBody");
  const crash = Number(result.crashPoint || 0).toFixed(2);

  if (win) {
    title.textContent = "Cashed out!";
    title.className = "round-popup-title win";
    body.innerHTML = `You won <strong>${shared.fmt(win.payout || win.grossPayout || 0)} pts</strong> at ${Number(win.cashout || 0).toFixed(2)}× · Crash ${crash}×`;
  } else {
    title.textContent = "Busted";
    title.className = "round-popup-title lose";
    body.innerHTML = `Lost ${shared.fmt(loss.bet || loss.amount || 0)} pts · Crash ${crash}×`;
  }
  popup.classList.remove("hidden");
}

$("#roundPopupDismiss")?.addEventListener("click", () => $("#roundPopup").classList.add("hidden"));

function renderCrash() {
  if (!gameState) return;
  const phase = gameState.phase || "idle";
  const mult = Number(gameState.multiplier || 1);

  if (phase === "betting" || phase === "idle") multHistory = [1];
  else {
    const last = multHistory[multHistory.length - 1] ?? 1;
    if (mult >= last - 0.0001 && (multHistory.length === 0 || Math.abs(last - mult) > 0.001)) {
      multHistory.push(mult);
      if (multHistory.length > 120) multHistory.shift();
    }
  }

  $("#multDisplay").textContent = `${mult.toFixed(2)}×`;
  $("#multDisplay").classList.toggle("crashed", phase === "ended");
  $("#phaseLabel").textContent = phaseLabel(phase).toUpperCase();
  $("#crashSub").textContent =
    phase === "running"
      ? "Multiplier climbing — auto cashout when your target hits."
      : phase === "betting"
        ? "Place your bet before the round starts."
        : phase === "ended"
          ? `Crashed at ${Number(gameState.crashPoint || mult).toFixed(2)}×`
          : "Waiting for next round…";

  initCrashChart();
  crashChart?.draw(multHistory, phase, mult);
  renderTaxPot(gameState);
  renderEntries(gameState);

  if (phase === "ended" && lastPhase !== "ended" && gameState.lastResult) {
    showRoundPopup(gameState.lastResult);
    loadTopProfiles();
    refreshWallet();
  }
  lastPhase = phase;
}

async function sendChatCmd(message) {
  const session = shared.getSession();
  const res = await shared.api("/api/chat", {
    method: "POST",
    body: {
      message,
      userId: session.userId,
      user: session.userId,
      displayName: session.displayName,
      source: "mobile",
    },
  });
  if (res.parsed) {
    const msg = res.parsed.message || res.parsed.type || "OK";
    $("#crashAction").textContent = msg;
    const la = $("#lastActionMsg");
    la.textContent = msg;
    la.classList.remove("hidden");
    if (res.parsed.balance != null) refreshWallet();
  }
  return res;
}

$("#btnLinkStart").addEventListener("click", () => startLink().catch((e) => ($("#linkStatus").textContent = e.message)));
$("#btnAppReview").addEventListener("click", () => appReviewLogin().catch((e) => ($("#linkStatus").textContent = e.message)));
$("#btnPlaceBet").addEventListener("click", () => {
  const amt = $("#betAmount").value.trim();
  const co = $("#betCashout").value.trim().replace(",", ".");
  sendChatCmd(`!${amt} ${co}`).catch((e) => ($("#crashAction").textContent = e.message));
});
$("#btnBalance").addEventListener("click", () => {
  sendChatCmd("!balance").catch((e) => ($("#crashAction").textContent = e.message));
});
$("#btnAllIn")?.addEventListener("click", () => {
  sendChatCmd("!all 2").catch((e) => ($("#crashAction").textContent = e.message));
});

function appendChat(row) {
  const feed = $("#chatFeed");
  const div = document.createElement("div");
  div.className = "chat-line";
  div.dataset.mid = row.id || "";
  div.innerHTML = `<strong>${shared.esc(row.displayName || row.userId)}</strong> ${shared.esc(row.message)}`;
  feed.appendChild(div);
  feed.scrollTop = feed.scrollHeight;
}

async function loadChat() {
  try {
    const res = await shared.api("/api/mobile/chat?limit=40");
    $("#chatFeed").innerHTML = "";
    (res.messages || []).forEach(appendChat);
  } catch (e) {
    $("#chatStatus").textContent = e.message;
  }
}

$("#btnChatSend").addEventListener("click", async () => {
  const text = $("#chatInput").value.trim();
  if (!text) return;
  $("#chatInput").value = "";
  try {
    const res = await shared.api("/api/mobile/chat", { method: "POST", body: { message: text } });
    if (res.message) appendChat(res.message);
  } catch (e) {
    $("#chatStatus").textContent = e.message;
  }
});

async function loadBoard() {
  try {
    const res = await shared.api("/api/balances?limit=25", { auth: false });
    const rows = res.balances || [];
    $("#boardList").innerHTML = rows
      .map((r, i) => `<li><span class="lb-rank">${i + 1}</span> ${shared.esc(r.displayName || r.user)} <span class="lb-pts">${shared.fmt(r.balance)}</span></li>`)
      .join("");
  } catch (e) {
    $("#boardStatus").textContent = e.message;
  }
}

async function initVault() {
  try {
    const games = await loadVaultCatalog();
    renderVaultGrid($("#vaultGrid"), games, (g) => {
      openVaultGame(g, $("#vaultGame"), $("#vaultMsg"), (w) => {
        if (w.balance != null) {
          wallet.balance = w.balance;
          walletPill.textContent = `${shared.fmt(w.balance)} pts`;
          $("#entriesBalance").textContent = `${shared.fmt(w.balance)} pts`;
        }
        updateVaultBalance($("#vaultBalance"), w);
        refreshWallet();
      });
    });
    updateVaultBalance($("#vaultBalance"), wallet);
  } catch (e) {
    $("#vaultMsg").textContent = e.message;
  }
}

if (shared.isLoggedIn()) {
  $("#linkStatus").textContent = `Signed in as @${shared.getSession().userId}`;
  setLinked(true);
} else {
  showTab("link");
}

fetch("/api/mobile/status")
  .then((r) => r.json())
  .then((s) => {
    if (s.tiktokLive?.isLive) liveBadge.textContent = "TikTok LIVE";
  })
  .catch(() => {});
