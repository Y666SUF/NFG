import {
  getSession,
  saveSession,
  clearSession,
  isLoggedIn,
  setUnauthorizedHandler,
  api,
  fmtMult,
  fmtPts,
  esc,
  parseBetAmount,
  showToast,
} from "./shared.js";
import { initArcade } from "./arcade.js";
import { CrashChartRenderer } from "./crash-chart.js";

const $ = (id) => document.getElementById(id);

const els = {
  topbar: $("topbar"),
  userPill: $("userPill"),
  balancePill: $("balancePill"),
  livePill: $("livePill"),
  btnLogout: $("btnLogout"),
  linkPanel: $("linkPanel"),
  btnLinkStart: $("btnLinkStart"),
  linkStatus: $("linkStatus"),
  linkCode: $("linkCode"),
  linkWait: $("linkWait"),
  btnLinkCancel: $("btnLinkCancel"),
  linkError: $("linkError"),
  main: $("main"),
  tabbar: $("tabbar"),
  screenPlay: $("screenPlay"),
  roundEta: $("roundEta"),
  chartWrap: $("chartWrap"),
  crashCanvas: $("crashCanvas"),
  chartEntries: $("chartEntries"),
  chartStatus: $("chartStatus"),
  chartMult: $("chartMult"),
  chartMultEyebrow: $("chartMultEyebrow"),
  multDisplay: $("multDisplay"),
  taxPotBanner: $("taxPotBanner"),
  taxPotAmt: $("taxPotAmt"),
  recentCrashes: $("recentCrashes"),
  subline: $("subline"),
  betForm: $("betForm"),
  betAmount: $("betAmount"),
  betCashout: $("betCashout"),
  betDockBalance: $("betDockBalance"),
  btnBetAll: $("btnBetAll"),
  btnBalanceShoutDock: $("btnBalanceShoutDock"),
  actionMsg: $("actionMsg"),
  walletBalance: $("walletBalance"),
  walletSub: $("walletSub"),
  btnRefreshWallet: $("btnRefreshWallet"),
  btnBalanceShout: $("btnBalanceShout"),
  inventoryCard: $("inventoryCard"),
  inventoryList: $("inventoryList"),
  chatFeed: $("chatFeed"),
  chatForm: $("chatForm"),
  chatInput: $("chatInput"),
  boardList: $("boardList"),
};

let crashChart = null;
if (els.crashCanvas && els.chartWrap) {
  crashChart = new CrashChartRenderer(els.crashCanvas, els.chartWrap);
}

const mobileShellMq = window.matchMedia("(max-width: 520px), (hover: none) and (pointer: coarse) and (max-width: 820px)");
const phoneMq = window.matchMedia("(max-width: 520px)");
let activeTab = "play";

function setBodyPhase(phase) {
  document.body.classList.remove("phase-idle", "phase-betting", "phase-running", "phase-ended");
  document.body.classList.add(`phase-${phase || "idle"}`);
}

function measureChrome() {
  if (els.tabbar && !els.tabbar.hidden) {
    document.documentElement.style.setProperty("--tabbar-h", `${els.tabbar.offsetHeight}px`);
  }
  if (crashChart) crashChart.resize();
}

function updateMobileShell() {
  const loggedIn = !els.main.hidden;
  const useShell = loggedIn && mobileShellMq.matches;
  document.body.classList.toggle("play-shell", useShell);
  document.body.classList.toggle("tab-play", activeTab === "play");
  measureChrome();
}

function setupKeyboardLift() {
  const vv = window.visualViewport;
  if (!vv) return;
  const onViewport = () => {
    const gap = Math.max(0, window.innerHeight - vv.height - vv.offsetTop);
    const open = gap > 80;
    document.documentElement.style.setProperty("--keyboard-lift", open ? `${gap}px` : "0px");
    if (crashChart) crashChart.resize();
  };
  vv.addEventListener("resize", onViewport);
  vv.addEventListener("scroll", onViewport);
}

function setupPortraitLock() {
  const lock = $("portraitLock");
  const sync = () => {
    if (!lock) return;
    const landscape = window.matchMedia("(orientation: landscape)").matches;
    const show = phoneMq.matches && landscape && window.innerHeight <= 520;
    lock.hidden = !show;
    document.body.classList.toggle("portrait-blocked", show);
  };
  window.addEventListener("resize", sync);
  window.addEventListener("orientationchange", sync);
  phoneMq.addEventListener("change", sync);
  sync();
}

function setupDismissKeyboard() {
  const scene = document.getElementById("playScene");
  if (!scene) return;
  scene.addEventListener("click", (e) => {
    if (e.target.closest("input, button, textarea, select, a, label")) return;
    const active = document.activeElement;
    if (active && (active.tagName === "INPUT" || active.tagName === "TEXTAREA")) active.blur();
  });
}

mobileShellMq.addEventListener("change", updateMobileShell);
window.addEventListener("resize", measureChrome);
setupKeyboardLift();
setupPortraitLock();
setupDismissKeyboard();

let ws = null;
let state = null;
let historyMult = [1];
let lastRoundId = 0;
let prevPhase = null;
let lastActionForChart = "";
let linkPollTimer = null;
let linkCode = "";
let presenceTimer = null;
let chatPollTimer = null;

const arcade = initArcade({ onBalanceChange: refreshWallet });

setUnauthorizedHandler(showLoggedOut);

function setActionMsg(msg, isErr) {
  if (!msg) {
    els.actionMsg.hidden = true;
    lastActionForChart = "";
  } else {
    els.actionMsg.hidden = false;
    els.actionMsg.textContent = msg;
    els.actionMsg.classList.toggle("err", !!isErr);
    if (!isErr) lastActionForChart = msg;
  }
  if (state) renderChartEntries(state.openBets, state.queuedBets);
}

function renderTaxPot(s) {
  const amt = s?.taxPot?.amount;
  if (amt == null || Number(amt) <= 0) {
    els.taxPotBanner.hidden = true;
    return;
  }
  els.taxPotBanner.hidden = false;
  els.taxPotAmt.textContent = `${Math.floor(Number(amt)).toLocaleString()} pts`;
}

function renderRecentCrashes(s) {
  const rows = s?.recentCrashes || [];
  if (!rows.length) {
    els.recentCrashes.hidden = true;
    return;
  }
  els.recentCrashes.hidden = false;
  els.recentCrashes.innerHTML = rows
    .slice(0, 5)
    .map((m, i) => {
      const hot = Number(m) >= 2;
      return `<span class="crash-chip${hot ? " hot" : ""}">${fmtMult(m)}</span>`;
    })
    .join("");
}

function renderChartEntries(open, queued) {
  if (!els.chartEntries) return;
  const o = open || [];
  const q = queued || [];
  const total = o.length + q.length;
  let html = `<div class="chart-entries-head">👥 IN ROUND <strong>${total}</strong></div>`;
  if (!total) {
    html += `<div class="chart-entry-row">No players yet</div>`;
  } else {
    for (const b of o.slice(0, 4)) {
      html += `<div class="chart-entry-row">${esc(b.displayName || b.user || "?")} · ${b.amount} @ ${Number(b.cashout).toFixed(2)}×</div>`;
    }
    if (q.length) {
      html += `<div class="chart-entries-head" style="margin-top:4px">NEXT ROUND</div>`;
      for (const b of q.slice(0, 3)) {
        html += `<div class="chart-entry-row queued">${esc(b.displayName || b.user || "?")} · ${b.amount} @ ${Number(b.cashout).toFixed(2)}×</div>`;
      }
    }
  }
  if (lastActionForChart) {
    html += `<div class="chart-entries-msg">${esc(lastActionForChart)}</div>`;
  }
  els.chartEntries.innerHTML = html;
}

function updateChartChrome(s) {
  const phase = s.phase || "idle";
  const crashed = phase === "ended";
  const showMult = phase === "running" || phase === "ended";

  if (els.chartMult) {
    els.chartMult.hidden = !showMult;
    els.chartMult.classList.toggle("crashed", crashed);
  }
  if (els.chartMultEyebrow) els.chartMultEyebrow.hidden = !crashed;

  const multVal = crashed ? (s.crashPoint ?? s.multiplier) : s.multiplier;
  if (els.multDisplay) els.multDisplay.textContent = fmtMult(multVal);

  if (els.chartStatus) {
    if (phase === "betting" || phase === "idle") {
      els.chartStatus.hidden = false;
      const sec =
        phase === "betting" && s.bettingEndsAt
          ? Math.max(0, Math.ceil((s.bettingEndsAt - Date.now()) / 1000))
          : null;
      els.chartStatus.innerHTML =
        phase === "betting"
          ? `<div>Waiting for round…</div><div class="eyebrow">ENTRY WINDOW</div>${sec != null ? `<div class="countdown">${sec}s</div>` : ""}`
          : `<div>Standing by</div>`;
    } else {
      els.chartStatus.hidden = true;
    }
  }
}

function applyState(s) {
  if (!s) return;
  if (s.roundId !== lastRoundId) {
    lastRoundId = s.roundId;
    historyMult = [1];
  }
  const phaseBecameEnded = prevPhase !== "ended" && s.phase === "ended";
  prevPhase = s.phase;
  state = s;
  const phase = s.phase || "idle";
  setBodyPhase(phase);
  if (els.screenPlay) {
    els.screenPlay.classList.remove("phase-idle", "phase-betting", "phase-running", "phase-ended");
    els.screenPlay.classList.add(`phase-${phase}`);
  }
  if (phaseBecameEnded && els.chartWrap) {
    els.chartWrap.classList.add("flash-crash");
    setTimeout(() => els.chartWrap.classList.remove("flash-crash"), 700);
  }
  if (s.spinPauseEndsAt && s.phase === "ended") {
    const sec = Math.max(0, Math.ceil((s.spinPauseEndsAt - Date.now()) / 1000));
    els.roundEta.hidden = false;
    els.roundEta.textContent = `Spin ${sec}s`;
  } else if (s.nextRoundStartsAt && (s.phase === "idle" || s.phase === "ended")) {
    const sec = Math.max(0, Math.ceil((s.nextRoundStartsAt - Date.now()) / 1000));
    els.roundEta.hidden = false;
    els.roundEta.textContent = `Next ~${sec}s`;
  } else {
    els.roundEta.hidden = true;
  }
  if (s.phase === "betting") {
    const sec = Math.max(0, Math.ceil((s.bettingEndsAt - Date.now()) / 1000));
    els.subline.textContent = `Entry window ${sec}s — join the round below`;
    if (!historyMult.length || historyMult[historyMult.length - 1] !== 1) historyMult = [1];
  } else if (s.phase === "running") {
    els.subline.textContent = "Multiplier climbing — score when your target is reached.";
    const m = s.multiplier;
    if (!historyMult.length || Math.abs(historyMult[historyMult.length - 1] - m) > 0.001) {
      historyMult.push(m);
      if (historyMult.length > 200) historyMult.shift();
    }
  } else if (s.phase === "ended") {
    els.subline.textContent = "Round finished — next round starts automatically.";
    const endM = s.crashPoint != null ? s.crashPoint : s.multiplier;
    const last = historyMult[historyMult.length - 1];
    if (last == null || Math.abs(last - endM) > 0.02) {
      historyMult.push(endM);
      if (historyMult.length > 200) historyMult.shift();
    }
  } else {
    els.subline.textContent = s.nextRoundStartsAt ? "Waiting for next round…" : "Stand by for the next round.";
  }
  if (crashChart) {
    crashChart.update({ ...s, history: historyMult });
  }
  updateChartChrome(s);
  renderChartEntries(s.openBets, s.queuedBets);
  renderTaxPot(s);
  renderRecentCrashes(s);
}

function connectWs() {
  if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) return;
  const proto = location.protocol === "https:" ? "wss" : "ws";
  ws = new WebSocket(`${proto}://${location.host}`);
  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.type === "state") applyState(msg.payload);
      else if (msg.type === "balance_toast" && isLoggedIn()) {
        const p = msg.payload || {};
        const session = getSession();
        if (String(p.user || "").toLowerCase() === session.userId.toLowerCase()) {
          showToast(p.text || "Balance updated");
          refreshWallet();
        }
      } else if (msg.type === "app_chat") appendChatLine(msg.payload);
    } catch {
      /* ignore */
    }
  };
  ws.onclose = () => setTimeout(connectWs, 2000);
  ws.onopen = () => {
    ws.send(JSON.stringify({ type: "ping" }));
    fetchState();
  };
}

async function fetchState() {
  try {
    const { data } = await api("/api/state");
    applyState(data);
  } catch {
    els.subline.textContent = "Could not load game state.";
  }
}

async function refreshLiveStatus() {
  try {
    const { data } = await api("/api/mobile/status");
    const tt = data && data.tiktokLive;
    const live = !!(tt && (tt.isLive === true || tt.state === "live"));
    els.livePill.textContent = live ? "LIVE" : "Offline";
    els.livePill.classList.toggle("live", !!live);
    els.livePill.classList.toggle("off", !live);
  } catch {
    els.livePill.textContent = "—";
  }
}

async function refreshWallet() {
  if (!isLoggedIn()) return;
  try {
    const { ok, data } = await api("/api/mobile/me");
    if (!ok) return;
    const bal = data.balance ?? data.points ?? 0;
    els.balancePill.textContent = fmtPts(bal);
    els.walletBalance.textContent = fmtPts(bal);
    if (els.betDockBalance) {
      els.betDockBalance.textContent = isLoggedIn() ? fmtPts(bal) : "Link TikTok to play";
    }
    const parts = [];
    if (data.displayName) {
      saveSession({ displayName: data.displayName });
      els.userPill.textContent = data.displayName;
    }
    if (data.shieldActive) parts.push("Shield active");
    if (data.jetLockActive) parts.push("Jet lock");
    els.walletSub.textContent = parts.length ? parts.join(" · ") : "Shared wallet with TikTok LIVE";
    const inv = data.inventory || data.powerupInventory || {};
    const keys = Object.keys(inv).filter((k) => Number(inv[k]) > 0);
    if (keys.length) {
      els.inventoryCard.hidden = false;
      els.inventoryList.innerHTML = keys.map((k) => `<li>${esc(k)}: ${esc(inv[k])}</li>`).join("");
    } else {
      els.inventoryCard.hidden = true;
    }
  } catch {
    /* ignore */
  }
}

async function sendCommand(message) {
  if (!isLoggedIn()) {
    setActionMsg("Link your TikTok on LIVE first.", true);
    return;
  }
  const session = getSession();
  try {
    const { data } = await api("/api/chat", {
      method: "POST",
      body: {
        message,
        userId: session.userId,
        user: session.userId,
        displayName: session.displayName || session.userId,
        source: "mobile",
      },
    });
    handleChatResult(data);
    await refreshWallet();
  } catch (e) {
    setActionMsg(e.message || "Could not send command.", true);
  }
}

function handleChatResult(data) {
  const parsed = data && data.parsed;
  if (!parsed) {
    if (data && data.ignored) setActionMsg("Command not recognized.", true);
    return;
  }
  if (parsed.type === "bet") {
    setActionMsg(
      parsed.ok ? `Joined: ${parsed.amount} pts · target ${parsed.cashout}×` : betError(parsed.reason),
      !parsed.ok
    );
  } else if (parsed.type === "balance_shout") {
    if (parsed.ok && parsed.balance != null) setActionMsg(`Balance: ${fmtPts(parsed.balance)}`);
    else setActionMsg(parsed.cooldown ? `Balance cooldown — ${parsed.secondsLeft || "?"}s` : "Balance on cooldown.", true);
  } else if (parsed.ok === false && parsed.reason) {
    setActionMsg(String(parsed.reason).replace(/_/g, " "), true);
  } else {
    setActionMsg("OK");
  }
}

function betError(reason) {
  const map = {
    insufficient: "Not enough points.",
    not_betting: "Queued for next round.",
    bad_cashout: "Target must be 1.05–500×.",
    bad_amount: "Invalid point amount.",
    already_bet: "You already joined this round.",
  };
  return map[reason] || reason || "Could not join round.";
}

async function placeBet(amountText, cashout) {
  const trimmed = String(amountText || "").trim();
  if (!trimmed || Number(cashout) < 1.05) {
    setActionMsg("Enter points and target ≥ 1.05×.", true);
    return;
  }
  if (!parseBetAmount(trimmed) && trimmed.toLowerCase() !== "all") {
    setActionMsg("Invalid amount (e.g. 100, 30k, 3m).", true);
    return;
  }
  await sendCommand(`!${trimmed} ${cashout}`);
}

async function loadBoard() {
  try {
    const { data } = await api("/api/balances?limit=all");
    const rows = (data && data.balances) || [];
    els.boardList.innerHTML = "";
    if (!rows.length) {
      els.boardList.innerHTML = '<li style="opacity:0.6">No players yet</li>';
      return;
    }
    rows.slice(0, 100).forEach((row, i) => {
      const li = document.createElement("li");
      li.textContent = `${i + 1}. ${row.displayName || row.user} — ${fmtPts(row.balance ?? row.points)}`;
      els.boardList.appendChild(li);
    });
  } catch {
    els.boardList.innerHTML = '<li style="opacity:0.6">Could not load leaderboard</li>';
  }
}

function appendChatLine(msg) {
  const text = msg && (msg.message || msg.text);
  if (!text) return;
  const div = document.createElement("div");
  div.className = "chat-line";
  div.innerHTML = `<span class="who">${esc(msg.displayName || msg.user || msg.userId || "?")}</span>${esc(text)}`;
  els.chatFeed.appendChild(div);
  els.chatFeed.scrollTop = els.chatFeed.scrollHeight;
}

async function loadChat() {
  if (!isLoggedIn()) return;
  try {
    const { data } = await api("/api/mobile/chat?limit=50");
    els.chatFeed.innerHTML = "";
    (data?.messages || []).forEach(appendChatLine);
  } catch {
    els.chatFeed.innerHTML = '<div class="chat-line" style="opacity:0.6">Chat unavailable</div>';
  }
}

async function sendAppChat(text) {
  if (!isLoggedIn()) return;
  const trimmed = String(text || "").trim();
  if (!trimmed) return;
  try {
    const { ok, data } = await api("/api/mobile/chat", { method: "POST", body: { message: trimmed } });
    if (ok && data) appendChatLine(data.message || data);
    els.chatInput.value = "";
  } catch (e) {
    showToast(e.message || "Could not send message");
  }
}

async function startLink() {
  els.linkError.hidden = true;
  els.btnLinkStart.disabled = true;
  try {
    const session = getSession();
    const { ok, data } = await api("/api/mobile/link/start", {
      method: "POST",
      body: { deviceId: session.deviceId },
    });
    if (!ok || !data?.code) throw new Error("Could not start link.");
    linkCode = String(data.code).toUpperCase();
    els.linkStatus.hidden = false;
    els.linkCode.textContent = data.tiktokCommand || `!link ${linkCode}`;
    els.linkWait.textContent = "Waiting for your TikTok comment on LIVE…";
    clearInterval(linkPollTimer);
    linkPollTimer = setInterval(pollLink, 2000);
    pollLink();
  } catch (e) {
    els.linkError.hidden = false;
    els.linkError.textContent = e.message || "Link failed.";
    els.btnLinkStart.disabled = false;
  }
}

async function pollLink() {
  if (!linkCode) return;
  try {
    const { data } = await api(`/api/mobile/link/status/${encodeURIComponent(linkCode)}`);
    if (!data) return;
    if (data.status === "linked" && data.token && data.userId) {
      clearInterval(linkPollTimer);
      linkPollTimer = null;
      saveSession({ token: data.token, userId: data.userId });
      els.linkStatus.hidden = true;
      els.btnLinkStart.disabled = false;
      showLoggedIn();
      showToast("Linked to TikTok!");
    } else if (data.status === "expired_or_unknown") {
      clearInterval(linkPollTimer);
      linkPollTimer = null;
      els.linkError.hidden = false;
      els.linkError.textContent = "Link code expired — tap Link TikTok to try again.";
      els.linkStatus.hidden = true;
      els.btnLinkStart.disabled = false;
    } else if (data.expiresInSeconds != null) {
      els.linkWait.textContent = `Waiting… ${data.expiresInSeconds}s left`;
    }
  } catch {
    /* keep polling */
  }
}

function cancelLink() {
  clearInterval(linkPollTimer);
  linkPollTimer = null;
  linkCode = "";
  els.linkStatus.hidden = true;
  els.btnLinkStart.disabled = false;
}

async function logout() {
  try {
    await api("/api/mobile/session/logout", { method: "POST", body: {} });
  } catch {
    /* ignore */
  }
  clearSession();
  cancelLink();
  showLoggedOut();
}

function showLoggedIn() {
  const session = getSession();
  els.linkPanel.hidden = true;
  els.main.hidden = false;
  els.topbar.hidden = false;
  els.tabbar.hidden = false;
  els.userPill.textContent = session.displayName || session.userId || "Player";
  updateMobileShell();
  connectWs();
  refreshWallet();
  refreshLiveStatus();
  loadBoard();
  loadChat();
  startPresence();
  startChatPoll();
  arcade.loadCatalog();
}

function showLoggedOut() {
  els.linkPanel.hidden = false;
  els.main.hidden = true;
  els.topbar.hidden = true;
  els.tabbar.hidden = true;
  if (els.betDockBalance) els.betDockBalance.textContent = "Link TikTok to play";
  document.body.classList.remove("play-shell", "tab-play", "portrait-blocked");
  stopPresence();
  stopChatPoll();
}

function startPresence() {
  stopPresence();
  const beat = async () => {
    if (!isLoggedIn()) return;
    try {
      const session = getSession();
      await api("/api/mobile/presence/heartbeat", {
        method: "POST",
        body: { deviceId: session.deviceId },
      });
    } catch {
      /* ignore */
    }
  };
  beat();
  presenceTimer = setInterval(beat, 30000);
}

function stopPresence() {
  clearInterval(presenceTimer);
  presenceTimer = null;
}

function startChatPoll() {
  stopChatPoll();
  chatPollTimer = setInterval(() => {
    if (document.querySelector('[data-screen="chat"].screen-active')) loadChat();
  }, 8000);
}

function stopChatPoll() {
  clearInterval(chatPollTimer);
  chatPollTimer = null;
}

function switchTab(tab) {
  activeTab = tab;
  document.querySelectorAll(".tab").forEach((el) => {
    el.classList.toggle("tab-active", el.dataset.tab === tab);
  });
  document.querySelectorAll(".screen").forEach((el) => {
    el.classList.toggle("screen-active", el.dataset.screen === tab);
  });
  document.body.classList.toggle("tab-play", tab === "play");
  measureChrome();
  if (tab === "board") loadBoard();
  if (tab === "chat") loadChat();
  if (tab === "wallet") refreshWallet();
  if (tab === "arcade") window.dispatchEvent(new Event("arcade-tab"));
}

els.btnLinkStart.addEventListener("click", startLink);
els.btnLinkCancel.addEventListener("click", cancelLink);
els.btnLogout.addEventListener("click", logout);
els.betForm.addEventListener("submit", (e) => {
  e.preventDefault();
  placeBet(els.betAmount.value, Number(els.betCashout.value));
});
els.btnBetAll.addEventListener("click", () => placeBet("all", Number(els.betCashout.value)));
els.btnRefreshWallet?.addEventListener("click", refreshWallet);
els.btnBalanceShout?.addEventListener("click", () => sendCommand("!balance"));
els.btnBalanceShoutDock?.addEventListener("click", () => sendCommand("!balance"));
els.chatForm.addEventListener("submit", (e) => {
  e.preventDefault();
  sendAppChat(els.chatInput.value);
});
document.querySelectorAll(".tab").forEach((btn) => {
  btn.addEventListener("click", () => switchTab(btn.dataset.tab));
});

setInterval(() => {
  if (state) applyState(state);
  refreshLiveStatus();
}, 1000);

if (isLoggedIn()) {
  showLoggedIn();
  switchTab("play");
} else {
  showLoggedOut();
  connectWs();
}
requestAnimationFrame(measureChrome);
