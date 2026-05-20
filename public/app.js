const multDisplay = document.getElementById("multDisplay");
const subline = document.getElementById("subline");
const phasePill = document.getElementById("phasePill");
const betList = document.getElementById("betList");
const lastPanel = document.getElementById("lastPanel");
const lastPanelEmpty = document.getElementById("lastPanelEmpty");
const lastResultWrap = document.getElementById("lastResultWrap");
const pointsGuideList = document.getElementById("pointsGuideList");
const lastCrash = document.getElementById("lastCrash");
const winList = document.getElementById("winList");
const loseList = document.getElementById("loseList");
const linePath = document.getElementById("linePath");
const areaPath = document.getElementById("areaPath");
const chartWrap = document.getElementById("chartWrap");
const headDot = document.getElementById("headDot");
const gridLines = document.getElementById("gridLines");
const btnStart = document.getElementById("btnStart");
const nextRoundEta = document.getElementById("nextRoundEta");
const simUser = document.getElementById("simUser");
const simMsg = document.getElementById("simMsg");
const btnSendSim = document.getElementById("btnSendSim");
const btnPoints = document.getElementById("btnPoints");
const feed = document.getElementById("feed");
const admUser = document.getElementById("admUser");
const admSet = document.getElementById("admSet");
const admAdd = document.getElementById("admAdd");
const btnApplyPoints = document.getElementById("btnApplyPoints");
const starterPts = document.getElementById("starterPts");
const btnSaveStarter = document.getElementById("btnSaveStarter");
const board = document.getElementById("board");
const balancesList = document.getElementById("balancesList");
const spotifyMissionBlock = document.getElementById("spotifyMissionBlock");
const spotifyMissionNowPlaying = document.getElementById("spotifyMissionNowPlaying");
const spotifyMissionQueueOne = document.getElementById("spotifyMissionQueueOne");
const topProfiles = document.getElementById("topProfiles");
const taxPotBanner = document.getElementById("taxPotBanner");
const lbTitle = document.getElementById("lbTitle");
const balTitle = document.getElementById("balTitle");
let missionResetAtMs = null;
const balanceToast = document.getElementById("balanceToast");
const balanceToastText = document.getElementById("balanceToastText");
const rewardToastStack = document.getElementById("rewardToastStack");
const actionPopup = document.getElementById("actionPopup");
const actionPopupIcon = document.getElementById("actionPopupIcon");
const actionPopupKicker = document.getElementById("actionPopupKicker");
const actionPopupTitle = document.getElementById("actionPopupTitle");
const actionPopupSub = document.getElementById("actionPopupSub");
const actionPopupText = document.getElementById("actionPopupText");
const iconsOverlay = document.getElementById("iconsOverlay");
const iconsOverlayGrid = document.getElementById("iconsOverlayGrid");
const iconsOverlayFooter = document.getElementById("iconsOverlayFooter");
const queueList = document.getElementById("queueList");
const queueHead = document.getElementById("queueHead");
const roundSummary = document.getElementById("roundSummary");
const roundCrashAt = document.getElementById("roundCrashAt");
const roundWinTotal = document.getElementById("roundWinTotal");
const roundLoseTotal = document.getElementById("roundLoseTotal");
const roundWinList = document.getElementById("roundWinList");
const roundLoseList = document.getElementById("roundLoseList");
const roundTopCards = document.getElementById("roundTopCards");
const roundRecentMult = document.getElementById("roundRecentMult");
const pinnedSlot = document.getElementById("pinnedSlot");
const pinnedText = document.getElementById("pinnedText");
const pinnedTimer = document.getElementById("pinnedTimer");
const spinOverlay = document.getElementById("spinOverlay");
const spinTitle = document.getElementById("spinTitle");
const spinWheel = document.getElementById("spinWheel");
const spinResult = document.getElementById("spinResult");
const spinLegend = document.getElementById("spinLegend");

let balanceToastTimer = null;
let actionPopupTimer = null;
let iconsOverlayTimer = null;
let roundSummaryTimer = null;
let spinHideTimer = null;
let spinResultTimer = null;
let spinRotation = 0;
const ROUND_SUMMARY_SHOW_MS = 5000;
const IS_STREAM_UI =
  !!(document && document.body && document.body.classList.contains("stream-ui"));

let state = null;
let historyMult = [1];
let lastRoundId = 0;
let prevPhase = null;
let lastSummaryRoundId = 0;
let missionsRenderSeq = 0;
let recentCrashMults = [];
let boardRefreshInFlight = false;
let boardRefreshQueued = false;
let boardRefreshQueuedTimer = null;
let lastBoardRefreshAt = 0;

const CHART_W = 400;
const CHART_H = 200;
const PAD_X = 26;
const PAD_Y = 16;

function fmtMult(n) {
  return `${(Math.round(Number(n) * 100) / 100).toFixed(2)}×`;
}

function escHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const NAME_STYLE_META = {
  none: { icon: "", cls: "namefx-none" },
  neon: { icon: "✨", cls: "namefx-neon" },
  royal: { icon: "👑", cls: "namefx-royal" },
  fire: { icon: "🔥", cls: "namefx-fire" },
  ice: { icon: "❄️", cls: "namefx-ice" },
  shadow: { icon: "🌑", cls: "namefx-shadow" },
  rainbow: { icon: "🌈", cls: "namefx-rainbow" },
  pulse: { icon: "💫", cls: "namefx-pulse" },
  glitch: { icon: "⚡", cls: "namefx-glitch" },
};
const USER_PERKS_BY_USER = new Map();
const SUPERFAN_MASCOT_ANIMALS = [
  "🐻", "🐼", "🐨", "🐶", "🐱", "🐰", "🦊", "🦁", "🐯", "🐮",
  "🐷", "🐸", "🐵", "🐹", "🐭", "🐻‍❄️", "🦝", "🦦", "🦥", "🦄",
];
const SUPERFAN_MASCOT_DECOR = ["✨", "💫", "🌟", "🎀", "🍯", "🧸", "💖", "🌈", "🎈", "🫶"];
const SUPERFAN_MASCOTS = (() => {
  const out = [];
  for (const animal of SUPERFAN_MASCOT_ANIMALS) {
    for (const deco of SUPERFAN_MASCOT_DECOR) {
      out.push(`${animal}${deco}`);
    }
  }
  return out;
})();

function userKeyOf(obj) {
  return String((obj && obj.user) || "")
    .trim()
    .toLowerCase();
}

function rememberUserPerks(obj) {
  const key = userKeyOf(obj);
  if (!key) return;
  const prev = USER_PERKS_BY_USER.get(key) || {};
  const next = { ...prev };
  if (obj && obj.superFan === true) next.superFan = true;
  const fanLevel = Math.max(0, Math.floor(Number((obj && obj.superFanLevel) || 0)));
  if (fanLevel > 0) next.superFanLevel = Math.max(0, Math.floor(Number(next.superFanLevel) || 0), fanLevel);
  const iconIdx = Math.floor(Number((obj && obj.superFanIcon) || -1));
  if (Number.isFinite(iconIdx) && iconIdx >= 0) next.superFanIcon = iconIdx;
  if (obj && Object.prototype.hasOwnProperty.call(obj, "nameBadge")) {
    const badge = String(obj.nameBadge || "none").trim().toLowerCase();
    if (badge && badge !== "none") next.nameBadge = badge;
    else delete next.nameBadge;
  }
  USER_PERKS_BY_USER.set(key, next);
}

function userLabel(obj) {
  if (!obj) return "Player";
  return String(obj.displayName || obj.user || "Player").trim();
}

function stripLeadingCrown(name) {
  return String(name || "").replace(/^\s*👑\s*/u, "");
}

const NAME_BADGE_LABELS =
  typeof NFG_BADGE_ICONS !== "undefined" && NFG_BADGE_ICONS.LABELS
    ? NFG_BADGE_ICONS.LABELS
    : {
        acespades: "Ace of Spades",
        chip: "Vault Chip",
        dice: "High Roller",
        bullion: "Gold Bullion",
        lucky7: "Lucky Seven",
        ltc: "Litecoin",
        bitcoin: "Bitcoin",
        ethereum: "Ether Gem",
        whale: "Whale Vault",
        imperial: "NFG Imperial",
        crown: "Royal Vault",
      };

const BADGE_LEGACY_IDS =
  typeof NFG_BADGE_ICONS !== "undefined" && NFG_BADGE_ICONS.resolveBadgeId
    ? null
    : {
        voidmark: "acespades",
        pulsecore: "chip",
        prism: "dice",
        nova: "bullion",
        eclipse: "lucky7",
        nebula: "ltc",
        sovereign: "bitcoin",
        astral: "ethereum",
        transcend: "whale",
        apex: "imperial",
      };

function resolveBadgeIdClient(badgeId) {
  if (typeof NFG_BADGE_ICONS !== "undefined" && typeof NFG_BADGE_ICONS.resolveBadgeId === "function") {
    return NFG_BADGE_ICONS.resolveBadgeId(badgeId);
  }
  const id = String(badgeId || "")
    .trim()
    .toLowerCase();
  return (BADGE_LEGACY_IDS && BADGE_LEGACY_IDS[id]) || id;
}

function normalizeBadgeClass(badgeId) {
  const id = resolveBadgeIdClient(badgeId);
  if (!id || id === "none") return "";
  if (id === "crown" || NAME_BADGE_LABELS[id]) return id;
  return "";
}

/** Purchased status tier — OSRS-style SVG icon before the display name. */
function renderNameStatusIcon(badgeId) {
  const cls = normalizeBadgeClass(badgeId);
  if (!cls) return "";
  if (typeof NFG_BADGE_ICONS !== "undefined" && typeof NFG_BADGE_ICONS.render === "function") {
    return NFG_BADGE_ICONS.render(cls);
  }
  const title = NAME_BADGE_LABELS[cls] || cls;
  return `<span class="nfg-badge nfg-badge--${escHtml(cls)}" title="${escHtml(title)}" aria-hidden="true"></span>`;
}

function renderNameBadgeHtml(badgeId) {
  return renderNameStatusIcon(badgeId);
}

function superFanMascotFor(obj) {
  if (!SUPERFAN_MASCOTS.length) return "🧸";
  const perks = USER_PERKS_BY_USER.get(userKeyOf(obj)) || {};
  const iconIdx = Math.floor(Number((obj && obj.superFanIcon) || perks.superFanIcon || -1));
  if (Number.isFinite(iconIdx) && iconIdx >= 0) {
    return SUPERFAN_MASCOTS[iconIdx % SUPERFAN_MASCOTS.length];
  }
  const seed = String((obj && (obj.user || obj.displayName)) || "").toLowerCase();
  let h = 2166136261 >>> 0;
  for (let i = 0; i < seed.length; i += 1) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return SUPERFAN_MASCOTS[h % SUPERFAN_MASCOTS.length];
}

function renderStyledName(obj, opts) {
  rememberUserPerks(obj);
  const omitLevel = !!(opts && opts.omitLevel);
  const rawName = userLabel(obj);
  const style = String((obj && obj.nameStyle) || "none").toLowerCase();
  const meta = NAME_STYLE_META[style] || NAME_STYLE_META.none;
  const perks = USER_PERKS_BY_USER.get(userKeyOf(obj)) || {};
  const superFan = !!((obj && obj.superFan === true) || perks.superFan === true);
  const superFanLevel = Math.max(
    0,
    Math.floor(Number((obj && obj.superFanLevel) || perks.superFanLevel || 0))
  );
  const activeBadge = String((obj && obj.nameBadge) || perks.nameBadge || "none").toLowerCase();
  const baseName = stripLeadingCrown(rawName);
  const name = escHtml(baseName);
  const icon = meta.icon ? `<span class="namefx-icon">${meta.icon}</span>` : "";
  const level = Math.max(1, Math.floor(Number((obj && obj.level) || 1)));
  const rank = String((obj && obj.rank) || "Rookie").toLowerCase();
  const superFanBadge = superFan
    ? `<span class="name-badge name-badge--superfan" data-fan-level="${superFanLevel}"><span class="name-badge-ico">🧡</span>NFG</span>`
    : "";
  const statusIcon = renderNameStatusIcon(activeBadge);
  const identityParts = [superFanBadge, statusIcon, icon, `<span class="namefx-text">${name}</span>`].filter(
    Boolean
  );
  const identityInner = identityParts.join("");
  const identityWrap = superFan
    ? `<span class="namefx-superfan-frame">${identityInner}</span>`
    : `<span class="namefx-identity">${identityInner}</span>`;
  const levelBadge = omitLevel
    ? ""
    : `<span class="lvl-badge rank-${escHtml(rank)}">Lv.${level}</span>`;
  return `<span class="namefx ${meta.cls}" data-user="${escHtml(String(obj.user || ""))}">
    ${levelBadge}
    ${identityWrap}
  </span>`;
}

function renderTopProfileLevel(row) {
  const level = Math.max(1, Math.floor(Number((row && row.level) || 1)));
  const rank = String((row && row.rank) || "Rookie").toLowerCase();
  return `<span class="lvl-badge rank-${escHtml(rank)} top-profile-lvl">Lv.${level}</span>`;
}

function profileEffectTitle(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  if (lv >= 70) return "Celestial";
  if (lv >= 50) return "Mythic";
  if (lv >= 35) return "Legend";
  if (lv >= 22) return "Elite";
  if (lv >= 12) return "Rising";
  return "Starter";
}

function profileCardTier(level) {
  const lv = Math.max(1, Math.floor(Number(level) || 1));
  if (lv >= 70) return "tier-celestial";
  if (lv >= 50) return "tier-mythic";
  if (lv >= 35) return "tier-legend";
  if (lv >= 22) return "tier-elite";
  if (lv >= 12) return "tier-rising";
  return "tier-starter";
}

function topBalanceColor(balanceValue) {
  const max = 5_000_000_000;
  const v = Math.max(0, Number(balanceValue) || 0);
  const t = Math.max(0, Math.min(1, v / max));
  // 0 -> cool slate/cyan, 1 -> warm gold
  const hue = 205 - t * 155; // 205 -> 50
  const sat = 70 + t * 22; // 70% -> 92%
  const light = 72 - t * 14; // 72% -> 58%
  return `hsl(${Math.round(hue)} ${Math.round(sat)}% ${Math.round(light)}%)`;
}

function renderTopProfiles(rows) {
  if (!topProfiles) return;
  const top = (rows || []).slice(0, 5);
  if (!top.length) {
    topProfiles.replaceChildren();
    const empty = document.createElement("div");
    empty.className = "top-profile-empty";
    empty.textContent = "Top 5 profiles show here";
    topProfiles.appendChild(empty);
    return;
  }
  const frag = document.createDocumentFragment();
  top.forEach((row, i) => {
    rememberUserPerks(row);
    const rank = String((row && row.rank) || "Rookie").toLowerCase();
    const level = Math.max(1, Math.floor(Number((row && row.level) || 1)));
    const balance = Number(row.balance || 0);
    const balanceColor = topBalanceColor(balance);
    const user = escHtml(String((row && row.user) || ""));
    const superFan = !!row.superFan;
    const effect = escHtml(profileEffectTitle(level));
    const tierClass = profileCardTier(level);
    const shieldActive = row.shieldActive && row.shieldMsLeft > 0;
    const shieldTimer = shieldActive ? `🛡 ${fmtDurationMs(row.shieldMsLeft)} shield` : "";
    const jetLockActive = row.jetLockActive && row.jetLockMsLeft > 0;
    const jetLockTimer = jetLockActive ? `✈️ lock ${fmtDurationMs(row.jetLockMsLeft)}` : "";
    const card = document.createElement("article");
    card.className = `top-profile-card rank-${rank} ${tierClass}${superFan ? " top-profile-card--superfan" : ""}`;
    card.innerHTML = `
      <div class="top-profile-head">
        <span class="top-profile-pos">#${i + 1}</span>
        ${renderTopProfileLevel(row)}
      </div>
      <div class="top-profile-display">${renderStyledName(row, { omitLevel: true })}</div>
      <div class="top-profile-user">@${user}</div>
      <div class="top-profile-meta">${escHtml(String(row.rank || "Rookie"))} · ${effect}</div>
      ${shieldActive ? `<div class="top-profile-shield">${escHtml(shieldTimer)}</div>` : ""}
      ${jetLockActive ? `<div class="top-profile-lock">${escHtml(jetLockTimer)}</div>` : ""}
      <div class="top-profile-balance" style="color:${balanceColor}; text-shadow:0 0 8px color-mix(in srgb, ${balanceColor} 38%, transparent);">${balance.toLocaleString()} pts</div>
      ${superFan ? `<div class="top-profile-superfan-mascot" aria-label="Superfan mascot" title="Superfan">${escHtml(superFanMascotFor(row))}</div>` : ""}
    `;
    frag.appendChild(card);
  });
  topProfiles.replaceChildren(frag);
}

function renderTaxPotBanner(gameState) {
  if (!taxPotBanner) return;
  const amount = Math.max(0, Math.floor(Number(gameState?.taxPot?.potAmount || 0)));
  const resetSec = Math.max(0, Math.floor(Number(gameState?.taxPot?.secondsUntilReset || 0)));
  const resetText = resetSec > 0 ? ` · reset ${fmtCountdownFromMs(resetSec * 1000)} UK` : "";
  taxPotBanner.textContent = `💜💰 Tax Pot: ${amount.toLocaleString()} pts${resetText} 💰💜`;
}

function updateBalanceShieldTooltips() {
  if (!board) return;
  const now = Date.now();
  board.querySelectorAll(".shield-badge[data-shield-until]").forEach((el) => {
    const until = Number(el.getAttribute("data-shield-until") || 0);
    if (!Number.isFinite(until) || until <= now) {
      el.setAttribute("title", "Shield inactive");
      return;
    }
    const leftMs = Math.max(0, until - now);
    el.setAttribute("title", `Shield active: ${fmtDurationMs(leftMs)} left`);
  });
}

const LB_FLASH_MS = 2600;

function flashLeaderboardFromLast(res) {
  if (!res || !board) return;
  const winSet = new Set((res.wins || []).map((w) => w.user));
  const loseSet = new Set((res.losses || []).map((l) => l.user));

  function paint(ol) {
    if (!ol) return;
    for (const li of ol.querySelectorAll("li")) {
      const nameEl = li.querySelector(".lb-name");
      const ptsEl = li.querySelector(".lb-pts");
      if (!nameEl || !ptsEl) continue;
      const nameNode = nameEl.querySelector(".namefx");
      const name = nameNode?.getAttribute("data-user") || "";
      ptsEl.classList.remove("pts-flash-up", "pts-flash-down");
      // Force reflow so re-adding the class retriggers animation if needed
      void ptsEl.offsetWidth;
      if (winSet.has(name)) {
        ptsEl.classList.add("pts-flash-up");
        setTimeout(() => ptsEl.classList.remove("pts-flash-up"), LB_FLASH_MS);
      } else if (loseSet.has(name)) {
        ptsEl.classList.add("pts-flash-down");
        setTimeout(() => ptsEl.classList.remove("pts-flash-down"), LB_FLASH_MS);
      }
    }
  }

  paint(board);
}

function showRoundSummary(res) {
  if (!roundSummary || !res) return;
  const wins = Array.isArray(res.wins) ? res.wins : [];
  const losses = Array.isArray(res.losses) ? res.losses : [];
  const winRows = wins.map((w) => ({
    user: w.user,
    displayName: w.displayName,
    nameStyle: w.nameStyle,
    level: w.level,
    rank: w.rank,
    amount: Math.max(0, Math.floor(Number(w.payout) - Number(w.bet))),
  }));
  const lossRows = losses.map((l) => ({
    user: l.user,
    displayName: l.displayName,
    nameStyle: l.nameStyle,
    level: l.level,
    rank: l.rank,
    amount: Math.max(0, Math.floor(Number(l.bet) || 0)),
  }));
  const winTotal = winRows.reduce((a, b) => a + b.amount, 0);
  const loseTotal = lossRows.reduce((a, b) => a + b.amount, 0);

  if (roundCrashAt) roundCrashAt.textContent = `${fmtMult(res.crashPoint)}`;
  if (roundWinTotal) roundWinTotal.textContent = `+${winTotal}`;
  if (roundLoseTotal) roundLoseTotal.textContent = `-${loseTotal}`;
  if (roundWinList) {
    roundWinList.innerHTML = "";
    const top = winRows.sort((a, b) => b.amount - a.amount).slice(0, 10);
    if (!top.length) {
      roundWinList.innerHTML = "<li>None</li>";
    } else {
      for (const row of top) {
        const li = document.createElement("li");
        li.innerHTML = `<span>${renderStyledName(row)}</span><strong>+${row.amount}</strong>`;
        roundWinList.appendChild(li);
      }
    }
  }
  if (roundLoseList) {
    roundLoseList.innerHTML = "";
    const top = lossRows.sort((a, b) => b.amount - a.amount).slice(0, 10);
    if (!top.length) {
      roundLoseList.innerHTML = "<li>None</li>";
    } else {
      for (const row of top) {
        const li = document.createElement("li");
        li.innerHTML = `<span>${renderStyledName(row)}</span><strong>-${row.amount}</strong>`;
        roundLoseList.appendChild(li);
      }
    }
  }

  if (roundTopCards) {
    roundTopCards.innerHTML = "";
    const top3 = winRows.sort((a, b) => b.amount - a.amount).slice(0, 3);
    top3.forEach((row, idx) => {
      const card = document.createElement("div");
      card.className = `round-top-card rank-${idx + 1}`;
      card.innerHTML = `
        <div class="round-top-rank">#${idx + 1}</div>
        <div class="round-top-name">${renderStyledName(row)}</div>
        <div class="round-top-net">+${row.amount}</div>
      `;
      roundTopCards.appendChild(card);
    });
  }

  if (roundRecentMult) {
    const rows = recentCrashMults.slice(-10).reverse();
    if (!rows.length) {
      roundRecentMult.innerHTML = "";
    } else {
      roundRecentMult.innerHTML = `
        <div class="round-recent-title">Last 10 multipliers</div>
        <div class="round-recent-grid">
          ${rows.map((m) => `<span class="round-recent-pill">${fmtMult(m)}</span>`).join("")}
        </div>
      `;
    }
  }

  roundSummary.hidden = false;
  roundSummary.classList.remove("show");
  // Force reflow to restart animation.
  void roundSummary.offsetWidth;
  roundSummary.classList.add("show");

  clearTimeout(roundSummaryTimer);
  roundSummaryTimer = setTimeout(() => {
    roundSummary.classList.remove("show");
    roundSummary.hidden = true;
  }, ROUND_SUMMARY_SHOW_MS);
}

function updateSkyboxByState(s) {
  if (document && document.body && document.body.classList.contains("stream-ui")) {
    // Keep stream mode background static to avoid perceived flicker/twitch.
    return;
  }
  if (!document || !document.body || !s) return;
  const phase = s.phase || "idle";
  const mult = Number(s.multiplier || 1);
  const crash = Number(s.crashPoint || mult || 1);
  const base = phase === "ended" ? crash : mult;
  const lvl = Math.max(0, Math.min(1, (Math.log2(Math.max(1, base)) || 0) / 8));
  const hueA = Math.round(258 + lvl * 52);
  const hueB = Math.round(318 + lvl * 26);
  const satA = Math.round(62 + lvl * 20);
  const satB = Math.round(66 + lvl * 18);
  const lightA = Math.round(40 + lvl * 18);
  const lightB = Math.round(44 + lvl * 16);
  const alpha = (0.28 + lvl * 0.45).toFixed(2);
  document.body.style.setProperty("--sky-a", `${hueA} ${satA}% ${lightA}% / ${alpha}`);
  document.body.style.setProperty("--sky-b", `${hueB} ${satB}% ${lightB}% / ${alpha}`);
  document.body.style.setProperty("--sky-c", `${Math.round(hueA + 24)} ${satA}% ${lightA}% / ${alpha}`);
}

function renderPinned(pinned) {
  if (!pinnedSlot || !pinnedText || !pinnedTimer) return;
  if (!pinned || !pinned.text || !pinned.user) {
    pinnedSlot.hidden = true;
    pinnedText.textContent = "";
    pinnedTimer.textContent = "";
    return;
  }
  const left = Math.max(0, Math.ceil((Number(pinned.expiresAt || 0) - Date.now()) / 1000));
  if (left <= 0) {
    pinnedSlot.hidden = true;
    pinnedText.textContent = "";
    pinnedTimer.textContent = "";
    return;
  }
  pinnedSlot.hidden = false;
  pinnedText.innerHTML = `${renderStyledName(pinned)}: ${escHtml(pinned.text)}`;
  pinnedTimer.textContent = `${left}s`;
}

function spinSegmentColor(index, total) {
  const hue = Math.floor((index / Math.max(1, total)) * 360);
  return `hsl(${hue} 82% 56%)`;
}

function spinOutcomeText(seg) {
  const id = String(seg && seg.id ? seg.id : "").toLowerCase();
  if (id === "miss") return "No payout";
  if (id === "half") return "Get 0.5x ticket back";
  if (id === "refund") return "Get full ticket back";
  if (id === "boost") return "Get 1.5x ticket";
  if (id === "double") return "Get 2x ticket";
  if (id === "mega") return "Get 3x ticket";
  return `Payout ${seg && seg.label ? seg.label : "?"}`;
}

function showSpinOverlay(p) {
  if (!spinOverlay || !spinWheel || !spinTitle || !spinResult || !p) return;
  const segments = Array.isArray(p.segments) && p.segments.length
    ? p.segments
    : [
        { label: "MISS" },
        { label: "0.5x" },
        { label: "1x" },
        { label: "1.5x" },
        { label: "2x" },
        { label: "3x" },
      ];
  const n = segments.length;
  const sector = 360 / n;
  const bg = [];
  const colors = [];
  for (let i = 0; i < n; i += 1) {
    const a0 = i * sector;
    const a1 = (i + 1) * sector;
    const color = spinSegmentColor(i, n);
    colors.push(color);
    bg.push(`${color} ${a0}deg ${a1}deg`);
  }
  spinWheel.style.background = `conic-gradient(${bg.join(",")})`;
  spinWheel.innerHTML = "";
  const wheelSize = spinWheel.clientWidth || 300;
  spinWheel.style.setProperty("--label-radius", `${Math.max(62, Math.floor(wheelSize * 0.34))}px`);
  for (let i = 0; i < n; i += 1) {
    const seg = segments[i];
    const center = i * sector + sector / 2;
    const lab = document.createElement("span");
    lab.className = "spin-seg-label";
    lab.style.setProperty("--ang", `${center}deg`);
    lab.textContent = seg.label || `S${i + 1}`;
    spinWheel.appendChild(lab);
  }
  if (spinLegend) {
    spinLegend.innerHTML = "";
    segments.forEach((seg, i) => {
      const row = document.createElement("div");
      row.className = "spin-legend-row";
      row.innerHTML = `<span class="spin-legend-swatch" style="background:${colors[i]}"></span>
        <span class="spin-legend-label">${escHtml(seg.label || "-")}</span>
        <span class="spin-legend-desc">${escHtml(spinOutcomeText(seg))}</span>`;
      spinLegend.appendChild(row);
    });
  }

  const stopIndex = Math.max(0, Math.min(n - 1, Number(p.resultIndex) || 0));
  // pointer is at top center; center chosen segment on pointer
  const targetCenter = stopIndex * sector + sector / 2;
  const targetRotation = 360 - targetCenter;
  const turns = 8 + Math.floor(Math.random() * 3);
  const spinMs = Math.max(3200, Math.min(9000, Number(p.durationMs) || 7000));
  const startRotation = ((spinRotation % 360) + 360) % 360;
  const finalRotation = startRotation + turns * 360 + targetRotation + (Math.random() * 4 - 2);
  const finalNormalized = ((finalRotation % 360) + 360) % 360;
  spinRotation = finalNormalized;

  spinOverlay.hidden = false;
  spinOverlay.classList.remove("show");
  void spinOverlay.offsetWidth;
  spinOverlay.classList.add("show");

  spinTitle.textContent = `${userLabel(p)} spins (${p.cost} pts)`;
  spinResult.textContent = "Spinning...";
  spinResult.classList.remove("is-positive", "is-negative");

  spinWheel.style.transition = "none";
  spinWheel.style.transform = `rotate(${startRotation}deg)`;
  void spinWheel.offsetWidth;
  spinWheel.style.transition = `transform ${spinMs}ms cubic-bezier(0.08, 0.92, 0.15, 1)`;
  spinWheel.style.transform = `rotate(${finalRotation}deg)`;
  setTimeout(() => {
    spinWheel.style.transition = "none";
    spinWheel.style.transform = `rotate(${finalNormalized}deg)`;
  }, spinMs + 40);

  clearTimeout(spinResultTimer);
  spinResultTimer = setTimeout(() => {
    const net = Number(p.net) || 0;
    const sign = net >= 0 ? "+" : "";
    spinResult.textContent = `${p.resultLabel} · payout ${p.payout} · net ${sign}${net}`;
    spinResult.classList.toggle("is-positive", net >= 0);
    spinResult.classList.toggle("is-negative", net < 0);
  }, Math.max(1200, spinMs - 2300));

  clearTimeout(spinHideTimer);
  spinHideTimer = setTimeout(() => {
    spinOverlay.classList.remove("show");
    spinOverlay.hidden = true;
  }, Math.max(2200, spinMs + 900));
}

function setPhaseLabel(phase) {
  const map = { idle: "Idle", betting: "Entry Open", running: "Running", ended: "Round over" };
  phasePill.textContent = map[phase] || phase;
}

function updateLivePhaseCountdown() {
  if (!state) return;
  if (state.phase === "betting") {
    const sec = Math.max(0, Math.ceil((Number(state.bettingEndsAt || 0) - Date.now()) / 1000));
    if (phasePill) phasePill.textContent = `Entry ${sec}s`;
    if (subline) {
      subline.textContent = `Entry window ${sec}s — !amount mult or !all mult (e.g. !3m 2.5, !30k 2, !all 2)`;
    }
    return;
  }
  if (nextRoundEta) {
    if (state.spinPauseEndsAt && state.phase === "ended") {
      const sec = Math.max(0, Math.ceil((Number(state.spinPauseEndsAt) - Date.now()) / 1000));
      nextRoundEta.hidden = false;
      nextRoundEta.textContent = `Spin queue ${sec}s`;
    } else if (state.nextRoundStartsAt && (state.phase === "idle" || state.phase === "ended")) {
      const sec = Math.max(0, Math.ceil((Number(state.nextRoundStartsAt) - Date.now()) / 1000));
      nextRoundEta.hidden = false;
      nextRoundEta.textContent = `Next round ~${sec}s`;
    }
  }
}

function drawGrid(maxY, innerW, innerH, padX, padY) {
  gridLines.innerHTML = "";
  const NS = "http://www.w3.org/2000/svg";
  const steps = 6;
  for (let i = 0; i <= steps; i += 1) {
    const t = i / steps;
    const mult = 1 + t * (maxY - 1);
    const y = padY + innerH * (1 - t);
    const line = document.createElementNS(NS, "line");
    line.setAttribute("x1", String(padX));
    line.setAttribute("x2", String(padX + innerW));
    line.setAttribute("y1", String(y));
    line.setAttribute("y2", String(y));
    gridLines.appendChild(line);
    const label = document.createElementNS(NS, "text");
    label.setAttribute("x", String(padX + innerW + 6));
    label.setAttribute("y", String(y + 3));
    const dec = mult < 10 ? 2 : mult < 100 ? 1 : 0;
    label.textContent = `${mult.toFixed(dec)}×`;
    gridLines.appendChild(label);
  }
}

function drawChart(mult, crash, phase) {
  const w = CHART_W;
  const h = CHART_H;
  const padX = PAD_X;
  const padY = PAD_Y;
  const innerW = w - padX * 2;
  const innerH = h - padY * 2;

  let maxY = Math.max(2.05, mult * 1.2, 2.2);
  if (phase === "ended" && crash != null) {
    maxY = Math.max(maxY, Number(crash) * 1.08);
  } else if (phase === "running") {
    maxY = Math.max(maxY, mult * 1.25);
  }
  const span = Math.max(maxY - 1, 0.05);

  const yFor = (m) => {
    const clamped = Math.min(Math.max(m, 1), maxY);
    return padY + innerH * (1 - (clamped - 1) / span);
  };

  let pts = historyMult.length ? historyMult.slice() : [1];
  if ((phase === "idle" || phase === "betting") && pts.length === 1) {
    pts = [1, 1];
  }
  const n = pts.length;
  const xs = pts.map((_, i) => padX + (n <= 1 ? 0 : (i / (n - 1)) * innerW));

  let d = "";
  for (let i = 0; i < n; i += 1) {
    const x = xs[i];
    const y = yFor(pts[i]);
    d += i === 0 ? `M ${x} ${y}` : ` L ${x} ${y}`;
  }
  if (!d) d = `M ${padX} ${yFor(1)} L ${padX + innerW} ${yFor(1)}`;

  linePath.setAttribute("d", d);

  const lastX = xs[n - 1];
  const lastY = yFor(pts[n - 1]);
  const baseY = padY + innerH;
  const areaD = `${d} L ${lastX} ${baseY} L ${padX} ${baseY} Z`;
  areaPath.setAttribute("d", areaD);

  headDot.setAttribute("cx", String(lastX));
  headDot.setAttribute("cy", String(lastY));

  drawGrid(maxY, innerW, innerH, padX, padY);

  if (phase === "ended" && (crash != null || mult > 1)) {
    multDisplay.classList.add("crash");
    linePath.setAttribute("stroke", "#fb7185");
    linePath.removeAttribute("filter");
  } else {
    multDisplay.classList.remove("crash");
    linePath.setAttribute("stroke", "url(#lineStrokeGrad)");
    linePath.setAttribute("filter", "url(#lineGlow)");
  }
}

function renderBets(open, queued) {
  betList.innerHTML = "";
  if (!open || !open.length) {
    betList.innerHTML = '<li style="opacity:0.6">No entries this round</li>';
  } else {
    for (const b of open) {
      const li = document.createElement("li");
      li.innerHTML = `<span class="bet-n">${renderStyledName(b)}</span> · ${b.amount} @ ${b.cashout.toFixed(2)}×`;
      betList.appendChild(li);
    }
  }

  if (queueList && queueHead) {
    queueList.innerHTML = "";
    const q = queued || [];
    if (!q.length) {
      queueHead.hidden = true;
    } else {
      queueHead.hidden = false;
      for (const b of q) {
        const li = document.createElement("li");
        li.innerHTML = `<span class="bet-n">${renderStyledName(b)}</span> · ${b.amount} @ ${b.cashout.toFixed(2)}×`;
        queueList.appendChild(li);
      }
    }
  }
}

function renderLast(res) {
  if (!lastResultWrap) return;
  if (!res) {
    lastResultWrap.hidden = true;
    if (lastPanelEmpty) lastPanelEmpty.hidden = false;
    if (lastPanel) lastPanel.classList.remove("has-last-result");
    return;
  }
  lastResultWrap.hidden = false;
  if (lastPanelEmpty) lastPanelEmpty.hidden = true;
  if (lastPanel) lastPanel.classList.add("has-last-result");
  lastCrash.textContent = fmtMult(res.crashPoint);
  winList.innerHTML = "";
  loseList.innerHTML = "";
  for (const w of res.wins || []) {
    const li = document.createElement("li");
    li.className = "last-outcome last-outcome--win";
    const profit = Math.floor(Number(w.payout) - Number(w.bet));
    li.innerHTML = `<span class="last-name"><strong>${renderStyledName(w)}</strong></span>
      <span class="last-delta last-delta--win">+${profit} net</span>
      <span class="last-sub">${escHtml(String(w.payout))} paid · ${escHtml(String(w.bet))} staked</span>`;
    winList.appendChild(li);
  }
  if (!winList.children.length) {
    winList.innerHTML = '<li class="last-empty">—</li>';
  }
  for (const l of res.losses || []) {
    const li = document.createElement("li");
    li.className = "last-outcome last-outcome--lose";
    li.innerHTML = `<span class="last-name"><strong>${renderStyledName(l)}</strong></span>
      <span class="last-delta last-delta--lose">−${escHtml(String(l.bet))}</span>
      <span class="last-sub">out · target ${fmtMult(l.cashout)}</span>`;
    loseList.appendChild(li);
  }
  if (!loseList.children.length) {
    loseList.innerHTML = '<li class="last-empty">—</li>';
  }
}

function applyState(s) {
  if (s.roundId !== lastRoundId) {
    lastRoundId = s.roundId;
    historyMult = [1];
  }
  const phaseBecameEnded = prevPhase !== "ended" && s.phase === "ended";
  state = s;
  document.body.classList.remove("phase-idle", "phase-betting", "phase-running", "phase-ended");
  document.body.classList.add(`phase-${s.phase}`);
  updateSkyboxByState(s);
  setPhaseLabel(s.phase);
  multDisplay.textContent = fmtMult(s.multiplier);

  if (chartWrap) {
    chartWrap.classList.remove("phase-idle", "phase-betting", "phase-running", "phase-ended");
    chartWrap.classList.add(`phase-${s.phase}`);
    if (phaseBecameEnded) {
      chartWrap.classList.add("flash-crash");
      setTimeout(() => {
        chartWrap.classList.remove("flash-crash");
      }, 700);
    }
  }

  if (nextRoundEta) {
    if (s.spinPauseEndsAt && s.phase === "ended") {
      const sec = Math.max(0, Math.ceil((s.spinPauseEndsAt - Date.now()) / 1000));
      nextRoundEta.hidden = false;
      nextRoundEta.textContent = `Spin queue ${sec}s`;
    } else if (s.nextRoundStartsAt && (s.phase === "idle" || s.phase === "ended")) {
      const sec = Math.max(0, Math.ceil((s.nextRoundStartsAt - Date.now()) / 1000));
      nextRoundEta.hidden = false;
      nextRoundEta.textContent = `Next round ~${sec}s`;
    } else {
      nextRoundEta.hidden = true;
      nextRoundEta.textContent = "";
    }
  }

  if (s.phase === "betting") {
    const sec = Math.max(0, Math.ceil((s.bettingEndsAt - Date.now()) / 1000));
    subline.textContent = `Entry window ${sec}s — !amount mult or !all mult (e.g. !3m 2.5, !30k 2, !all 2)`;
    if (historyMult.length === 0 || historyMult[historyMult.length - 1] !== 1) {
      historyMult = [1];
    }
  } else if (s.phase === "running") {
    subline.textContent = "Multiplier climbing — auto cashout when targets hit.";
    const m = s.multiplier;
    if (!historyMult.length || Math.abs(historyMult[historyMult.length - 1] - m) > 0.001) {
      historyMult.push(m);
      if (historyMult.length > 200) historyMult.shift();
    }
  } else if (s.phase === "ended") {
    if (s.pendingSpinCount > 0 || s.spinPauseEndsAt) {
      const sec = Math.max(0, Math.ceil((Number(s.spinPauseEndsAt) - Date.now()) / 1000));
      subline.textContent =
        sec > 0
          ? `Round finished — spin queue in progress (${sec}s).`
          : "Round finished — spin queue in progress.";
    } else {
      subline.textContent = "Round finished — next starts automatically.";
    }
    const endM = s.crashPoint != null ? s.crashPoint : s.multiplier;
    const last = historyMult[historyMult.length - 1];
    if (last == null || Math.abs(last - endM) > 0.02) {
      historyMult.push(endM);
      if (historyMult.length > 200) historyMult.shift();
    }
  } else {
    if (s.nextRoundStartsAt) {
      subline.textContent = "Waiting for next round…";
    } else if (s.opts && s.opts.autoRestartMs) {
      subline.textContent = "Next round starting shortly…";
    } else {
      subline.textContent = "Idle — use “Manual start” in the drawer below.";
    }
    historyMult = [1];
  }

  drawChart(s.multiplier, s.crashPoint ?? s.multiplier, s.phase);
  renderBets(s.openBets, s.queuedBets);
  renderLast(s.lastResult);
  renderPinned(s.pinnedMessage);
  renderTaxPotBanner(s);

  if (phaseBecameEnded && s.lastResult) {
    const crashVal = Number(s.lastResult.crashPoint);
    if (Number.isFinite(crashVal) && crashVal > 0) {
      recentCrashMults.push(crashVal);
      if (recentCrashMults.length > 10) recentCrashMults = recentCrashMults.slice(-10);
    }
    refreshBoard(true)
      .then(() => flashLeaderboardFromLast(s.lastResult))
      .catch(() => {});
    if (s.lastResult.roundId && s.lastResult.roundId !== lastSummaryRoundId) {
      lastSummaryRoundId = s.lastResult.roundId;
      showRoundSummary(s.lastResult);
    }
  }

  prevPhase = s.phase;
}

function pushFeed(text) {
  const li = document.createElement("li");
  li.innerHTML = text;
  feed.prepend(li);
  while (feed.children.length > 40) feed.removeChild(feed.lastChild);
}

function connectWs() {
  const proto = location.protocol === "https:" ? "wss" : "ws";
  const ws = new WebSocket(`${proto}://${location.host}`);
  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.type === "state") applyState(msg.payload);
      if (msg.type === "chat_result") handleChatResult(msg.payload);
      if (msg.type === "reward") handleReward(msg.payload);
      if (msg.type === "balance_toast") showBalanceToast(msg.payload);
      if (msg.type === "game_event") handleGameEvent(msg.payload);
      if (msg.type === "economy_notification") handleEconomyNotification(msg.payload);
      if (msg.type === "icons_popup") showIconsOverlay(msg.payload);
    } catch {
      /* ignore */
    }
  };
  ws.onclose = () => setTimeout(connectWs, 2000);
}

function fmtCountdownFromMs(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = String(Math.floor(total / 3600)).padStart(2, "0");
  const m = String(Math.floor((total % 3600) / 60)).padStart(2, "0");
  const s = String(total % 60).padStart(2, "0");
  return `${h}:${m}:${s}`;
}

function updateMissionHeaderTimer() {
  if (!balTitle) return;
  if (!missionResetAtMs) {
    balTitle.textContent = "Missions to Level Up";
    return;
  }
  const left = missionResetAtMs - Date.now();
  balTitle.textContent = `Missions to Level Up (${fmtCountdownFromMs(left)} UK)`;
}

function mapSpotifyErrorToHint(errorCode) {
  const code = String(errorCode || "");
  if (!code) return "Spotify unavailable";
  if (code === "spotify_not_configured") return "Set HANGMAN_SPOTIFY_* in .env";
  if (code === "no_active_device") return "Open Spotify and start playback";
  if (code === "queue_forbidden_premium_or_scope") return "Queue needs Premium/scope";
  if (code === "queue_list_needs_scope") return "Re-auth Spotify with playback scope";
  if (code.includes("invalid_refresh_token")) return "Run Spotify OAuth again";
  if (code.includes("invalid_client")) return "Check Spotify client id/secret";
  if (code.startsWith("token_http_")) return "Spotify token request failed";
  return "Spotify unavailable";
}

function renderSpotifyMission(status) {
  if (!spotifyMissionBlock || !spotifyMissionNowPlaying || !spotifyMissionQueueOne) return;
  spotifyMissionBlock.hidden = false;
  const nowLine = String(status?.nowPlaying || "").trim();
  const up = Array.isArray(status?.upcoming) ? status.upcoming : [];
  const nextOne = up
    .map((line) => String(line || "").trim())
    .filter(Boolean)[0] || "";

  if (status && status.nowPlayingOk) {
    spotifyMissionNowPlaying.textContent = nowLine || "Nothing playing";
  } else {
    spotifyMissionNowPlaying.textContent = mapSpotifyErrorToHint(status?.nowPlayingError);
  }

  if (status && status.queueOk) {
    spotifyMissionQueueOne.textContent = nextOne || "Queue is empty";
  } else {
    spotifyMissionQueueOne.textContent = mapSpotifyErrorToHint(status?.queueError);
  }
}

async function refreshSpotifyMission() {
  if (!spotifyMissionBlock || !spotifyMissionNowPlaying || !spotifyMissionQueueOne) return;
  try {
    const r = await fetch("/api/spotify/status", { cache: "no-store" });
    if (!r.ok) throw new Error(String(r.status));
    const body = await r.json();
    renderSpotifyMission(body);
  } catch {
    renderSpotifyMission({
      nowPlayingOk: false,
      nowPlayingError: "spotify_unreachable",
      queueOk: false,
      queueError: "spotify_unreachable",
      upcoming: [],
      nowPlaying: "",
    });
  }
}

const POWER_POPUP_PRESETS = {
  steal: { icon: "🌌", kicker: "Galaxy steal", cls: "power-popup--steal", durationMs: 3800 },
  freeze: { icon: "✈️", kicker: "Flying Jet freeze", cls: "power-popup--freeze", durationMs: 3800 },
  shield_break: { icon: "🏎️", kicker: "Car Drifting", cls: "power-popup--shield-break", durationMs: 3800 },
  galaxy_arm: { icon: "🌌", kicker: "Galaxy gift", cls: "power-popup--galaxy-arm", durationMs: 4200 },
  car_drifting_arm: { icon: "🏎️", kicker: "Car Drifting gift", cls: "power-popup--car-arm", durationMs: 4200 },
  flying_jet_arm: { icon: "✈️", kicker: "Flying Jet gift", cls: "power-popup--jet-arm", durationMs: 4200 },
  shield: { icon: "🛡️", kicker: "Racing Debut", cls: "power-popup--shield", durationMs: 4500 },
  interstellar: { icon: "🪐", kicker: "Interstellar", cls: "power-popup--interstellar is-mega", durationMs: 6800 },
  default: { icon: "⚡", kicker: "", cls: "power-popup--default", durationMs: 3200 },
};

function resetActionPopupSlots() {
  for (const el of [actionPopupIcon, actionPopupKicker, actionPopupTitle, actionPopupSub, actionPopupText]) {
    if (!el) continue;
    el.hidden = true;
    el.textContent = "";
    el.innerHTML = "";
  }
}

function showPowerPopup(opts = {}) {
  if (!actionPopup) return;
  const variant = opts.variant || "default";
  const preset = POWER_POPUP_PRESETS[variant] || POWER_POPUP_PRESETS.default;
  const positive = opts.positive !== false;
  const durationMs = Math.max(2200, Number(opts.durationMs) || preset.durationMs || 3200);
  const hasStructured = !!(opts.kicker || opts.title || opts.subtitle || opts.icon);

  resetActionPopupSlots();
  actionPopup.className = "action-popup power-popup";
  for (const cls of String(preset.cls || "").split(/\s+/).filter(Boolean)) {
    actionPopup.classList.add(cls);
  }
  actionPopup.classList.add(positive ? "is-positive" : "is-negative");
  if (variant === "interstellar") actionPopup.classList.add("is-mega");

  if (actionPopupIcon) {
    const icon = opts.icon != null ? String(opts.icon) : preset.icon;
    if (icon) {
      actionPopupIcon.hidden = false;
      actionPopupIcon.textContent = icon;
    }
  }
  if (actionPopupKicker) {
    const kicker = opts.kicker != null ? String(opts.kicker) : preset.kicker;
    if (kicker) {
      actionPopupKicker.hidden = false;
      actionPopupKicker.textContent = kicker;
    }
  }
  if (actionPopupTitle && opts.title) {
    actionPopupTitle.hidden = false;
    actionPopupTitle.innerHTML = opts.title;
  }
  if (actionPopupSub && opts.subtitle) {
    actionPopupSub.hidden = false;
    actionPopupSub.innerHTML = opts.subtitle;
  }
  if (actionPopupText) {
    const legacy = opts.html || opts.message;
    if (legacy && !hasStructured) {
      actionPopupText.hidden = false;
      actionPopupText.innerHTML = legacy;
    } else if (legacy && hasStructured) {
      actionPopupText.hidden = false;
      actionPopupText.innerHTML = legacy;
    }
  }

  if (!hasStructured && !(opts.html || opts.message)) return;

  actionPopup.hidden = false;
  actionPopup.classList.remove("show");
  void actionPopup.offsetWidth;
  actionPopup.classList.add("show");
  clearTimeout(actionPopupTimer);
  actionPopupTimer = setTimeout(() => {
    actionPopup.classList.remove("show");
    actionPopup.hidden = true;
    resetActionPopupSlots();
  }, durationMs);
}

function showActionPopup(message, positive = true) {
  showPowerPopup({ message, positive, variant: "default" });
}

function showGiftPowerPopup(p) {
  const m = p && p.rewardMeta;
  if (!m || !m.special) return;
  const who = renderStyledName(p);
  if (m.special === "galaxy_arm") {
    const n = Number(m.stealsReady) || 1;
    showPowerPopup({
      variant: "galaxy_arm",
      title: who,
      subtitle: `<strong>${n}</strong> steal charge${n === 1 ? "" : "s"} ready · <code>!steal @user</code>`,
    });
    return;
  }
  if (m.special === "car_drifting_break_arm") {
    const n = Number(m.shieldBreaksReady) || 1;
    showPowerPopup({
      variant: "car_drifting_arm",
      title: who,
      subtitle: `<strong>${n}</strong> shield break${n === 1 ? "" : "s"} ready · <code>!break @user</code>`,
    });
    return;
  }
  if (m.special === "flying_jet_lock_arm") {
    const n = Number(m.jetLocksReady) || 1;
    showPowerPopup({
      variant: "flying_jet_arm",
      title: who,
      subtitle: `<strong>${n}</strong> freeze charge${n === 1 ? "" : "s"} ready · <code>!freeze @user</code>`,
    });
    return;
  }
  if (m.special === "shield_applied") {
    const hrs = Number(m.shieldHours) || 48;
    const stacks = Number(m.shieldStacks) || 1;
    showPowerPopup({
      variant: "shield",
      title: who,
      subtitle:
        stacks > 1
          ? `Shield active <strong>${hrs}h</strong> (${stacks}× Racing Debut stacks)`
          : `Shield active for <strong>${hrs}h</strong> · protected from steals`,
    });
    return;
  }
  if (m.special === "interstellar_tax_claim") {
    const claimed = Number(m.claimedAmount) || 0;
    if (m.claimed && claimed > 0) {
      showPowerPopup({
        variant: "interstellar",
        title: who,
        subtitle: `<span class="action-popup-tax-label">FULL TAX POT CLAIMED</span><span class="action-popup-tax-amount">+${fmtNum(claimed)}</span><span class="action-popup-tax-hint">pts added to balance</span>`,
      });
    } else {
      showPowerPopup({
        variant: "interstellar",
        positive: false,
        title: who,
        subtitle: `<span class="action-popup-tax-label">TAX POT EMPTY</span><span class="action-popup-tax-hint">Interstellar used — nothing to claim</span>`,
        durationMs: 5200,
      });
    }
  }
}

function hideIconsOverlay() {
  if (!iconsOverlay) return;
  iconsOverlay.classList.remove("show");
  iconsOverlay.hidden = true;
  iconsOverlay.setAttribute("aria-hidden", "true");
}

function showIconsOverlay(payload) {
  if (!iconsOverlay || !iconsOverlayGrid || !payload || !payload.ok) return;
  const badges = Array.isArray(payload.badges) ? payload.badges : [];
  const durationMs = Math.max(3000, Number(payload.durationMs) || 10_000);
  const triggeredBy = String(payload.displayName || payload.user || "viewer");

  iconsOverlayGrid.innerHTML = "";
  for (const b of badges) {
    const badgeId = String(b.id || "").toLowerCase();
    const card = document.createElement("article");
    card.className = "icons-overlay-item";

    const tier = document.createElement("div");
    tier.className = "icons-overlay-item-tier";
    tier.textContent = `Tier ${Math.max(1, Math.floor(Number(b.tier) || 0))}`;

    const ico = document.createElement("div");
    ico.className = "icons-overlay-item-ico";
    ico.innerHTML =
      typeof NFG_BADGE_ICONS !== "undefined"
        ? NFG_BADGE_ICONS.render(badgeId, { title: b.label || badgeId })
        : renderNameBadgeHtml(badgeId);

    const label = document.createElement("div");
    label.className = "icons-overlay-item-label";
    label.textContent = String(b.label || b.id || "Badge");

    const sampleLabel = document.createElement("span");
    sampleLabel.className = "icons-overlay-item-sample-label";
    sampleLabel.textContent = "In chat";

    const sample = document.createElement("div");
    sample.className = "icons-overlay-item-sample";
    sample.innerHTML = `${renderNameBadgeHtml(badgeId)}<span>YourName</span>`;

    const idLine = document.createElement("div");
    idLine.className = "icons-overlay-item-id";
    idLine.textContent = `!buy ${badgeId}`;

    const cost = document.createElement("div");
    cost.className = "icons-overlay-item-cost";
    cost.textContent = `${fmtNum(Number(b.cost) || 0)} pts`;

    card.append(tier, ico, label, sampleLabel, sample, idLine, cost);
    iconsOverlayGrid.appendChild(card);
  }

  if (iconsOverlayFooter) {
    const durSec = Math.round(durationMs / 1000);
    iconsOverlayFooter.textContent = `Opened by ${triggeredBy} · chat !icons (${durSec}s display, global cooldown)`;
  }

  iconsOverlay.hidden = false;
  iconsOverlay.setAttribute("aria-hidden", "false");
  iconsOverlay.classList.remove("show");
  void iconsOverlay.offsetWidth;
  iconsOverlay.classList.add("show");

  clearTimeout(iconsOverlayTimer);
  iconsOverlayTimer = setTimeout(hideIconsOverlay, durationMs);
}

function handleEconomyNotification(p) {
  if (!p || !p.user || !p.message) return;
  pushFeed(`<strong>${renderStyledName(p)}</strong> ${escHtml(p.message)}`);
}

function handleGameEvent(ev) {
  if (!ev) return;
  if (ev.type === "spin_play") {
    showSpinOverlay(ev);
    pushFeed(
      `<strong>${renderStyledName(ev)}</strong> spun wheel: ${ev.resultLabel} (cost ${ev.cost}, payout ${ev.payout}, net ${ev.net >= 0 ? "+" : ""}${ev.net})`
    );
    refreshBoard();
  }
}

function showBalanceToast(p) {
  if (!balanceToast || !balanceToastText) return;
  if (!p || p.ok === false) {
    if (p && p.cooldown && p.secondsLeft != null) {
      balanceToast.className = "balance-toast";
      balanceToast.hidden = false;
      balanceToastText.textContent = `${userLabel(p)}: wait ${p.secondsLeft}s before !balance again`;
      clearTimeout(balanceToastTimer);
      balanceToastTimer = setTimeout(() => {
        balanceToast.hidden = true;
      }, 3200);
    }
    return;
  }
  balanceToast.hidden = false;
  const shieldText =
    p.shieldActive && p.shieldMsLeft > 0 ? ` · shield ${fmtDurationMs(p.shieldMsLeft)} left` : "";
  const jetLockText =
    p.jetLockActive && p.jetLockMsLeft > 0
      ? ` · flying-jet lock ${fmtDurationMs(p.jetLockMsLeft)} (only !balance)`
      : "";
  const missions = Array.isArray(p.missions) ? p.missions : [];
  const missionLines = missions.length
    ? missions.map((mission) => `${mission.title}: ${mission.progress}/${mission.target}`)
    : ["Mission: complete live actions to level up"];
  const inv = p.inventory || {};
  const inventoryLine = `Inventory — steals: ${Math.max(0, Math.floor(Number(inv.stealCharges) || 0))}, breaks: ${Math.max(
    0,
    Math.floor(Number(inv.shieldBreakCharges) || 0)
  )}, jets: ${Math.max(0, Math.floor(Number(inv.jetLockCharges) || 0))}`;
  const resetLeft = p.missionResetAtMs
    ? `Reset: ${fmtCountdownFromMs(Math.max(0, Number(p.missionResetAtMs) - Date.now()))} (${p.missionResetTimezone || "UK"})`
    : "";
  const lines = [];
  if (resetLeft) lines.push(resetLeft);
  lines.push(inventoryLine);
  lines.push(...missionLines);
  const rank = String((p && p.rank) || "Rookie").toLowerCase();
  const level = Math.max(1, Math.floor(Number((p && p.level) || 1)));
  const tierClass = profileCardTier(level);
  const effectTitle = profileEffectTitle(level);
  balanceToast.className = `balance-toast rank-${rank} ${tierClass}`;
  balanceToastText.innerHTML = `
    <div class="balance-profile">
      <div class="balance-profile-main">
        <div class="balance-profile-display">${escHtml(userLabel(p))}</div>
        <div class="balance-profile-user">@${escHtml(String((p && p.user) || ""))}</div>
      </div>
      <div class="balance-profile-side">
        <div class="balance-profile-level">Lv.${level}</div>
        <div class="balance-profile-rank">${escHtml(String((p && p.rank) || "Rookie"))}</div>
      </div>
      <div class="balance-profile-balance">${escHtml(String(p.balance))} pts${escHtml(
    shieldText
  )}${escHtml(jetLockText)}</div>
      <div class="balance-profile-effect">Profile Effect: ${escHtml(effectTitle)}</div>
      <small>${lines.map((line) => escHtml(line)).join("<br>")}</small>
    </div>
  `;
  clearTimeout(balanceToastTimer);
  balanceToastTimer = setTimeout(() => {
    balanceToast.hidden = true;
  }, 5200);
}

function handleChatResult(p) {
  if (p.type === "spotify_queue") {
    if (p.ok) {
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> queued <span style="color:var(--accent2)">${escHtml(
          String(p.track || "track")
        )}</span> on Spotify`
      );
      refreshSpotifyMission().catch(() => {});
    } else {
      const reason = p.help
        ? p.help
        : mapSpotifyErrorToHint(p.reason || p.error || "spotify_unavailable");
      pushFeed(`<strong>${renderStyledName(p)}</strong> Spotify queue failed: ${escHtml(reason)}`);
    }
    return;
  }

  if (p.type === "balance_line") {
    if (p.cooldown) {
      pushFeed(`<strong>${renderStyledName(p)}</strong> balance hidden — cooldown ${p.secondsLeft}s`);
    } else {
      const shieldText =
        p.shieldActive && p.shieldMsLeft > 0
          ? ` · shield left ${fmtDurationMs(p.shieldMsLeft)}`
          : " · no shield";
      const jetLockText =
        p.jetLockActive && p.jetLockMsLeft > 0
          ? ` · flying-jet lock ${fmtDurationMs(p.jetLockMsLeft)} (only !balance)`
          : "";
      const missions = Array.isArray(p.missions) ? p.missions : [];
      const missionSummary = missions
        .map((mission) => `${mission.title} ${mission.progress}/${mission.target}`)
        .join(" | ");
      const inv = p.inventory || {};
      const inventorySummary = `inv steals:${Math.max(0, Math.floor(Number(inv.stealCharges) || 0))} breaks:${Math.max(
        0,
        Math.floor(Number(inv.shieldBreakCharges) || 0)
      )} jets:${Math.max(0, Math.floor(Number(inv.jetLockCharges) || 0))}`;
      const resetSummary = p.missionResetAtMs
        ? ` · reset ${fmtCountdownFromMs(Math.max(0, Number(p.missionResetAtMs) - Date.now()))} UK`
        : "";
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> balance: ${p.balance}${shieldText}${jetLockText} · ${escHtml(
          inventorySummary
        )}${resetSummary}${missionSummary ? ` · ${escHtml(missionSummary)}` : ""}`
      );
    }
    return;
  }
  if (p.type === "steal_line") {
    if (p.ok) {
      const targetObj = {
        user: p.target,
        displayName: p.targetDisplayName || p.target,
        nameStyle: p.targetNameStyle || "none",
        level: p.targetLevel,
        rank: p.targetRank,
      };
      const bountyText = p.bountyClaimed
        ? ` + bounty ${p.bountyClaimed.amount}`
        : "";
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> stole <span style="color:var(--accent2)">${p.stolen}</span>${bountyText} from <strong>${renderStyledName(targetObj)}</strong> (bal ${p.balance}, steals left ${p.stealsReady})`
      );
      showPowerPopup({
        variant: "steal",
        title: `${renderStyledName(p)} stole from ${renderStyledName(targetObj)}`,
        subtitle: `<span class="action-popup-pts-hit">+${escHtml(String(p.stolen))}</span> points stolen${
          p.bountyClaimed ? ` · bounty +${escHtml(String(p.bountyClaimed.amount))}` : ""
        }`,
      });
    } else if (p.reason === "target_shielded") {
      const targetObj = {
        user: p.target,
        displayName: p.targetDisplayName || p.target,
        nameStyle: p.targetNameStyle || "none",
        level: p.targetLevel,
        rank: p.targetRank,
      };
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> failed steal on <strong>${renderStyledName(targetObj)}</strong>: shield active ${p.secondsLeft}s`
      );
      showPowerPopup({
        variant: "steal",
        positive: false,
        title: `${renderStyledName(p)} steal blocked`,
        subtitle: `${renderStyledName(targetObj)} has an active shield (${Math.max(1, Number(p.secondsLeft) || 0)}s left)`,
      });
    } else if (p.reason === "steal_not_armed") {
      pushFeed(`<strong>${renderStyledName(p)}</strong> tried to steal but has no Galaxy steal charge.`);
      showPowerPopup({
        variant: "steal",
        positive: false,
        title: renderStyledName(p),
        subtitle: "No Galaxy steal charge — send a Galaxy gift first",
      });
    } else if (p.reason === "target_empty") {
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> steal failed: ${escHtml(
          p.targetDisplayName || p.target
        )} has no points to steal.`
      );
      showPowerPopup({
        variant: "steal",
        positive: false,
        title: `${renderStyledName(p)} steal failed`,
        subtitle: `${escHtml(String(p.targetDisplayName || p.target))} has no points to steal`,
      });
    } else {
      pushFeed(`<strong>${renderStyledName(p)}</strong> steal failed: ${p.reason}`);
      showPowerPopup({
        variant: "steal",
        positive: false,
        title: `${renderStyledName(p)} steal failed`,
        subtitle: escHtml(String(p.reason || "unknown")),
      });
    }
    return;
  }
  if (p.type === "shield_break_line") {
    const targetObj = {
      user: p.target,
      displayName: p.targetDisplayName || p.target,
      nameStyle: p.targetNameStyle || "none",
      level: p.targetLevel,
      rank: p.targetRank,
    };
    if (p.ok) {
      const reduced = fmtDurationMs(p.reducedMs || 0);
      const remain = fmtDurationMs(p.shieldMsLeft || 0);
      const detail = p.fullyBroken
        ? `removed the final ${reduced} (shield now down)`
        : `reduced shield by ${reduced} (${remain} left)`;
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> ${escHtml(detail)} on <strong>${renderStyledName(targetObj)}</strong>`
      );
      showPowerPopup({
        variant: "shield_break",
        title: p.fullyBroken
          ? `${renderStyledName(p)} broke ${renderStyledName(targetObj)}'s shield`
          : `${renderStyledName(p)} damaged ${renderStyledName(targetObj)}'s shield`,
        subtitle: p.fullyBroken
          ? `Shield removed (${escHtml(reduced)})`
          : `Reduced by ${escHtml(reduced)} · ${escHtml(remain)} remaining`,
      });
      if (Number(p.targetLockSeconds || 0) > 0) {
        pushFeed(
          `<strong>${renderStyledName(targetObj)}</strong> cannot bet/buy for ${Math.ceil(
            Number(p.targetLockSeconds)
          )}s (or until stolen).`
        );
        if (p.fullyBroken) {
          pushFeed(
            `<strong>${renderStyledName(
              targetObj
            )}</strong> can still send Racing Debut during lock for +48h shield; without that, they are stealable.`
          );
        }
      }
    } else {
      const reasonMap = {
        shield_break_not_armed: "no Car Drifting shield-break charge",
        no_active_shield: "target has no active shield",
      };
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> shield break failed on <strong>${renderStyledName(targetObj)}</strong>: ${reasonMap[p.reason] || p.reason}`
      );
      showPowerPopup({
        variant: "shield_break",
        positive: false,
        title: `${renderStyledName(p)} shield break failed`,
        subtitle: `${renderStyledName(targetObj)} — ${escHtml(String(reasonMap[p.reason] || p.reason))}`,
      });
    }
    return;
  }
  if (p.type === "jet_lock_line") {
    const targetObj = {
      user: p.target,
      displayName: p.targetDisplayName || p.target,
      nameStyle: p.targetNameStyle || "none",
      level: p.targetLevel,
      rank: p.targetRank,
    };
    if (p.ok) {
      const lockText = fmtDurationMs((Number(p.targetLockSeconds) || 0) * 1000);
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> locked <strong>${renderStyledName(
          targetObj
        )}</strong> from betting/buying for ${escHtml(lockText)} (only !balance allowed).`
      );
      showPowerPopup({
        variant: "freeze",
        title: `${renderStyledName(p)} froze ${renderStyledName(targetObj)}`,
        subtitle: `Cannot bet or buy for <strong>${escHtml(lockText)}</strong> · only <code>!balance</code> allowed`,
      });
    } else {
      const reasonMap = {
        jet_lock_not_armed: "no Flying Jet lock charge",
      };
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> flying-jet lock failed on <strong>${renderStyledName(targetObj)}</strong>: ${reasonMap[p.reason] || p.reason}`
      );
      showPowerPopup({
        variant: "freeze",
        positive: false,
        title: `${renderStyledName(p)} freeze failed`,
        subtitle: `${renderStyledName(targetObj)} — ${escHtml(String(reasonMap[p.reason] || p.reason))}`,
      });
    }
    return;
  }
  if (p.type === "command_lock_line") {
    pushFeed(
      `<strong>${renderStyledName(p)}</strong> command blocked: flying-jet lock active (${Math.max(
        1,
        Number(p.secondsLeft || 0)
      )}s left). Only !balance is allowed.`
    );
    showPowerPopup({
      variant: "freeze",
      positive: false,
      title: `${renderStyledName(p)} is frozen`,
      subtitle: `Flying Jet lock · ${Math.max(1, Number(p.secondsLeft || 0))}s left · only <code>!balance</code>`,
    });
    return;
  }
  if (p.type === "bounty_line") {
    if (p.ok) {
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> placed bounty on ${escHtml(p.targetDisplayName || p.target)} for <span style="color:var(--accent2)">${p.amount}</span> pts`
      );
    } else {
      const reason = {
        bounty_too_small: `minimum is ${p.min || 500}`,
        self_target: "you cannot target yourself",
        insufficient: "insufficient points",
        shield_break_lock: shieldBreakLockReasonText(p),
      }[p.reason] || p.reason;
      pushFeed(`<strong>${renderStyledName(p)}</strong> bounty failed: ${reason}`);
    }
    return;
  }
  if (p.type === "pin_line") {
    if (p.ok) {
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> pinned message for ${p.cost} pts: "${escHtml(
          p.text
        )}"`
      );
    } else {
      const reason = {
        pin_empty: "message cannot be empty",
        insufficient: "insufficient points",
        shield_break_lock: shieldBreakLockReasonText(p),
      }[p.reason] || p.reason;
      pushFeed(`<strong>${renderStyledName(p)}</strong> pin failed: ${reason}`);
    }
    return;
  }
  if (p.type === "spin_ticket_line") {
    if (p.ok) {
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> bought a spin ticket for ${p.cost} pts — plays after round ends (queue ${p.queueSize})`
      );
    } else {
      const reasonMap = {
        spin_requires_active_round: "you can only buy spin during an active round",
        insufficient: "insufficient points",
        shield_break_lock: shieldBreakLockReasonText(p),
      };
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> spin failed: ${reasonMap[p.reason] || p.reason}`
      );
    }
    return;
  }
  if (p.type === "namefx_line") {
    if (p.ok) {
      const icon = p.styleIcon ? `${p.styleIcon} ` : "";
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> activated ${icon}${escHtml(p.style)} style for ${p.cost} pts`
      );
    } else {
      const reason =
        p.reason === "style_unknown"
          ? `unknown style (try: ${(p.styles || []).join(", ")})`
          : p.reason === "shield_break_lock"
            ? shieldBreakLockReasonText(p)
          : p.reason;
      pushFeed(`<strong>${renderStyledName(p)}</strong> name style failed: ${reason}`);
    }
    return;
  }
  if (p.type === "icons_line") {
    if (p.cooldown) {
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> vault icons on cooldown — ${p.secondsLeft}s left (anyone can use !icons)`
      );
    } else if (p.ok) {
      pushFeed(`<strong>${renderStyledName(p)}</strong> opened the vault badge shop for everyone`);
    }
    return;
  }
  if (p.type === "buy_line") {
    if (p.ok) {
      const badgeHtml = renderNameBadgeHtml(p.badge);
      const badgeName = escHtml(String(p.badgeLabel || p.badge || "badge"));
      const cost = Number(p.cost || 0);
      const action = p.switched || cost === 0 ? "equipped" : "unlocked";
      const costText =
        cost > 0 ? ` for ${cost.toLocaleString()} pts` : " (owned — no charge)";
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> ${action} ${badgeHtml}<strong>${badgeName}</strong>${costText}`
      );
    } else {
      const reasonMap = {
        badge_unknown: `unknown badge (try: ${(p.badges || []).join(", ")})`,
        badge_already_active: "badge already equipped",
        badge_not_owned: "legacy badge not in your inventory",
        insufficient: "insufficient points",
        shield_break_lock: shieldBreakLockReasonText(p),
        jet_lock_active: "flying-jet lock active (only !balance allowed)",
      };
      pushFeed(`<strong>${renderStyledName(p)}</strong> buy failed: ${reasonMap[p.reason] || p.reason}`);
    }
    return;
  }
  if (p.type === "sell_crown_line") {
    if (p.ok) {
      rememberUserPerks({
        user: p.user,
        displayName: p.displayName,
        nameStyle: p.nameStyle,
        nameBadge: p.nameBadge || "none",
        level: p.level,
        rank: p.rank,
        superFan: p.superFan,
        superFanLevel: p.superFanLevel,
        superFanIcon: p.superFanIcon,
      });
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> sold Crown icon for <span style="color:var(--accent2)">${Number(
          p.refund || 0
        ).toLocaleString()}</span> pts (bal ${Number(p.balance || 0).toLocaleString()})`
      );
    } else {
      const reasonMap = {
        crown_not_owned: "you do not own/equip the Crown icon",
      };
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> crown sell failed: ${reasonMap[p.reason] || p.reason || "unknown"}`
      );
    }
    return;
  }
  if (p.type === "superfan_line") {
    const targetObj = {
      user: p.target,
      displayName: p.targetDisplayName || p.target,
      nameStyle: p.targetNameStyle || "none",
      level: p.targetLevel,
      rank: p.targetRank,
      superFan: !!p.targetSuperFan,
      superFanLevel: p.targetSuperFanLevel || 0,
    };
    if (p.ok) {
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> ${p.active ? "enabled" : "removed"} superfan for <strong>${renderStyledName(targetObj)}</strong>`
      );
      refreshBoard();
    } else {
      const reason = p.reason || "unknown";
      pushFeed(`<strong>${renderStyledName(p)}</strong> superfan command failed: ${escHtml(String(reason))}`);
    }
    return;
  }
  if (p.type === "unknown_command_line") {
    pushFeed(
      `<strong>${renderStyledName(p)}</strong> command not recognized: ${escHtml(String(p.command || "!command"))}`
    );
    return;
  }
  if (p.type === "bet") {
    if (p.ok) {
      const q = p.queued ? " — <em>queued next round</em>" : "";
      pushFeed(
        `<strong>${renderStyledName(p)}</strong> ${p.amount} @ ${p.cashout}×${q} (bal ${p.balance})`
      );
    } else {
      const reasonMap = {
        not_betting: "entry window is closed",
        bad_bet_amount: "invalid amount",
        bad_cashout: "invalid multiplier",
        already_bet: "already entered",
        insufficient: "insufficient points",
        not_queue_phase: "can only queue between rounds",
        shield_break_lock: shieldBreakLockReasonText(p),
        jet_lock_active: "flying-jet lock active (only !balance allowed)",
      };
      const reasonText = reasonMap[p.reason] || p.reason || "unknown";
      pushFeed(`<strong>${renderStyledName(p)}</strong> entry failed: ${reasonText}`);
    }
  }
}

function showRewardToastVisual(p) {
  if (!rewardToastStack || !p || !p.user) return;
  const labels = {
    share: "Share",
    gift: "Gift",
    like: "Like",
    repost: "Repost",
  };
  const k = labels[p.kind] || p.kind || "Reward";
  const kind = String(p.kind || "").toLowerCase();
  const icon =
    kind === "like" ? '<span class="reward-toast-ico reward-toast-ico--like">❤️</span>' :
    kind === "gift" ? '<span class="reward-toast-ico reward-toast-ico--gift">🎁</span>' :
    "";
  const el = document.createElement("div");
  el.className = "reward-toast-item";
  el.innerHTML = `
    <div class="reward-toast-row">
      <span class="reward-toast-name">${icon}${renderStyledName(p)}</span>
      <span class="reward-toast-pts">+${p.gained}</span>
    </div>
    <div class="reward-toast-kind">${k}</div>
  `;
  rewardToastStack.appendChild(el);
  setTimeout(() => {
    el.classList.add("is-out");
    setTimeout(() => {
      el.remove();
    }, 380);
  }, 4500);
  const maxItems = 6;
  while (rewardToastStack.children.length > maxItems) {
    rewardToastStack.removeChild(rewardToastStack.firstChild);
  }
}

function handleReward(p) {
  if (!p || !p.user) return;
  rememberUserPerks(p);
  const labels = {
    share: "Share",
    gift: "Gift",
    like: "Like",
    repost: "Repost",
  };
  const k = labels[p.kind] || p.kind;
  const giftLabel = p.giftName ? ` (${p.giftName})` : "";
  const meta =
    p.rewardMeta && p.rewardMeta.special === "galaxy_arm"
      ? ` · Galaxy armed (${p.rewardMeta.stealsReady} steal${p.rewardMeta.stealsReady === 1 ? "" : "s"})`
      : p.rewardMeta && p.rewardMeta.special === "interstellar_tax_claim"
        ? p.rewardMeta.claimed
          ? ` · Interstellar claimed tax pot +${p.rewardMeta.claimedAmount}`
          : " · Interstellar used but tax pot was empty"
      : p.rewardMeta && p.rewardMeta.special === "car_drifting_break_arm"
        ? ` · Car Drifting armed (${p.rewardMeta.shieldBreaksReady} shield break${p.rewardMeta.shieldBreaksReady === 1 ? "" : "s"})`
      : p.rewardMeta && p.rewardMeta.special === "flying_jet_lock_arm"
        ? ` · Flying Jet armed (${p.rewardMeta.jetLocksReady} lock${p.rewardMeta.jetLocksReady === 1 ? "" : "s"})`
      : p.rewardMeta && p.rewardMeta.special === "shield_applied"
        ? ` · Shield active for ${p.rewardMeta.shieldHours}h`
        : "";
  showRewardToastVisual(p);
  showGiftPowerPopup(p);
  pushFeed(
    `<strong>${renderStyledName(p)}</strong> ${k}${giftLabel} <span style="color:var(--accent2)">+${p.gained}</span> pts (bal ${p.balance})${meta}`
  );
  refreshBoard();
}

async function refreshBoard(force = false) {
  const now = Date.now();
  const minRefreshGapMs = IS_STREAM_UI ? 1600 : 500;
  const sinceLast = now - lastBoardRefreshAt;
  if (!force && sinceLast < minRefreshGapMs) {
    if (!boardRefreshQueued && !boardRefreshQueuedTimer) {
      boardRefreshQueued = true;
      const waitMs = Math.max(60, minRefreshGapMs - sinceLast);
      boardRefreshQueuedTimer = setTimeout(() => {
        boardRefreshQueuedTimer = null;
        boardRefreshQueued = false;
        refreshBoard().catch(() => {});
      }, waitMs);
    }
    return;
  }
  if (!force && boardRefreshInFlight) {
    boardRefreshQueued = true;
    if (!boardRefreshQueuedTimer) {
      boardRefreshQueuedTimer = setTimeout(() => {
        boardRefreshQueuedTimer = null;
        boardRefreshQueued = false;
        refreshBoard(force).catch(() => {});
      }, minRefreshGapMs);
    }
    return;
  }
  boardRefreshInFlight = true;
  lastBoardRefreshAt = now;
  try {
    const rb = await fetch("/api/balances");
    const jb = await rb.json();
    const balances = jb.balances || [];
    renderTopProfiles(balances);
    if (lbTitle) lbTitle.textContent = "Balances";
    const frag = document.createDocumentFragment();
    balances.forEach((row, i) => {
      rememberUserPerks(row);
      const li = document.createElement("li");
      li.title = `${userLabel(row)}: ${row.balance} pts`;
      const shieldIcon =
        row.shieldActive && row.shieldMsLeft > 0
          ? `<span class="shield-badge" data-shield-until="${Number(row.shieldUntil || 0)}" title="Shield active: ${fmtDurationMs(row.shieldMsLeft)} left">🛡</span>`
          : "";
      li.innerHTML = `<span class="lb-rank">${i + 1}</span><span class="lb-name">${renderStyledName(row)}${shieldIcon}</span><span class="lb-pts">${row.balance}</span>`;
      frag.appendChild(li);
    });
    board.replaceChildren(frag);

    updateBalanceShieldTooltips();
  } finally {
    boardRefreshInFlight = false;
    if (boardRefreshQueued && !boardRefreshQueuedTimer) {
      boardRefreshQueued = false;
      boardRefreshQueuedTimer = setTimeout(() => {
        boardRefreshQueuedTimer = null;
        refreshBoard().catch(() => {});
      }, IS_STREAM_UI ? 280 : 120);
    }
  }

}

async function refreshMissions() {
  if (balancesList) {
    const renderSeq = ++missionsRenderSeq;
    balancesList.innerHTML = "";
    const res = await fetch("/api/economy/missions");
    const body = await res.json();
    if (renderSeq !== missionsRenderSeq) return;
    const missionRows = Array.isArray(body.missions) ? body.missions : [];
    missionResetAtMs = Number(body.resetAtMs || 0) || null;
    updateMissionHeaderTimer();
    missionRows.forEach((mission) => {
      const li = document.createElement("li");
      li.className = "mission-row";
      li.innerHTML = `
        <span class="mission-name">${escHtml(mission.title || "Mission")}</span>
        <span class="mission-progress">Target ${mission.target || 0}</span>
        <div class="mission-bar"><div class="mission-bar-fill mission-bar-fill--goal"></div></div>
      `;
      balancesList.appendChild(li);
    });
    if (!missionRows.length) {
      balancesList.innerHTML = '<li class="mission-row"><span class="mission-name">No missions found.</span></li>';
    }
  }
}

async function loadStarter() {
  const r = await fetch("/api/config/starter");
  const j = await r.json();
  starterPts.value = j.starterPoints ?? 5000;
}

function fmtNum(n) {
  if (typeof n !== "number" || !Number.isFinite(n)) return String(n);
  return n.toLocaleString();
}

function fmtDurationMs(ms) {
  const total = Math.max(0, Math.floor(Number(ms) || 0));
  const s = Math.floor(total / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}h ${m}m ${sec}s`;
  if (m > 0) return `${m}m ${sec}s`;
  return `${sec}s`;
}

function shieldBreakLockReasonText(payload) {
  const sec = Math.max(1, Math.floor(Number(payload && payload.secondsLeft) || 0));
  if (!sec) return "shield-break lock active";
  return `shield-break lock active (${sec}s left)`;
}

async function loadPointsGuide() {
  if (!pointsGuideList) return;
  try {
    const r = await fetch("/api/config/rewards");
    const cfg = await r.json();
    const giftMult = cfg.giftCoinMultiplier ?? 500;
    const like = cfg.likePointsPer ?? 25;
    const shieldGift = cfg.shieldGift ?? "Racing Debut";
    const galaxyGift = cfg.galaxyGift ?? "Galaxy";
    const carDriftingGift = cfg.carDriftingGift ?? "Car Drifting";
    const flyingJetGift = cfg.flyingJetGift ?? "Flying Jet";
    const shieldHours = cfg.shieldHours ?? 48;
    const balanceCd = cfg.balanceCooldownSeconds ?? 60;
    const interstellarGift = cfg.interstellarGift ?? "Interstellar";
    const iconsDur = cfg.iconsPopupDurationSeconds ?? 10;
    const iconsCd = cfg.iconsPopupCooldownSeconds ?? 120;
    const rows = [
      {
        pair: [
          { icon: "💬", label: "!balance", value: `${fmtNum(balanceCd)}s cd` },
          { icon: "🌌", label: galaxyGift, value: "!steal @user" },
        ],
      },
      {
        pair: [
          { icon: "🎯", label: "Crash", value: "!3m 2.5 / !all 2" },
          { icon: "🚗", label: carDriftingGift, value: "!break @user" },
        ],
      },
      {
        pair: [
          { icon: "❤️", label: "Like", value: `+${fmtNum(like)}` },
          { icon: "🛡️", label: shieldGift, value: `${fmtNum(shieldHours)}h shield` },
        ],
      },
      {
        pair: [
          { icon: "🎵", label: "!song", value: "Spotify queue" },
          { icon: "🪐", label: interstellarGift, value: "tax pot" },
        ],
      },
      {
        pair: [
          {
            badgeClass: "acespades",
            label: "!icons",
            value: `${iconsDur}s · ${iconsCd}s cd`,
          },
          { icon: "✈️", label: flyingJetGift, value: "!freeze @user" },
        ],
      },
      { icon: "💎", label: "Gift", value: `×${fmtNum(giftMult)} ⓓ` },
    ];

    pointsGuideList.innerHTML = "";
    for (const row of rows) {
      const li = document.createElement("li");
      li.className = "pg-row";

      if (Array.isArray(row.pair) && row.pair.length === 2) {
        li.classList.add("pg-row--pair");
        for (const side of row.pair) {
          const cell = document.createElement("div");
          cell.className = "pg-pair-cell";

          const ico = document.createElement("span");
          ico.className = side.badgeClass ? "pg-ico pg-ico--badge" : "pg-ico";
          ico.setAttribute("aria-hidden", "true");
          if (side.badgeClass) {
            ico.innerHTML =
              typeof NFG_BADGE_ICONS !== "undefined"
                ? NFG_BADGE_ICONS.render(side.badgeClass)
                : `<span class="nfg-badge nfg-badge--${escHtml(side.badgeClass)}"></span>`;
          } else {
            ico.textContent = side.icon || "";
          }

          const mid = document.createElement("div");
          mid.className = "pg-mid";

          const lab = document.createElement("span");
          lab.className = "pg-lab";
          lab.textContent = side.label || "";

          const val = document.createElement("span");
          val.className = "pg-val";
          val.textContent = side.value || "";

          mid.append(lab, val);
          cell.append(ico, mid);
          li.appendChild(cell);
        }
      } else {
        const ico = document.createElement("span");
        ico.className = row.badgeClass ? "pg-ico pg-ico--badge" : "pg-ico";
        ico.setAttribute("aria-hidden", "true");
        if (row.badgeClass) {
          ico.innerHTML =
            typeof NFG_BADGE_ICONS !== "undefined"
              ? NFG_BADGE_ICONS.render(row.badgeClass)
              : `<span class="nfg-badge nfg-badge--${escHtml(row.badgeClass)}"></span>`;
        } else {
          ico.textContent = row.icon;
        }

        const mid = document.createElement("div");
        mid.className = "pg-mid";

        const lab = document.createElement("span");
        lab.className = "pg-lab";
        lab.textContent = row.label;

        const val = document.createElement("span");
        val.className = "pg-val";
        val.textContent = row.value;

        mid.append(lab, val);
        li.append(ico, mid);
      }
      pointsGuideList.appendChild(li);
    }
  } catch {
    pointsGuideList.innerHTML = '<li class="pg-row pg-row--err">Could not load points.</li>';
  }
}

btnStart.addEventListener("click", async () => {
  historyMult = [1];
  await fetch("/api/round/start", { method: "POST" });
});

btnSendSim.addEventListener("click", async () => {
  const user = simUser.value.trim();
  const message = simMsg.value.trim();
  if (!user || !message) return;
  await fetch("/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user, message }),
  });
  simMsg.value = "";
});

btnPoints.addEventListener("click", async () => {
  const user = simUser.value.trim();
  if (!user) return;
  await fetch("/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user, message: "!points" }),
  });
});

simMsg.addEventListener("keydown", (e) => {
  if (e.key === "Enter") btnSendSim.click();
});

btnApplyPoints.addEventListener("click", async () => {
  const user = admUser.value.trim();
  if (!user) return;
  const set = admSet.value === "" ? undefined : Number(admSet.value);
  const add = admAdd.value === "" ? undefined : Number(admAdd.value);
  await fetch("/api/admin/points", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user, set, add }),
  });
  admSet.value = "";
  admAdd.value = "";
  refreshBoard();
});

btnSaveStarter.addEventListener("click", async () => {
  const starterPoints = Number(starterPts.value);
  await fetch("/api/config/starter", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ starterPoints }),
  });
});

// Disable forced periodic full re-renders to keep stream layout visually stable.

setInterval(() => {
  if (!state) return;
  renderPinned(state.pinnedMessage);
}, IS_STREAM_UI ? 1000 : 500);

setInterval(updateBalanceShieldTooltips, 1000);

connectWs();
refreshBoard();
refreshSpotifyMission();
loadStarter();
loadPointsGuide();
if (!IS_STREAM_UI) {
  setInterval(refreshBoard, 8000);
}
setInterval(refreshSpotifyMission, IS_STREAM_UI ? 15000 : 5000);
setInterval(updateLivePhaseCountdown, 250);

fetch("/api/state")
  .then((r) => r.json())
  .then(applyState)
  .catch(() => {});

// Best-effort lookup window for browser mode only.
try {
  const isElectron = /electron/i.test(navigator.userAgent || "");
  if (!isElectron && !sessionStorage.getItem("nfg_lookup_opened")) {
    sessionStorage.setItem("nfg_lookup_opened", "1");
    setTimeout(() => {
      window.open("/player-lookup.html", "NFGCrashLookup", "width=720,height=900");
    }, 500);
  }
} catch {
  /* ignore popup/session storage restrictions */
}
