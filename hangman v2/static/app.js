(function initPortraitMode() {
  try {
    if (new URLSearchParams(location.search).get("portrait") === "1") {
      document.documentElement.classList.add("portrait-mode");
      document.body.classList.add("portrait-mode");
    }
  } catch (_) {
    /* ignore */
  }
})();

const wordSlots = document.getElementById("wordSlots");
const leaderboard = document.getElementById("leaderboard");
const alltimeTop5 = document.getElementById("alltimeTop5");
const statusText = document.getElementById("statusText");
const dot = document.getElementById("dot");
const monitor = document.getElementById("monitor");
const roundPopup = document.getElementById("roundPopup");
const roundPopupWord = document.getElementById("roundPopupWord");
const roundPopupMvps = document.getElementById("roundPopupMvps");
const roundPopupSealed = document.getElementById("roundPopupSealed");
const roundPopupMvpSection = document.getElementById("roundPopupMvpSection");
const roundPopupSealedSection = document.getElementById("roundPopupSealedSection");
const letterKeyboard = document.getElementById("letterKeyboard");
const hintPopup = document.getElementById("hintPopup");
const hintPopupFrom = document.getElementById("hintPopupFrom");
const hintPopupText = document.getElementById("hintPopupText");
const pointsPopup = document.getElementById("pointsPopup");
const pointsPopupAvatar = document.getElementById("pointsPopupAvatar");
const pointsPopupName = document.getElementById("pointsPopupName");
const pointsPopupScore = document.getElementById("pointsPopupScore");
const commandListPopup = document.getElementById("commandListPopup");
const commandListTitle = document.getElementById("commandListTitle");
const commandListSub = document.getElementById("commandListSub");
const commandListUl = document.getElementById("commandListUl");
const galaxyStealPopup = document.getElementById("galaxyStealPopup");
const galaxyStealThiefAvatar = document.getElementById("galaxyStealThiefAvatar");
const galaxyStealThiefName = document.getElementById("galaxyStealThiefName");
const galaxyStealStoleLine = document.getElementById("galaxyStealStoleLine");
const galaxyStealVictimAvatar = document.getElementById("galaxyStealVictimAvatar");
const galaxyStealVictimName = document.getElementById("galaxyStealVictimName");
const capSidelinePopup = document.getElementById("capSidelinePopup");
const capSidelineSenderAvatar = document.getElementById("capSidelineSenderAvatar");
const capSidelineSenderName = document.getElementById("capSidelineSenderName");
const capSidelineHeroLine = document.getElementById("capSidelineHeroLine");
const capSidelineVictimAvatar = document.getElementById("capSidelineVictimAvatar");
const capSidelineVictimName = document.getElementById("capSidelineVictimName");
const shieldTrimPopup = document.getElementById("shieldTrimPopup");
const shieldTrimSenderAvatar = document.getElementById("shieldTrimSenderAvatar");
const shieldTrimSenderName = document.getElementById("shieldTrimSenderName");
const shieldTrimVictimAvatar = document.getElementById("shieldTrimVictimAvatar");
const shieldTrimVictimName = document.getElementById("shieldTrimVictimName");
const shieldTrimDetail = document.getElementById("shieldTrimDetail");
const shieldGraceBanner = document.getElementById("shieldGraceBanner");
const fanGatePopup = document.getElementById("fanGatePopup");
const fanGateAvatar = document.getElementById("fanGateAvatar");
const fanGateName = document.getElementById("fanGateName");
const fanGateMsg = document.getElementById("fanGateMsg");
const fanOnlyToggle = document.getElementById("fanOnlyToggle");
const tiktokLiveUserInput = document.getElementById("tiktokLiveUsername");
const tiktokLiveConnectBtn = document.getElementById("tiktokLiveConnectBtn");
let tiktokUsernameInputPrefilled = false;
const wordTheme = document.getElementById("wordTheme");
const liveLikesTotal = document.getElementById("liveLikesTotal");
const liveLikesTopList = document.getElementById("liveLikesTopList");
const likeMvpBanner = document.getElementById("likeMvpBanner");
const likeMvpAvatar = document.getElementById("likeMvpAvatar");
const likeMvpName = document.getElementById("likeMvpName");
const likeMvpLikes = document.getElementById("likeMvpLikes");
const likeMvpCountdown = document.getElementById("likeMvpCountdown");
const lionNukeBanner = document.getElementById("lionNukeBanner");
const lionNukeCountdown = document.getElementById("lionNukeCountdown");
const lionNukeStarter = document.getElementById("lionNukeStarter");
const lionFreezeOverlay = document.getElementById("lionFreezeOverlay");
const lionFreezeCountdown = document.getElementById("lionFreezeCountdown");
const lionFreezeStarter = document.getElementById("lionFreezeStarter");
const playerOutToast = document.getElementById("playerOutToast");
const hangmanHelpPopup = document.getElementById("hangmanHelpPopup");
const hangmanHelpBody = document.getElementById("hangmanHelpBody");
const hangmanHelpFrom = document.getElementById("hangmanHelpFrom");
const hangmanHelpBackdrop = document.getElementById("hangmanHelpBackdrop");
const hangmanHelpClose = document.getElementById("hangmanHelpClose");
const wagerStrip = document.getElementById("wagerStrip");
const spotifyNowPlayingTitle = document.getElementById("spotifyNowPlayingTitle");
const spotifyUpNextList = document.getElementById("spotifyUpNextList");
const wagerIntroPopup = document.getElementById("wagerIntroPopup");
const wagerIntroVsRow = document.getElementById("wagerIntroVsRow");
const wagerIntroStake = document.getElementById("wagerIntroStake");
const wagerResultPopup = document.getElementById("wagerResultPopup");
const wagerResultCard = document.getElementById("wagerResultCard");

let _prevPlayerOutByKey = null;
let _playerOutToastTimer = null;
let likeMvpPayoutAtUnix = 0;
let likeMvpRewardPts = 2000;
let lionNukeDeadlineUnix = 0;

/** Halo tier from lifetime best consecutive seals (15 / 30 / 50 / 100); persists in all-time JSON. */
function wordStreakGlowTierSuffix(peakCount) {
  const v = Number(peakCount);
  if (!Number.isFinite(v) || v < 15) return "";
  if (v >= 100) return " word-streak-glow--t4";
  if (v >= 50) return " word-streak-glow--t3";
  if (v >= 30) return " word-streak-glow--t2";
  return " word-streak-glow--t1";
}

/** A–Z rows for on-screen letter status (green = in word, red = guessed wrong). */
const KEYBOARD_ROWS = ["ABCDEFGHI", "JKLMNOPQR", "STUVWXYZ"];

/** Letter count for the current word strip (used by slot scaling + resize refit). */
let lastWordLetterCount = 0;

/**
 * Shift modal popups / “out for this word” toast so their vertical center lines up with the
 * hangman letter strip (#wordSlots), while staying horizontally centered.
 */
function syncPopupWordRowAnchor() {
  const slots = document.getElementById("wordSlots");
  if (!slots) return;
  const r = slots.getBoundingClientRect();
  let midY;
  if (r.height >= 2) {
    midY = r.top + r.height / 2;
  } else {
    const theme = document.getElementById("wordTheme");
    const tr = theme?.getBoundingClientRect();
    midY =
      tr && tr.bottom > 0 ? tr.bottom + 42 : Math.min(window.innerHeight * 0.34, window.innerHeight * 0.5);
  }
  const offset = midY - window.innerHeight * 0.5;
  document.documentElement.style.setProperty(
    "--popup-y-offset",
    `${Math.round(offset * 10) / 10}px`
  );
}

/**
 * Scale letter slots so the strip fits the available width (accounts for the gift rail).
 * Uses --word-slot-scale; tightens further if scrollWidth still exceeds clientWidth.
 */
function fitWordSlotsToWidth(letterCount) {
  if (!wordSlots) return;
  lastWordLetterCount = letterCount;
  if (letterCount === 0) {
    wordSlots.style.removeProperty("--word-slot-scale");
    syncPopupWordRowAnchor();
    return;
  }
  let sc = 1;
  if (letterCount > 7) {
    sc = Math.min(1, (8.25 / letterCount) ** 0.94);
    sc = Math.max(0.22, sc);
  }
  const setSc = (v) => {
    if (v >= 0.998) wordSlots.style.removeProperty("--word-slot-scale");
    else wordSlots.style.setProperty("--word-slot-scale", v.toFixed(4));
  };
  setSc(sc);
  requestAnimationFrame(() => {
    if (!wordSlots) return;
    const cw = wordSlots.clientWidth;
    if (cw < 40) {
      syncPopupWordRowAnchor();
      return;
    }
    let cur = letterCount > 7 ? sc : 1;
    let guard = 0;
    while (wordSlots.scrollWidth > cw + 1 && guard < 36 && cur > 0.2) {
      cur *= 0.91;
      setSc(cur);
      guard++;
    }
    syncPopupWordRowAnchor();
  });
}

let gameWs = null;
let roundPopupTimer = null;
let hintPopupTimer = null;
let pointsPopupTimer = null;
let galaxyStealPopupTimer = null;
let capSidelinePopupTimer = null;
let fanGatePopupTimer = null;
let commandListPopupTimer = null;
let shieldTrimPopupTimer = null;
let hangmanHelpPopupTimer = null;
let wagerIntroTimer = null;
let wagerResultTimer = null;

/** @type {{ user_key?: string, display_name?: string, grace_until?: number }[]} */
let shieldGraceWindows = [];

/** @type {ReturnType<typeof setInterval> | null} */
let _alltimeShieldHintTimer = null;

function fmtShieldGraceRemaining(graceUntilUnix) {
  const ms = Number(graceUntilUnix) * 1000 - Date.now();
  if (ms <= 0) return "00:00";
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${String(m).padStart(2, "0")}:${r.toString().padStart(2, "0")}`;
}

/** Racing Debut shield time left (matches server `_fmt_shield_remaining`). */
function fmtRacingDebutShieldRemaining(expUnixSec) {
  const left = Math.max(0, Number(expUnixSec) - Date.now() / 1000);
  if (left <= 0) return "";
  const h = Math.floor(left / 3600);
  const m = Math.floor((left % 3600) / 60);
  if (h >= 24) {
    const d = Math.floor(h / 24);
    return `${d} day(s) ${h % 24}h left`;
  }
  return `${h}h ${m}m left`;
}

function updateAlltimeShieldHoverHints() {
  if (!alltimeTop5) return;
  alltimeTop5.querySelectorAll("[data-shield-until]").forEach((wrap) => {
    const hint = wrap.querySelector(".alltime-shield-hover-hint");
    if (!hint) return;
    const u = Number(wrap.dataset.shieldUntil);
    if (!Number.isFinite(u) || u * 1000 <= Date.now()) {
      hint.textContent = "";
      return;
    }
    hint.textContent = fmtRacingDebutShieldRemaining(u);
  });
}

function ensureAlltimeShieldHintTicker() {
  if (_alltimeShieldHintTimer != null) return;
  _alltimeShieldHintTimer = setInterval(updateAlltimeShieldHoverHints, 1000);
}

function renderShieldGraceBanner() {
  if (!shieldGraceBanner) return;
  const rows = (shieldGraceWindows || []).filter(
    (w) => w && w.grace_until != null && Number(w.grace_until) * 1000 > Date.now()
  );
  if (!rows.length) {
    shieldGraceBanner.classList.add("hidden");
    shieldGraceBanner.setAttribute("hidden", "");
    shieldGraceBanner.innerHTML = "";
    return;
  }
  shieldGraceBanner.classList.remove("hidden");
  shieldGraceBanner.removeAttribute("hidden");
  const title =
    '<p class="shield-grace-banner-title">Shield removed — renew window</p>';
  const body = rows
    .map((w) => {
      const name =
        nameBadgePrefixHtml(w.name_badge) +
        escapeHtml(String(w.display_name || w.user_key || "?"));
      const rem = fmtShieldGraceRemaining(w.grace_until);
      return `<p class="shield-grace-row shield-grace-row--full" role="status">In <span class="shield-grace-time">${escapeHtml(
        rem
      )}</span> &mdash; <span class="shield-grace-name">${name}</span>&rsquo;s shield is down. Renew with Racing Debut now, or it&rsquo;s open to Galaxy steal when this hits zero!</p>`;
    })
    .join("");
  shieldGraceBanner.innerHTML = title + body;
}

function setStatus(st) {
  statusText.textContent = st;
  dot.className = "dot";
  if (st === "connected") dot.classList.add("ok");
  else if (String(st).startsWith("error") || st === "disconnected" || st === "stopped")
    dot.classList.add("err");
  else dot.classList.add("warn");
}

function playerRowKey(p) {
  const k = p.user_key != null && p.user_key !== undefined ? String(p.user_key).trim() : "";
  return k || String(p.name || "").trim() || "";
}

function showPlayerOutToast(displayName, nameBadge) {
  if (!playerOutToast) return;
  syncPopupWordRowAnchor();
  if (_playerOutToastTimer) {
    clearTimeout(_playerOutToastTimer);
    _playerOutToastTimer = null;
  }
  const label = textWithNameBadge((displayName || "").trim() || "Player", nameBadge);
  playerOutToast.textContent = `${label} is OUT FOR THIS ROUND`;
  playerOutToast.classList.remove("hidden");
  _playerOutToastTimer = setTimeout(() => {
    playerOutToast.classList.add("hidden");
    playerOutToast.textContent = "";
    _playerOutToastTimer = null;
  }, 1800);
}

function renderWagerStrip(state) {
  if (!wagerStrip) return;
  const w = state && state.wager;
  if (!w || !w.key_a || !w.key_b) {
    wagerStrip.classList.add("hidden");
    wagerStrip.innerHTML = "";
    return;
  }
  const amt = Number(w.amount) || 0;
  const ba = nameBadgePrefixHtml(w.name_badge_a);
  const bb = nameBadgePrefixHtml(w.name_badge_b);
  const na = ba + escapeHtml(String(w.name_a || ""));
  const nb = bb + escapeHtml(String(w.name_b || ""));
  wagerStrip.innerHTML = `
    <p class="wager-strip-kicker">Head-to-head wager</p>
    <div class="wager-strip-inner">
      <div class="wager-strip-face">
        <img src="${avatarUrl(String(w.key_a))}" alt="" width="44" height="44" decoding="async" referrerpolicy="no-referrer" />
        <span class="wager-strip-name">${na}</span>
      </div>
      <span class="wager-strip-vs">VS</span>
      <div class="wager-strip-face">
        <img src="${avatarUrl(String(w.key_b))}" alt="" width="44" height="44" decoding="async" referrerpolicy="no-referrer" />
        <span class="wager-strip-name">${nb}</span>
      </div>
    </div>
    <p class="wager-strip-amount">${amt} all-time pts · only these two can guess</p>
  `;
  wagerStrip.classList.remove("hidden");
}

function placeSpotifyDock(state) {
  const block = document.getElementById("spotifyNowBlock");
  const above = document.getElementById("spotifyDockAboveWord");
  const under = document.getElementById("spotifyDockUnderGifts");
  if (!block || !above || !under) return;
  const portrait = document.documentElement.classList.contains("portrait-mode");
  const w = state && state.wager;
  const wagerOn = !!(w && w.key_a && w.key_b);
  if (portrait && wagerOn) {
    under.classList.remove("hidden");
    under.setAttribute("aria-hidden", "false");
    if (block.parentElement !== under) under.appendChild(block);
  } else {
    under.classList.add("hidden");
    under.setAttribute("aria-hidden", "true");
    if (block.parentElement !== above) above.appendChild(block);
  }
}

async function fetchHangmanSpotifyNowPlaying() {
  if (!spotifyNowPlayingTitle) return;
  try {
    const r = await fetch("/api/hangman/now-playing", { cache: "no-store" });
    if (!r.ok) throw new Error(String(r.status));
    const d = await r.json();
    if (d.ok && d.line) {
      spotifyNowPlayingTitle.textContent = d.playing === false ? "Paused · " + d.line : d.line;
    } else if (d.error === "no_spotify_session") {
      spotifyNowPlayingTitle.textContent = "Start Spotify on this PC";
    } else if (d.error === "winrt_missing") {
      spotifyNowPlayingTitle.textContent = "Install winrt packages (pip install -r requirements.txt)";
    } else if (d.error === "not_windows") {
      spotifyNowPlayingTitle.textContent = "Now playing needs Windows + Spotify desktop";
    } else {
      spotifyNowPlayingTitle.textContent = "—";
    }
  } catch {
    spotifyNowPlayingTitle.textContent = "—";
  }
}

async function fetchHangmanSpotifyUpNext() {
  if (!spotifyUpNextList) return;
  const maxNext = 2;
  try {
    const r = await fetch("/api/hangman/spotify-queue-list", { cache: "no-store" });
    if (!r.ok) throw new Error(String(r.status));
    const d = await r.json();
    spotifyUpNextList.innerHTML = "";
    if (d.ok && Array.isArray(d.upcoming) && d.upcoming.length > 0) {
      for (const line of d.upcoming.slice(0, maxNext)) {
        const t = String(line).trim();
        if (!t) continue;
        const li = document.createElement("li");
        li.textContent = t;
        spotifyUpNextList.appendChild(li);
      }
      if (spotifyUpNextList.children.length > 0) return;
    }
    const li = document.createElement("li");
    li.className = "meta";
    if (d.error === "spotify_not_configured") {
      li.textContent = "Add HANGMAN_SPOTIFY_* to .env for queue";
    } else if (
      d.error === "invalid_refresh_token_run_oauth_again" ||
      d.error === "invalid_client_id_or_secret_check_dashboard" ||
      (typeof d.error === "string" && d.error.startsWith("token_http_"))
    ) {
      li.textContent =
        d.error === "invalid_client_id_or_secret_check_dashboard"
          ? "Spotify client id/secret wrong — check .env"
          : d.error === "invalid_refresh_token_run_oauth_again"
            ? "Run py hangman_spotify_oauth_once.py then restart"
            : "Spotify token failed — see /api/hangman/spotify-auth-status";
    } else if (d.error === "queue_list_needs_scope") {
      li.textContent = d.hint || "Run hangman_spotify_oauth_once.py (read playback scope)";
    } else if (d.error === "no_active_device") {
      li.textContent = "Open Spotify and start playback";
    } else if (d.error === "queue_list_401" || d.error === "auth_failed") {
      li.textContent = "Spotify auth failed — check .env / oauth";
    } else if (d.ok && Array.isArray(d.upcoming) && d.upcoming.length === 0) {
      li.textContent = typeof d.hint === "string" && d.hint.trim() ? d.hint.trim() : "Nothing queued yet";
    } else {
      li.textContent = d.error || "—";
    }
    spotifyUpNextList.appendChild(li);
  } catch {
    spotifyUpNextList.innerHTML = "";
    const li = document.createElement("li");
    li.className = "meta";
    li.textContent = "—";
    spotifyUpNextList.appendChild(li);
  }
}

async function refreshHangmanSpotify() {
  await Promise.all([fetchHangmanSpotifyNowPlaying(), fetchHangmanSpotifyUpNext()]);
}

function renderState(state) {
  if (wordTheme) wordTheme.textContent = state.word_theme || "";
  renderWagerStrip(state);

  wordSlots.innerHTML = "";
  const slots = state.slots || [];
  let group = document.createElement("span");
  group.className = "word-group";

  for (let i = 0; i < slots.length; i++) {
    const ch = slots[i];
    if (ch === " ") {
      if (group.childNodes.length) {
        wordSlots.appendChild(group);
        group = document.createElement("span");
        group.className = "word-group";
      }
      continue;
    }
    const span = document.createElement("span");
    span.className = "slot" + (ch ? "" : " empty");
    span.textContent = ch || "\u00A0";
    group.appendChild(span);
  }
  if (group.childNodes.length) wordSlots.appendChild(group);

  const letterCount = slots.filter((c) => c !== " ").length;
  fitWordSlotsToWidth(letterCount);

  renderKeyboard(state);

  leaderboard.innerHTML = "";
  const players = state.players || [];
  players.forEach((p, i) => {
    const li = document.createElement("li");
    const metaHtml = p.out ? ` <span class="meta">out</span>` : "";
    const key = p.user_key != null && p.user_key !== undefined ? String(p.user_key) : "";
    const showGlow = !!p.glow;
    const creature = sessionMascotCreatureHtml(p, key || `anon-${i}`, "user-creature--sm");
    const nc = p.name_color != null ? String(p.name_color).trim() : "";
    let nameClass = "leaderboard-name-block";
    if (showGlow) nameClass += " name-glow";
    if (nc) nameClass += " has-name-color";
    const likeT = Math.max(0, Math.floor(Number(p.like_cosmetic_tier) || 0));
    nameClass += likeCosmeticTierClasses(likeT);
    const colorAttr = mergeLikeHueIntoColorAttr(nameColorStyleAttr(nc), likeT);
    const rawStreak = p.word_solve_streak;
    const wss = Number(rawStreak);
    const streakN = Number.isFinite(wss) && wss > 0 ? Math.floor(wss) : 0;
    const rawPeak = p.word_streak_peak;
    const peakN = Number.isFinite(Number(rawPeak)) ? Math.max(0, Math.floor(Number(rawPeak))) : 0;
    const streakGlowClass = wordStreakGlowTierSuffix(peakN);
    const streakHtml =
      streakN > 0
        ? ` <span class="leaderboard-word-streak" aria-label="${streakN} words sealed in a row">${String(
            streakN
          )} \u{1F525}</span>`
        : "";
    const streakWrapClass = `leaderboard-name-streak-wrap${streakGlowClass}`;
    const nbPre = nameBadgePrefixHtml(p.name_badge);
    li.innerHTML = `<span class="leaderboard-line-main">${creature}<span class="${streakWrapClass}"><span class="${nameClass}"${colorAttr}>${i + 1}. ${nbPre}${escapeHtml(
      p.name
    )}</span>${streakHtml}</span></span><span>${p.score}${metaHtml}</span>`;
    leaderboard.appendChild(li);
  });

  const nextOut = new Map();
  (state.players || []).forEach((p) => {
    const k = playerRowKey(p);
    if (!k) return;
    nextOut.set(k, !!p.out);
  });
  if (_prevPlayerOutByKey !== null) {
    nextOut.forEach((out, k) => {
      if (out && _prevPlayerOutByKey.get(k) === false) {
        const pl = (state.players || []).find((x) => playerRowKey(x) === k);
        if (pl) showPlayerOutToast(pl.name, pl.name_badge);
      }
    });
  }
  _prevPlayerOutByKey = nextOut;
  placeSpotifyDock(state);
}

function renderKeyboard(state) {
  if (!letterKeyboard) return;
  const kb = state.keyboard || {};
  const correct = new Set(kb.correct || []);
  const wrong = new Set(kb.wrong || []);
  letterKeyboard.innerHTML = "";
  KEYBOARD_ROWS.forEach((row) => {
    const rowEl = document.createElement("div");
    rowEl.className = "kb-row";
    for (const ch of row) {
      const key = document.createElement("span");
      key.className = "kb-key";
      key.textContent = ch;
      if (correct.has(ch)) key.classList.add("kb-correct");
      else if (wrong.has(ch)) key.classList.add("kb-wrong");
      else key.classList.add("kb-unused");
      rowEl.appendChild(key);
    }
    letterKeyboard.appendChild(rowEl);
  });
}

function normalizeUserKeyRef(k) {
  return String(k == null ? "" : k)
    .trim()
    .replace(/^@+/, "")
    .toLowerCase();
}

/** Safe `#rgb` / `#rrggbb` from server, or "". */
function sanitizeNameColorHex(hex) {
  if (hex == null || hex === "") return "";
  const s = String(hex).trim();
  if (!/^#[0-9A-Fa-f]{3}$|^#[0-9A-Fa-f]{6}$/.test(s)) return "";
  return s;
}

/** All-time shop: !buy prefix star|heart|crown — whitelist only. */
function nameBadgeEmoji(badge) {
  const b = badge != null ? String(badge).trim().toLowerCase() : "";
  if (b === "star") return "\u2B50";
  if (b === "heart") return "\u2764\uFE0F";
  if (b === "crown") return String.fromCodePoint(0x1f451);
  return "";
}

function nameBadgePrefixHtml(badge) {
  const em = nameBadgeEmoji(badge);
  if (!em) return "";
  return `<span class="user-name-badge" aria-hidden="true">${em}</span>`;
}

/** Server: +1 tier per 50k lifetime LIVE likes — extra classes on name elements. */
function likeCosmeticTierClasses(tier) {
  const t = Math.max(0, Math.floor(Number(tier) || 0));
  if (t < 1) return "";
  if (t <= 10) return ` like-name-tier-${t}`;
  return " like-name-tier-11plus";
}

function likeCosmeticHueInlineStyle(tier) {
  const t = Math.max(0, Math.floor(Number(tier) || 0));
  if (t <= 10) return "";
  const hue = (t * 53) % 360;
  return ` style="--like-cosmetic-hue:${hue}"`;
}

function mergeLikeHueIntoColorAttr(colorAttr, tier) {
  const hueStyle = likeCosmeticHueInlineStyle(tier);
  if (!hueStyle) return colorAttr || "";
  const inner = hueStyle.replace(/^\s*style="/, "").replace(/"$/, "");
  if (!colorAttr || !String(colorAttr).trim()) return ` style="${inner}"`;
  const m = String(colorAttr).trim().match(/^style="(.*)"\s*$/);
  if (m) return ` style="${m[1]};${inner}"`;
  return colorAttr;
}

function textWithNameBadge(name, badge) {
  const em = nameBadgeEmoji(badge);
  const n = (name != null ? String(name) : "").trim();
  return em && n ? `${em} ${n}` : n || (em ? em : "");
}

/**
 * CSS custom props for !buy glow on all-time top 5 name border: unique per user_key (two hashes).
 * Optional `nameColorHex`: border/sparkles follow purchased name colour instead of the rainbow ring.
 */
function alltimeGlowSparkleStyleAttr(userKeyRef, nameColorHex) {
  const str = normalizeUserKeyRef(userKeyRef) || "anon";
  let a = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    a ^= str.charCodeAt(i);
    a = Math.imul(a, 16777619) >>> 0;
  }
  let b = 5381 >>> 0;
  for (let i = 0; i < str.length; i++) {
    b = ((b << 5) + b + str.charCodeAt(i)) >>> 0;
  }
  const hue = a % 360;
  const spin = 3.15 + (b % 950) / 200;
  const fall = 1.42 + (a >>> 4) % 140 / 100;
  const delay = -((b >>> 6) % 160) / 100;
  const driftPx = (a % 29) - 14;
  const nh = sanitizeNameColorHex(nameColorHex);
  const nameVar = nh ? `--name-glow-hex:${nh};` : "";
  return ` style="${nameVar}--glow-h:${hue};--glow-spin-dur:${spin.toFixed(2)}s;--spark-fall-dur:${fall.toFixed(2)}s;--spark-fall-delay:${delay.toFixed(2)}s;--spark-drift-x:${driftPx}px;"`;
}

/** Stable creature from 500-slot pool (see user-characters.js). */
function userCreatureHtml(userKey) {
  const fn = typeof window !== "undefined" && window.getUserCreatureIconHtml;
  if (typeof fn === "function") return fn(userKey || "anon", "");
  return `<div class="alltime-mascot-float"><div class="alltime-mascot-bounce"><svg class="ohana-svg" viewBox="0 0 48 48" width="44" height="44" aria-hidden="true"><circle cx="24" cy="24" r="12" fill="#64748b"/></svg></div></div>`;
}

/** Session leaderboard: default creature, heart shop, or glow crown / heart toggle. */
function sessionMascotCreatureHtml(p, fallbackKey, sizeClass) {
  const showGlow = !!p.glow;
  const preferCrown = p.glow_mascot_crown !== false;
  const heartRaw = p.heart_color != null ? String(p.heart_color).trim() : "";
  const heartHex = sanitizeNameColorHex(heartRaw);
  const key =
    p.user_key != null && String(p.user_key).trim() !== ""
      ? String(p.user_key)
      : fallbackKey;
  if (showGlow && preferCrown) return glowCrownIconHtml(key, sizeClass);
  if (showGlow && !preferCrown && heartHex) return userHeartMascotHtml(heartHex, sizeClass);
  if (showGlow) return glowCrownIconHtml(key, sizeClass);
  if (heartHex) return userHeartMascotHtml(heartHex, sizeClass);
  return userCreatureHtml(key);
}

/** All-time top 5 row mascot (same rules as session). */
function alltimeMascotCreatureHtml(r, iconKey, rankIndex) {
  const showGlow = !!r.glow;
  const preferCrown = r.glow_mascot_crown !== false;
  const hcRaw = r.heart_color != null ? String(r.heart_color).trim() : "";
  const heartHex = sanitizeNameColorHex(hcRaw);
  const key = iconKey || r.name || `rank-${rankIndex}`;
  if (showGlow && preferCrown) return glowCrownIconHtml(key, "");
  if (showGlow && !preferCrown && heartHex) return userHeartMascotHtml(heartHex, "");
  if (showGlow) return glowCrownIconHtml(key, "");
  if (heartHex) return userHeartMascotHtml(heartHex, "");
  return userCreatureHtml(key);
}

/** Crown for !buy glow: 500 procedural variants per user_key (see user-characters.js). */
function glowCrownIconHtml(userKey, sizeClass) {
  const fn = typeof window !== "undefined" && window.getGlowCrownIconHtml;
  if (typeof fn === "function") return fn(userKey || "anon", sizeClass != null ? String(sizeClass) : "");
  const size = sizeClass != null ? String(sizeClass) : "";
  return `<div class="alltime-mascot-float user-glow-crown ${size}"><div class="alltime-mascot-bounce"><svg class="user-crown-svg ohana-svg" viewBox="0 0 48 48" width="44" height="44" aria-hidden="true"><circle cx="24" cy="24" r="10" fill="#ca8a04"/></svg></div></div>`;
}

/** Coloured heart mascot (!buy pink heart). With glow, shown when glow_mascot_crown is false. */
function userHeartMascotHtml(hex, sizeClass) {
  const fill = sanitizeNameColorHex(hex);
  if (!fill) return userCreatureHtml("anon");
  const size = sizeClass != null ? String(sizeClass) : "";
  const sm = size.includes("user-creature--sm");
  const w = sm ? 34 : 44;
  const h = w;
  const path =
    "M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z";
  const glow = `${fill}99`;
  return `<div class="alltime-mascot-float ${size}" style="filter:drop-shadow(0 2px 4px rgba(0,0,0,0.35)) drop-shadow(0 0 10px ${glow})"><div class="alltime-mascot-bounce"><svg class="user-heart-svg ohana-svg" viewBox="0 0 24 24" width="${w}" height="${h}" aria-hidden="true"><path fill="${fill}" d="${path}"/></svg></div></div>`;
}

/** When a round ends, bounce the ohana mascot if the winner is in the all-time top 5 row. */
function triggerOhanaWinJump(roundPop) {
  if (!alltimeTop5 || !roundPop) return;
  const winnerKeys = new Set();
  (roundPop.mvps || []).forEach((m) => {
    const k = normalizeUserKeyRef(m.user_key);
    if (k) winnerKeys.add(k);
  });
  if (roundPop.sealed_by && roundPop.sealed_by.user_key) {
    const k = normalizeUserKeyRef(roundPop.sealed_by.user_key);
    if (k) winnerKeys.add(k);
  }
  if (!winnerKeys.size) return;

  alltimeTop5.querySelectorAll(".alltime-hero-row[data-user-key]").forEach((row) => {
    const rk = normalizeUserKeyRef(row.dataset.userKey);
    if (!rk || !winnerKeys.has(rk)) return;
    const bounce = row.querySelector(".alltime-mascot-bounce");
    if (!bounce) return;
    bounce.classList.remove("alltime-mascot-bounce--jump");
    void bounce.offsetWidth;
    bounce.classList.add("alltime-mascot-bounce--jump");
    const done = () => bounce.classList.remove("alltime-mascot-bounce--jump");
    bounce.addEventListener("animationend", done, { once: true });
  });
}

function alltimeShieldPillHtml(shieldUntil) {
  if (shieldUntil == null || shieldUntil === undefined) return "";
  const exp = Number(shieldUntil);
  if (!Number.isFinite(exp) || exp * 1000 <= Date.now()) return "";
  const leftMs = exp * 1000 - Date.now();
  const h = Math.floor(leftMs / 3600000);
  const m = Math.floor((leftMs % 3600000) / 60000);
  const title = `Racing Debut: protected from Galaxy steals — ${h}h ${m}m left`;
  const hint = fmtRacingDebutShieldRemaining(exp);
  const svg =
    '<svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><path fill="currentColor" d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 2.18l7 3.12v5.7c0 4.54-3.07 8.44-7 9.55-3.93-1.11-7-5.01-7-9.55V6.3l7-3.12z"/></svg>';
  const untilAttr = String(Math.floor(exp));
  return `<span class="alltime-shield-pill-wrap" data-shield-until="${escapeHtml(untilAttr)}"><span class="alltime-shield-pill" style="color:#4ade80" title="${escapeHtml(
    title
  )}" role="img" aria-label="${escapeHtml(title)}">${svg}</span><span class="alltime-shield-hover-hint">${escapeHtml(
    hint
  )}</span></span>`;
}

function renderAlltime(rows) {
  if (!alltimeTop5) return;
  alltimeTop5.innerHTML = "";
  const top = (rows || []).slice(0, 5);
  if (!top.length) {
    const li = document.createElement("li");
    li.className = "alltime-hero-empty";
    li.textContent = "No totals yet";
    alltimeTop5.appendChild(li);
    return;
  }
  top.forEach((r, i) => {
    const li = document.createElement("li");
    li.className = "alltime-hero-row";
    const rawKey = r.user_key != null && r.user_key !== undefined ? String(r.user_key).trim() : "";
    if (rawKey) li.dataset.userKey = rawKey;
    const handle = rawKey.startsWith("@") ? rawKey.slice(1) : rawKey;
    const handleLine = handle
      ? `<span class="alltime-hero-handle" title="Type this @ in chat (e.g. Galaxy)">@${escapeHtml(handle)}</span>`
      : "";
    const iconKey = rawKey || r.name || `rank-${i}`;
    const showGlow = !!r.glow;
    const mascot = alltimeMascotCreatureHtml(r, iconKey, i);
    const nc = r.name_color != null ? String(r.name_color).trim() : "";
    let nameClass = "alltime-hero-name";
    if (showGlow) nameClass += " name-glow";
    if (nc) nameClass += " has-name-color";
    const likeT = Math.max(0, Math.floor(Number(r.like_cosmetic_tier) || 0));
    nameClass += likeCosmeticTierClasses(likeT);
    const colorAttr = mergeLikeHueIntoColorAttr(nameColorStyleAttr(nc), likeT);
    const shield = alltimeShieldPillHtml(r.shield_until);
    const peakRaw = r.word_streak_peak;
    const peakN = Number.isFinite(Number(peakRaw)) ? Math.max(0, Math.floor(Number(peakRaw))) : 0;
    const alltimeNameGlow = wordStreakGlowTierSuffix(peakN);
    const nbPre = nameBadgePrefixHtml(r.name_badge);
    const nameSpan = `<span class="${nameClass}"${colorAttr}>${nbPre}${escapeHtml(r.name)}</span>`;
    let namePart = nameSpan;
    if (showGlow) {
      const sk = alltimeGlowSparkleStyleAttr(rawKey || r.name || `rank-${i}`, nc);
      const byo = sanitizeNameColorHex(nc) ? " alltime-glow-sparkle-wrap--byo-color" : "";
      namePart = `<span class="alltime-glow-sparkle-wrap${byo}"${sk}>${nameSpan}</span>`;
    }
    const nameAndShield = `${namePart}${shield}`;
    const nameHtml = alltimeNameGlow
      ? `<span class="alltime-hero-name-streak-wrap${alltimeNameGlow}">${nameAndShield}</span>`
      : nameAndShield;
    li.innerHTML = `${mascot}<span class="alltime-hero-rank">${i + 1}</span>${nameHtml}${handleLine}<span class="alltime-hero-score">${r.total}</span>`;
    alltimeTop5.appendChild(li);
  });
  updateAlltimeShieldHoverHints();
  ensureAlltimeShieldHintTicker();
}

function escapeHtml(s) {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

function formatLikeMvpCountdown(totalMs) {
  const ms = Math.max(0, totalMs);
  const s = Math.floor(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
}

function tickLikeMvpCountdown() {
  if (!likeMvpCountdown || !likeMvpBanner || likeMvpBanner.hidden) return;
  const ms = likeMvpPayoutAtUnix * 1000 - Date.now();
  likeMvpCountdown.textContent = formatLikeMvpCountdown(ms);
  likeMvpCountdown.title = `Top liker gets +${likeMvpRewardPts} all-time points when this hits 0`;
}

function formatNukeCountdown(totalMs) {
  const s = Math.max(0, Math.floor(totalMs / 1000));
  const m = Math.floor(s / 60);
  const sec = s % 60;
  return `${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
}

function tickLionNukeCountdown() {
  if (!lionNukeBanner || !lionNukeCountdown) return;
  if (!lionFreezeOverlay || !lionFreezeCountdown || lionNukeBanner.hidden) return;
  const ms = lionNukeDeadlineUnix * 1000 - Date.now();
  if (ms <= 0) {
    lionNukeBanner.hidden = true;
    lionFreezeOverlay.hidden = true;
    lionNukeDeadlineUnix = 0;
    return;
  }
  const txt = formatNukeCountdown(ms);
  lionNukeCountdown.textContent = txt;
  lionFreezeCountdown.textContent = txt;
}

function renderLionNukeBanner(payload) {
  if (!lionNukeBanner || !lionNukeCountdown || !lionNukeStarter) return;
  if (!lionFreezeOverlay || !lionFreezeCountdown || !lionFreezeStarter) return;
  if (!payload || payload.active !== true) {
    lionNukeDeadlineUnix = 0;
    lionNukeBanner.hidden = true;
    lionFreezeOverlay.hidden = true;
    return;
  }
  const d = Number(payload.deadline_unix) || 0;
  if (!Number.isFinite(d) || d <= 0 || d * 1000 <= Date.now()) {
    lionNukeDeadlineUnix = 0;
    lionNukeBanner.hidden = true;
    lionFreezeOverlay.hidden = true;
    return;
  }
  lionNukeDeadlineUnix = d;
  const who = String(payload.started_by_name || payload.started_by_user_key || "unknown");
  lionNukeStarter.textContent = who;
  lionFreezeStarter.textContent = who;
  lionNukeBanner.hidden = false;
  lionFreezeOverlay.hidden = false;
  tickLionNukeCountdown();
}

function renderLikeMvpBanner(b) {
  if (!likeMvpBanner || !b) return;
  likeMvpPayoutAtUnix = Number(b.payout_at_unix) || 0;
  likeMvpRewardPts = Math.max(1, Math.floor(Number(b.reward_points) || 2000));
  likeMvpBanner.hidden = false;
  const uk = b.user_key != null ? String(b.user_key).trim() : "";
  if (!uk) {
    if (likeMvpName)
      likeMvpName.innerHTML = `<span class="brand-alltime-topliker-empty">No lifetime likes yet</span>`;
    if (likeMvpAvatar) {
      likeMvpAvatar.hidden = true;
      likeMvpAvatar.removeAttribute("src");
    }
    if (likeMvpLikes) likeMvpLikes.textContent = "";
    tickLikeMvpCountdown();
    return;
  }
  const nm = escapeHtml(String(b.name != null ? b.name : "Player").trim() || "Player");
  const lt = Math.max(0, Math.floor(Number(b.like_cosmetic_tier) || 0));
  const tcls = likeCosmeticTierClasses(lt).trim();
  const lh = likeCosmeticHueInlineStyle(lt);
  const nb = nameBadgePrefixHtml(b.name_badge);
  if (likeMvpName) {
    likeMvpName.innerHTML = `<span class="brand-alltime-topliker-name${tcls ? ` ${tcls}` : ""}"${lh}>${nb}${nm}</span>`;
  }
  if (likeMvpAvatar) {
    likeMvpAvatar.hidden = false;
    likeMvpAvatar.src = avatarUrl(uk);
  }
  const likes = Math.max(0, Math.floor(Number(b.live_likes_lifetime) || 0));
  if (likeMvpLikes) likeMvpLikes.textContent = `${likes.toLocaleString()} likes`;
  tickLikeMvpCountdown();
}

function renderLiveLikes(payload) {
  if (!payload || !liveLikesTotal) return;
  const t = Number(payload.total);
  liveLikesTotal.textContent = Number.isFinite(t) ? String(Math.max(0, Math.floor(t))) : "0";
  if (!liveLikesTopList) return;
  const top = (Array.isArray(payload.top) ? payload.top : []).slice(0, 3);
  if (!top.length) {
    liveLikesTopList.innerHTML = "";
    return;
  }
  liveLikesTopList.innerHTML = top
    .map((row) => {
      const likes = Math.max(0, Math.floor(Number(row.likes) || 0));
      const nb = nameBadgePrefixHtml(row.name_badge);
      const nm = escapeHtml(String(row.name != null ? row.name : "?"));
      const lt = Math.max(0, Math.floor(Number(row.like_cosmetic_tier) || 0));
      const tcls = likeCosmeticTierClasses(lt).trim();
      const lh = likeCosmeticHueInlineStyle(lt);
      return `<li><span class="brand-like-mvp-icon" title="MVP liker" aria-hidden="true">\u{1F3C6}</span><span class="brand-like-top-name${tcls ? ` ${tcls}` : ""}"${lh}>${nb}${nm}</span><span class="brand-like-top-n">${likes}</span></li>`;
    })
    .join("");
}

/** Safe inline colour from server (#rgb / #rrggbb only). */
function nameColorStyleAttr(hex) {
  const s = sanitizeNameColorHex(hex);
  if (!s) return "";
  return ` style="color:${s}"`;
}

function avatarUrl(userKey) {
  return `/api/player-avatar?key=${encodeURIComponent(userKey)}`;
}

function faceBlock(name, userKey, nameBadge, likeCosmeticTier) {
  const wrap = document.createElement("div");
  wrap.className = "round-popup-face";
  const img = document.createElement("img");
  img.className = "round-popup-avatar";
  img.alt = "";
  img.width = 72;
  img.height = 72;
  img.loading = "lazy";
  img.decoding = "async";
  img.referrerPolicy = "no-referrer";
  img.src = avatarUrl(userKey);
  const cap = document.createElement("span");
  const lt = Math.max(0, Math.floor(Number(likeCosmeticTier) || 0));
  cap.className = `round-popup-name${likeCosmeticTierClasses(lt)}`.replace(/\s+/g, " ").trim();
  if (lt > 10) {
    cap.style.setProperty("--like-cosmetic-hue", String((lt * 53) % 360));
  }
  const em = nameBadgeEmoji(nameBadge);
  if (em) {
    const badge = document.createElement("span");
    badge.className = "user-name-badge";
    badge.setAttribute("aria-hidden", "true");
    badge.textContent = `${em}\u00A0`;
    cap.appendChild(badge);
  }
  cap.appendChild(document.createTextNode(name != null ? String(name) : ""));
  wrap.appendChild(img);
  wrap.appendChild(cap);
  return wrap;
}

function hideWagerIntroPopup() {
  if (wagerIntroTimer) {
    clearTimeout(wagerIntroTimer);
    wagerIntroTimer = null;
  }
  if (!wagerIntroPopup) return;
  wagerIntroPopup.classList.add("hidden");
  wagerIntroPopup.setAttribute("aria-hidden", "true");
}

function showWagerIntroPopup(pop) {
  if (!wagerIntroPopup || !wagerIntroVsRow || !pop) return;
  hideWagerIntroPopup();
  const a = pop.a || {};
  const b = pop.b || {};
  const amt = Number(pop.amount) || 0;
  const preA = nameBadgePrefixHtml(a.name_badge);
  const preB = nameBadgePrefixHtml(b.name_badge);
  const ca = likeCosmeticTierClasses(a.like_cosmetic_tier).trim();
  const cb = likeCosmeticTierClasses(b.like_cosmetic_tier).trim();
  const sa = likeCosmeticHueInlineStyle(a.like_cosmetic_tier);
  const sb = likeCosmeticHueInlineStyle(b.like_cosmetic_tier);
  wagerIntroVsRow.innerHTML = `
    <div class="wager-pill">
      <img src="${avatarUrl(String(a.user_key || ""))}" alt="" width="88" height="88" decoding="async" referrerpolicy="no-referrer" />
      <span class="${ca ? `${ca} ` : ""}wager-pill-name"${sa}>${preA}${escapeHtml(String(a.name || ""))}</span>
    </div>
    <span class="wager-vs-badge">VS</span>
    <div class="wager-pill">
      <img src="${avatarUrl(String(b.user_key || ""))}" alt="" width="88" height="88" decoding="async" referrerpolicy="no-referrer" />
      <span class="${cb ? `${cb} ` : ""}wager-pill-name"${sb}>${preB}${escapeHtml(String(b.name || ""))}</span>
    </div>`;
  if (wagerIntroStake) wagerIntroStake.textContent = `${amt} all-time pts at stake`;
  syncPopupWordRowAnchor();
  wagerIntroPopup.classList.remove("hidden");
  wagerIntroPopup.setAttribute("aria-hidden", "false");
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 4500, 2000), 9000);
  wagerIntroTimer = setTimeout(hideWagerIntroPopup, ms);
}

function hideWagerResultPopup() {
  if (wagerResultTimer) {
    clearTimeout(wagerResultTimer);
    wagerResultTimer = null;
  }
  if (!wagerResultPopup) return;
  wagerResultPopup.classList.add("hidden");
  wagerResultPopup.setAttribute("aria-hidden", "true");
  if (wagerResultCard) wagerResultCard.innerHTML = "";
}

function showWagerResultPopup(pop) {
  if (!wagerResultPopup || !wagerResultCard) return;
  const ws = pop.wager_settlement;
  if (!ws || !ws.winner_key || !ws.loser_key) return;
  hideWagerResultPopup();
  const ok = pop.wager_alltime_settled === true;
  const amt = Number(ws.amount) || 0;
  const paidRaw = Number(ws.settled_amount);
  const paid = Number.isFinite(paidRaw) ? Math.max(0, Math.floor(paidRaw)) : amt;
  const wk = String(ws.winner_key);
  const lk = String(ws.loser_key);
  let meta;
  if (ok) {
    meta =
      amt > 0 && paid < amt
        ? `+${paid} all-time pts (winner) · −${paid} (loser) — partial (${amt} wagered; loser's balance was lower).`
        : `+${paid} all-time pts (winner) · −${paid} (loser)`;
  } else {
    meta = ws.settlement_error
      ? String(ws.settlement_error)
      : "All-time transfer failed — scores unchanged.";
  }
  const lwc = likeCosmeticTierClasses(ws.loser_like_cosmetic_tier).trim();
  const wwc = likeCosmeticTierClasses(ws.winner_like_cosmetic_tier).trim();
  const lws = likeCosmeticHueInlineStyle(ws.loser_like_cosmetic_tier);
  const wws = likeCosmeticHueInlineStyle(ws.winner_like_cosmetic_tier);
  wagerResultCard.innerHTML = `
    <div class="wager-result-layout">
      <div class="wager-result-row wager-result-row--duel">
        <div class="wager-result-lose">
          <img src="${avatarUrl(lk)}" alt="" width="96" height="96" decoding="async" referrerpolicy="no-referrer" />
          <span class="wager-lose-name${lwc ? ` ${lwc}` : ""}"${lws}>${nameBadgePrefixHtml(ws.loser_name_badge)}${escapeHtml(
            String(ws.loser_name || "")
          )}</span>
        </div>
        <div class="wager-result-win-split">
          <p class="wager-win-title">Winner!</p>
          <img class="wager-win-avatar" src="${avatarUrl(wk)}" alt="" width="120" height="120" decoding="async" referrerpolicy="no-referrer" />
          <span class="wager-win-name${wwc ? ` ${wwc}` : ""}"${wws}>${nameBadgePrefixHtml(ws.winner_name_badge)}${escapeHtml(
            String(ws.winner_name || "")
          )}</span>
        </div>
      </div>
      <p class="wager-result-meta">${escapeHtml(meta)}</p>
    </div>`;
  syncPopupWordRowAnchor();
  wagerResultPopup.classList.remove("hidden");
  wagerResultPopup.setAttribute("aria-hidden", "false");
  const ms = 6500;
  wagerResultTimer = setTimeout(hideWagerResultPopup, ms);
}

function showWagerDrawToast() {
  const el = document.createElement("div");
  el.className = "wager-draw-toast";
  el.textContent = "Wager drawn — no all-time points change.";
  document.body.appendChild(el);
  syncPopupWordRowAnchor();
  setTimeout(() => el.remove(), 5200);
}

function hideRoundPopup() {
  if (roundPopupTimer) {
    clearTimeout(roundPopupTimer);
    roundPopupTimer = null;
  }
  if (!roundPopup) return;
  roundPopup.classList.add("hidden");
  roundPopup.setAttribute("aria-hidden", "true");
}

function showRoundPopup(pop) {
  if (!roundPopup || !pop) return;
  if (pop.wager_draw) {
    showWagerDrawToast();
    return;
  }
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 4500, 3000), 8000);
  const ws = pop.wager_settlement;
  const hasWager = !!(ws && ws.winner_key);

  const titleEl = document.getElementById("roundPopupTitle");
  const subEl = document.getElementById("roundPopupSub");
  const sealedLabelEl = document.querySelector("#roundPopupSealedSection .round-popup-label");

  if (titleEl) titleEl.textContent = pop.whole_word_solve ? "Whole phrase!" : "Word solved";
  if (sealedLabelEl) sealedLabelEl.textContent = pop.whole_word_solve ? "Solved by" : "Last letter";
  if (subEl) {
    if (pop.whole_word_solve && pop.whole_word_points != null) {
      subEl.hidden = false;
      subEl.textContent = `+${pop.whole_word_points} pts · ${pop.hidden_pct_before}% of letter slots were still hidden`;
    } else {
      subEl.hidden = true;
      subEl.textContent = "";
    }
  }

  roundPopupWord.textContent = pop.display_word || pop.word || "";

  roundPopupMvps.innerHTML = "";
  const mvps = pop.mvps || [];
  if (mvps.length) {
    roundPopupMvpSection.classList.remove("hidden");
    mvps.forEach((m) => {
      roundPopupMvps.appendChild(faceBlock(m.name, m.user_key, m.name_badge, m.like_cosmetic_tier));
    });
  } else {
    roundPopupMvpSection.classList.add("hidden");
  }

  const sealed = pop.sealed_by;
  roundPopupSealed.innerHTML = "";
  if (sealed && sealed.user_key) {
    const soleMvp =
      mvps.length === 1 && mvps[0].user_key === sealed.user_key;
    if (soleMvp) {
      roundPopupSealedSection.classList.add("hidden");
    } else {
      roundPopupSealedSection.classList.remove("hidden");
      roundPopupSealed.appendChild(
        faceBlock(sealed.name, sealed.user_key, sealed.name_badge, sealed.like_cosmetic_tier)
      );
    }
  } else {
    roundPopupSealedSection.classList.add("hidden");
  }

  syncPopupWordRowAnchor();
  roundPopup.classList.remove("hidden");
  roundPopup.setAttribute("aria-hidden", "false");

  if (pop.win_sound) playWinSound(pop.win_sound);

  if (roundPopupTimer) clearTimeout(roundPopupTimer);
  if (hasWager) {
    const msShort = Math.min(ms, 2800);
    roundPopupTimer = setTimeout(() => {
      hideRoundPopup();
      showWagerResultPopup(pop);
    }, msShort);
  } else {
    roundPopupTimer = setTimeout(hideRoundPopup, ms);
  }

  if (!hasWager) triggerOhanaWinJump(pop);
}

function hideHintPopup() {
  if (hintPopupTimer) {
    clearTimeout(hintPopupTimer);
    hintPopupTimer = null;
  }
  if (!hintPopup) return;
  hintPopup.classList.add("hidden");
  hintPopup.setAttribute("aria-hidden", "true");
}

function showHintPopup(pop) {
  if (!hintPopup || !hintPopupText || !pop || !pop.hint) return;
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 7500, 4000), 12000);
  if (hintPopupFrom) {
    const from = pop.from_name ? String(pop.from_name).trim() : "";
    if (from) {
      hintPopupFrom.hidden = false;
      hintPopupFrom.textContent = `From ${textWithNameBadge(from, pop.from_name_badge)}`;
    } else {
      hintPopupFrom.hidden = true;
      hintPopupFrom.textContent = "";
    }
  }
  hintPopupText.textContent = pop.hint;
  syncPopupWordRowAnchor();
  hintPopup.classList.remove("hidden");
  hintPopup.setAttribute("aria-hidden", "false");
  if (hintPopupTimer) clearTimeout(hintPopupTimer);
  hintPopupTimer = setTimeout(hideHintPopup, ms);
}

function hidePointsPopup() {
  if (pointsPopupTimer) {
    clearTimeout(pointsPopupTimer);
    pointsPopupTimer = null;
  }
  if (!pointsPopup) return;
  pointsPopup.classList.add("hidden");
  pointsPopup.setAttribute("aria-hidden", "true");
}

function hideCommandListPopup() {
  if (commandListPopupTimer) {
    clearTimeout(commandListPopupTimer);
    commandListPopupTimer = null;
  }
  if (!commandListPopup) return;
  commandListPopup.classList.add("hidden");
  commandListPopup.setAttribute("aria-hidden", "true");
}

function _hangmanHelpOnEsc(e) {
  if (e.key === "Escape") hideHangmanHelpPopup();
}

function hideHangmanHelpPopup() {
  if (hangmanHelpPopupTimer) {
    clearTimeout(hangmanHelpPopupTimer);
    hangmanHelpPopupTimer = null;
  }
  if (!hangmanHelpPopup) return;
  hangmanHelpPopup.classList.add("hidden");
  hangmanHelpPopup.setAttribute("aria-hidden", "true");
  if (hangmanHelpBody) hangmanHelpBody.innerHTML = "";
  document.removeEventListener("keydown", _hangmanHelpOnEsc);
}

function showHangmanHelpPopup(pop) {
  if (!hangmanHelpPopup || !hangmanHelpBody) return;
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 90000, 30000), 180000);
  hangmanHelpBody.innerHTML = "";
  const paras = Array.isArray(pop.paragraphs) ? pop.paragraphs : [];
  paras.forEach((t) => {
    const p = document.createElement("p");
    p.textContent = t != null ? String(t) : "";
    hangmanHelpBody.appendChild(p);
  });
  if (hangmanHelpFrom) {
    const from = pop.from_name != null ? String(pop.from_name).trim() : "";
    if (from) {
      hangmanHelpFrom.hidden = false;
      hangmanHelpFrom.textContent = `Requested by ${textWithNameBadge(from, pop.from_name_badge)}`;
    } else {
      hangmanHelpFrom.hidden = true;
      hangmanHelpFrom.textContent = "";
    }
  }
  hangmanHelpPopup.classList.remove("hidden");
  hangmanHelpPopup.setAttribute("aria-hidden", "false");
  document.addEventListener("keydown", _hangmanHelpOnEsc);
  if (hangmanHelpPopupTimer) clearTimeout(hangmanHelpPopupTimer);
  hangmanHelpPopupTimer = setTimeout(hideHangmanHelpPopup, ms);
}

(function setupHangmanHelpPopupUi() {
  if (hangmanHelpBackdrop) hangmanHelpBackdrop.addEventListener("click", hideHangmanHelpPopup);
  if (hangmanHelpClose) hangmanHelpClose.addEventListener("click", hideHangmanHelpPopup);
})();

function playWinSound(ws) {
  if (!ws || !ws.url) return;
  try {
    const a = new Audio(String(ws.url));
    a.volume = 0.72;
    a.play().catch(() => {});
  } catch (_) {
    /* ignore */
  }
}

function showCommandListPopup(pop) {
  if (!commandListPopup || !pop || !commandListTitle || !commandListUl) return;
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 14000, 6000), 120000);
  commandListTitle.textContent = pop.title != null ? String(pop.title).trim() : "Commands";
  if (commandListSub) {
    const sub = pop.subtitle != null ? String(pop.subtitle).trim() : "";
    commandListSub.textContent = sub;
    commandListSub.hidden = !sub;
  }
  commandListUl.innerHTML = "";
  const lines = Array.isArray(pop.lines) ? pop.lines : [];
  lines.forEach((line) => {
    const li = document.createElement("li");
    li.textContent = line != null ? String(line) : "";
    commandListUl.appendChild(li);
  });
  syncPopupWordRowAnchor();
  commandListPopup.classList.remove("hidden");
  commandListPopup.setAttribute("aria-hidden", "false");
  if (commandListPopupTimer) clearTimeout(commandListPopupTimer);
  commandListPopupTimer = setTimeout(hideCommandListPopup, ms);
}

function showPointsPopup(pop) {
  if (!pointsPopup || !pop || !pointsPopupName || !pointsPopupScore) return;
  const rawMs = Number(pop.duration_ms);
  const ms =
    Number.isFinite(rawMs) && rawMs > 0
      ? Math.min(Math.max(rawMs, 800), 30000)
      : 1800;
  const titleEl = document.getElementById("pointsPopupTitle");
  if (titleEl) {
    const k = pop.kicker != null ? String(pop.kicker).trim() : "";
    titleEl.textContent = k || "All-time";
  }
  const name = textWithNameBadge(
    pop.name != null ? String(pop.name).trim() : "Player",
    pop.name_badge
  );
  const score = Number(pop.score);
  pointsPopupName.textContent = name;
  pointsPopupScore.textContent = Number.isFinite(score) ? String(Math.trunc(score)) : "0";
  if (pointsPopupAvatar && pop.user_key) {
    pointsPopupAvatar.hidden = false;
    pointsPopupAvatar.src = avatarUrl(String(pop.user_key));
  } else if (pointsPopupAvatar) {
    pointsPopupAvatar.hidden = true;
    pointsPopupAvatar.removeAttribute("src");
  }
  syncPopupWordRowAnchor();
  pointsPopup.classList.remove("hidden");
  pointsPopup.setAttribute("aria-hidden", "false");
  if (pointsPopupTimer) clearTimeout(pointsPopupTimer);
  pointsPopupTimer = setTimeout(hidePointsPopup, ms);
}

function hideGalaxyStealPopup() {
  if (galaxyStealPopupTimer) {
    clearTimeout(galaxyStealPopupTimer);
    galaxyStealPopupTimer = null;
  }
  if (!galaxyStealPopup) return;
  galaxyStealPopup.classList.add("hidden");
  galaxyStealPopup.setAttribute("aria-hidden", "true");
}

function showGalaxyStealPopup(pop) {
  if (
    !galaxyStealPopup ||
    !pop ||
    !galaxyStealThiefName ||
    !galaxyStealStoleLine ||
    !galaxyStealVictimName
  )
    return;
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 8500, 5000), 12000);
  const pts = Number(pop.points);
  const ptsStr = Number.isFinite(pts) ? String(Math.trunc(pts)) : "0";
  const thief = textWithNameBadge(
    pop.from_name != null ? String(pop.from_name).trim() : "Player",
    pop.from_name_badge
  );
  const victim = textWithNameBadge(
    pop.victim_name != null ? String(pop.victim_name).trim() : "Player",
    pop.victim_name_badge
  );

  galaxyStealThiefName.textContent = thief;
  galaxyStealVictimName.textContent = victim;
  galaxyStealStoleLine.textContent = `Stole ${ptsStr} all-time points`;

  if (galaxyStealThiefAvatar && pop.from_user_key) {
    galaxyStealThiefAvatar.hidden = false;
    galaxyStealThiefAvatar.src = avatarUrl(String(pop.from_user_key));
  } else if (galaxyStealThiefAvatar) {
    galaxyStealThiefAvatar.hidden = true;
    galaxyStealThiefAvatar.removeAttribute("src");
  }

  if (galaxyStealVictimAvatar && pop.victim_user_key) {
    galaxyStealVictimAvatar.hidden = false;
    galaxyStealVictimAvatar.src = avatarUrl(String(pop.victim_user_key));
  } else if (galaxyStealVictimAvatar) {
    galaxyStealVictimAvatar.hidden = true;
    galaxyStealVictimAvatar.removeAttribute("src");
  }

  syncPopupWordRowAnchor();
  galaxyStealPopup.classList.remove("hidden");
  galaxyStealPopup.setAttribute("aria-hidden", "false");
  if (galaxyStealPopupTimer) clearTimeout(galaxyStealPopupTimer);
  galaxyStealPopupTimer = setTimeout(hideGalaxyStealPopup, ms);
}

function hideCapSidelinePopup() {
  if (capSidelinePopupTimer) {
    clearTimeout(capSidelinePopupTimer);
    capSidelinePopupTimer = null;
  }
  if (!capSidelinePopup) return;
  capSidelinePopup.classList.add("hidden");
  capSidelinePopup.setAttribute("aria-hidden", "true");
}

function hideShieldTrimPopup() {
  if (shieldTrimPopupTimer) {
    clearTimeout(shieldTrimPopupTimer);
    shieldTrimPopupTimer = null;
  }
  if (!shieldTrimPopup) return;
  shieldTrimPopup.classList.add("hidden");
  shieldTrimPopup.setAttribute("aria-hidden", "true");
}

function showShieldTrimPopup(pop) {
  if (
    !shieldTrimPopup ||
    !pop ||
    !shieldTrimSenderName ||
    !shieldTrimVictimName ||
    !shieldTrimDetail
  )
    return;
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 8500, 5000), 12000);
  const sender = textWithNameBadge(
    pop.from_name != null ? String(pop.from_name).trim() : "Player",
    pop.from_name_badge
  );
  const victim = textWithNameBadge(
    pop.victim_name != null ? String(pop.victim_name).trim() : "Player",
    pop.victim_name_badge
  );
  const detail =
    pop.detail != null && String(pop.detail).trim()
      ? String(pop.detail).trim()
      : "Racing Debut shield updated.";

  shieldTrimSenderName.textContent = sender;
  shieldTrimVictimName.textContent = victim;
  shieldTrimDetail.textContent = detail;

  if (shieldTrimSenderAvatar && pop.from_user_key) {
    shieldTrimSenderAvatar.hidden = false;
    shieldTrimSenderAvatar.src = avatarUrl(String(pop.from_user_key));
  } else if (shieldTrimSenderAvatar) {
    shieldTrimSenderAvatar.hidden = true;
    shieldTrimSenderAvatar.removeAttribute("src");
  }

  if (shieldTrimVictimAvatar && pop.victim_user_key) {
    shieldTrimVictimAvatar.hidden = false;
    shieldTrimVictimAvatar.src = avatarUrl(String(pop.victim_user_key));
  } else if (shieldTrimVictimAvatar) {
    shieldTrimVictimAvatar.hidden = true;
    shieldTrimVictimAvatar.removeAttribute("src");
  }

  syncPopupWordRowAnchor();
  shieldTrimPopup.classList.remove("hidden");
  shieldTrimPopup.setAttribute("aria-hidden", "false");
  if (shieldTrimPopupTimer) clearTimeout(shieldTrimPopupTimer);
  shieldTrimPopupTimer = setTimeout(hideShieldTrimPopup, ms);
}

function showCapSidelinePopup(pop) {
  if (
    !capSidelinePopup ||
    !pop ||
    !capSidelineSenderName ||
    !capSidelineHeroLine ||
    !capSidelineVictimName
  )
    return;
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 8500, 5000), 12000);
  const sender = textWithNameBadge(
    pop.from_name != null ? String(pop.from_name).trim() : "Player",
    pop.from_name_badge
  );
  const victim = textWithNameBadge(
    pop.victim_name != null ? String(pop.victim_name).trim() : "Player",
    pop.victim_name_badge
  );

  capSidelineSenderName.textContent = sender;
  capSidelineVictimName.textContent = victim;
  capSidelineHeroLine.textContent =
    "Hangman will ignore this player for the next round only — they can still play this word.";

  if (capSidelineSenderAvatar && pop.from_user_key) {
    capSidelineSenderAvatar.hidden = false;
    capSidelineSenderAvatar.src = avatarUrl(String(pop.from_user_key));
  } else if (capSidelineSenderAvatar) {
    capSidelineSenderAvatar.hidden = true;
    capSidelineSenderAvatar.removeAttribute("src");
  }

  if (capSidelineVictimAvatar && pop.victim_user_key) {
    capSidelineVictimAvatar.hidden = false;
    capSidelineVictimAvatar.src = avatarUrl(String(pop.victim_user_key));
  } else if (capSidelineVictimAvatar) {
    capSidelineVictimAvatar.hidden = true;
    capSidelineVictimAvatar.removeAttribute("src");
  }

  syncPopupWordRowAnchor();
  capSidelinePopup.classList.remove("hidden");
  capSidelinePopup.setAttribute("aria-hidden", "false");
  if (capSidelinePopupTimer) clearTimeout(capSidelinePopupTimer);
  capSidelinePopupTimer = setTimeout(hideCapSidelinePopup, ms);
}

function hideFanGatePopup() {
  if (fanGatePopupTimer) {
    clearTimeout(fanGatePopupTimer);
    fanGatePopupTimer = null;
  }
  if (!fanGatePopup) return;
  fanGatePopup.classList.add("hidden");
  fanGatePopup.setAttribute("aria-hidden", "true");
}

function showFanGatePopup(pop) {
  if (!fanGatePopup || !pop || !fanGateName || !fanGateMsg) return;
  const ms = Math.min(Math.max(Number(pop.duration_ms) || 7000, 4000), 12000);
  const name = textWithNameBadge(
    pop.name != null ? String(pop.name).trim() : "Viewer",
    pop.name_badge
  );
  fanGateName.textContent = name;
  fanGateMsg.textContent =
    pop.message ||
    "Send a Heart Me and join the fan club on this LIVE to play Hangman.";
  if (fanGateAvatar && pop.user_key) {
    fanGateAvatar.hidden = false;
    fanGateAvatar.src = avatarUrl(String(pop.user_key));
  } else if (fanGateAvatar) {
    fanGateAvatar.hidden = true;
    fanGateAvatar.removeAttribute("src");
  }
  fanGatePopup.classList.remove("hidden");
  fanGatePopup.setAttribute("aria-hidden", "false");
  if (fanGatePopupTimer) clearTimeout(fanGatePopupTimer);
  fanGatePopupTimer = setTimeout(hideFanGatePopup, ms);
}

function renderLogs(_lines) {}

function connectWs() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  const ws = new WebSocket(`${proto}//${location.host}/ws`);
  gameWs = ws;

  ws.onopen = () => setStatus("page ready");

  ws.onmessage = (ev) => {
    let data;
    try {
      data = JSON.parse(ev.data);
    } catch {
      return;
    }
    if (data.type === "error") {
      alert(data.detail || "Request failed.");
      if (fanOnlyToggle) fanOnlyToggle.checked = !fanOnlyToggle.checked;
      return;
    }
    if (data.type === "update") {
      if (data.tiktok) {
        monitor.textContent = `Watching @${data.tiktok}`;
        const av = document.getElementById("streamerAvatar");
        if (av) av.src = `/api/streamer-avatar?v=${encodeURIComponent(data.tiktok)}`;
        if (tiktokLiveUserInput && !tiktokUsernameInputPrefilled) {
          tiktokLiveUserInput.value = data.tiktok;
          tiktokUsernameInputPrefilled = true;
        }
      }
      if (data.live_likes) renderLiveLikes(data.live_likes);
      if (data.like_mvp_banner) renderLikeMvpBanner(data.like_mvp_banner);
      if ("lion_nuke" in data) renderLionNukeBanner(data.lion_nuke);
      if (data.tiktok_status) setStatus(data.tiktok_status);
      if (data.state) renderState(data.state);
      if (data.alltime) renderAlltime(data.alltime);
      if (data.shield_grace_windows !== undefined) {
        shieldGraceWindows = Array.isArray(data.shield_grace_windows)
          ? data.shield_grace_windows
          : [];
        renderShieldGraceBanner();
      }
      if (data.logs) renderLogs(data.logs);
      if (data.round_popup) showRoundPopup(data.round_popup);
      if (data.wager_intro_popup) showWagerIntroPopup(data.wager_intro_popup);
      if (data.hint_popup) showHintPopup(data.hint_popup);
      if (data.points_popup) showPointsPopup(data.points_popup);
      if (data.command_list_popup) showCommandListPopup(data.command_list_popup);
      if (data.hangman_help_popup) showHangmanHelpPopup(data.hangman_help_popup);
      if (data.galaxy_popup) showGalaxyStealPopup(data.galaxy_popup);
      if (data.cap_popup) showCapSidelinePopup(data.cap_popup);
      if (data.shield_trim_popup) showShieldTrimPopup(data.shield_trim_popup);
      if (data.fan_gate_popup) showFanGatePopup(data.fan_gate_popup);
      if (data.fan_only_mode !== undefined && fanOnlyToggle) {
        fanOnlyToggle.checked = !!data.fan_only_mode;
      }
    }
    if (data.type === "pong") return;
  };

  ws.onclose = () => {
    gameWs = null;
    setStatus("reconnecting…");
    setTimeout(connectWs, 2000);
  };

  ws.onerror = () => ws.close();

  setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: "ping" }));
  }, 25000);

  setInterval(() => {
    if (shieldGraceWindows.length) renderShieldGraceBanner();
    tickLikeMvpCountdown();
    tickLionNukeCountdown();
  }, 1000);
}

(function initRoundPopup() {
  const backdrop = roundPopup?.querySelector(".round-popup-backdrop");
  if (backdrop) backdrop.addEventListener("click", hideRoundPopup);
  const hintBackdrop = hintPopup?.querySelector(".hint-popup-backdrop");
  if (hintBackdrop) hintBackdrop.addEventListener("click", hideHintPopup);
  const pointsBackdrop = pointsPopup?.querySelector(".points-popup-backdrop");
  if (pointsBackdrop) pointsBackdrop.addEventListener("click", hidePointsPopup);
  const commandListBackdrop = commandListPopup?.querySelector(".command-list-backdrop");
  if (commandListBackdrop) commandListBackdrop.addEventListener("click", hideCommandListPopup);
  const galaxyBackdrop = galaxyStealPopup?.querySelector(".galaxy-steal-backdrop");
  if (galaxyBackdrop) galaxyBackdrop.addEventListener("click", hideGalaxyStealPopup);
  const capBackdrop = capSidelinePopup?.querySelector(".cap-sideline-backdrop");
  if (capBackdrop) capBackdrop.addEventListener("click", hideCapSidelinePopup);
  const shieldTrimBackdrop = shieldTrimPopup?.querySelector(".shield-trim-backdrop");
  if (shieldTrimBackdrop) shieldTrimBackdrop.addEventListener("click", hideShieldTrimPopup);
  const wagerIntroBackdrop = wagerIntroPopup?.querySelector(".wager-match-backdrop");
  if (wagerIntroBackdrop) wagerIntroBackdrop.addEventListener("click", hideWagerIntroPopup);
  const wagerResultBackdrop = wagerResultPopup?.querySelector(".wager-match-backdrop");
  if (wagerResultBackdrop) wagerResultBackdrop.addEventListener("click", hideWagerResultPopup);
  const fanGateCard = fanGatePopup?.querySelector(".fan-gate-card");
  if (fanGateCard) {
    fanGateCard.addEventListener("click", hideFanGatePopup);
    fanGateCard.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        hideFanGatePopup();
      }
    });
  }
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      hideRoundPopup();
      hideHintPopup();
      hidePointsPopup();
      hideGalaxyStealPopup();
      hideCapSidelinePopup();
      hideFanGatePopup();
      hideCommandListPopup();
      hideShieldTrimPopup();
      hideWagerIntroPopup();
      hideWagerResultPopup();
    }
  });
})();

(function initFanOnlyToggle() {
  if (!fanOnlyToggle) return;
  fanOnlyToggle.addEventListener("change", () => {
    const want = fanOnlyToggle.checked;
    let key = sessionStorage.getItem("hangmanHostKey") || "";
    if (!gameWs || gameWs.readyState !== WebSocket.OPEN) {
      fanOnlyToggle.checked = !want;
      return;
    }
    gameWs.send(JSON.stringify({ type: "set_fan_only", value: want, host_key: key }));
  });
})();

(function initTiktokLiveConnect() {
  if (!tiktokLiveUserInput || !tiktokLiveConnectBtn) return;

  async function postTiktokConnect(key, body) {
    const headers = { "Content-Type": "application/json" };
    if (key) headers["X-Host-Key"] = key;
    return fetch("/api/host/tiktok-connect", { method: "POST", headers, body: JSON.stringify(body) });
  }

  async function onConnect() {
    const raw = (tiktokLiveUserInput.value || "").trim().replace(/^@+/, "");
    if (!raw) {
      alert("Enter a TikTok @username to connect to.");
      return;
    }
    tiktokLiveConnectBtn.disabled = true;
    let stored = sessionStorage.getItem("hangmanHostKey") || "";
    try {
      let res = await postTiktokConnect(stored, { username: raw });
      if (res.status === 403) {
        const k = prompt(
          "If you set HANGMAN_HOST_KEY on the server, enter it here. Otherwise use http://127.0.0.1 on the PC running the game, or Cancel."
        );
        if (k === null) return;
        sessionStorage.setItem("hangmanHostKey", k);
        stored = k;
        res = await postTiktokConnect(stored, { username: raw });
      }
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        const msg =
          typeof err.detail === "string"
            ? err.detail
            : Array.isArray(err.detail)
              ? err.detail.map((d) => d.msg || d).join(" ")
              : await res.text();
        alert(msg || "Could not connect");
        return;
      }
      const okBody = await res.json().catch(() => ({}));
      if (okBody.tiktok && tiktokLiveUserInput) tiktokLiveUserInput.value = okBody.tiktok;
    } finally {
      tiktokLiveConnectBtn.disabled = false;
    }
  }

  tiktokLiveConnectBtn.addEventListener("click", onConnect);
  tiktokLiveUserInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") onConnect();
  });
})();

(function initResetSession() {
  const btn = document.getElementById("resetSessionBtn");
  if (!btn) return;

  async function postReset(key) {
    const headers = {};
    if (key) headers["X-Host-Key"] = key;
    return fetch("/api/host/reset-session", { method: "POST", headers });
  }

  btn.addEventListener("click", async () => {
    if (!confirm("Reset session scores to 0 for everyone? (All-time totals are not changed.)")) return;
    let stored = sessionStorage.getItem("hangmanHostKey") || "";
    btn.disabled = true;
    try {
      let res = await postReset(stored);
      if (res.status === 403) {
        const k = prompt(
          "If you set HANGMAN_HOST_KEY on the server, enter it here. Otherwise use http://127.0.0.1 on the PC running the game, or Cancel."
        );
        if (k === null) return;
        sessionStorage.setItem("hangmanHostKey", k);
        stored = k;
        res = await postReset(stored);
      }
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        const msg =
          typeof err.detail === "string"
            ? err.detail
            : Array.isArray(err.detail)
              ? err.detail.map((d) => d.msg || d).join(" ")
              : await res.text();
        alert(msg || "Reset failed");
        return;
      }
    } finally {
      btn.disabled = false;
    }
  });
})();

(function initWordSlotFitObserver() {
  if (!wordSlots || typeof ResizeObserver === "undefined") return;
  new ResizeObserver(() => {
    fitWordSlotsToWidth(lastWordLetterCount);
  }).observe(wordSlots);
  syncPopupWordRowAnchor();
})();

window.addEventListener("resize", () => {
  syncPopupWordRowAnchor();
});

window.addEventListener("load", () => {
  syncPopupWordRowAnchor();
});

(function verifyHangmanBuild() {
  fetch("/api/build-info")
    .then((r) => r.json())
    .then((info) => {
      console.info("[NFG Hangman] page URL:", window.location.href);
      console.info("[NFG Hangman] build-info:", info);
      if (info.index_contains_dobby) {
        console.error(
          "[NFG Hangman] This server’s index.html still mentions Dobby — wrong deploy or old copy."
        );
      }
    })
    .catch((e) => console.warn("[NFG Hangman] /api/build-info failed:", e));
})();

/** Desktop shell only (?desktop=1): scale the whole page so the window isn’t mostly empty margin. */
(function initDesktopZoom() {
  try {
    if (new URLSearchParams(location.search).get("desktop") !== "1") return;
  } catch (_) {
    return;
  }
  const STORAGE = "nfg_desktop_zoom_pct";
  const MIN = 0.5;
  const MAX = 2;
  const STEP = 0.1;
  let scale = 1;
  function apply() {
    scale = Math.min(MAX, Math.max(MIN, Math.round(scale * 100) / 100));
    const pct = Math.round(scale * 100);
    document.documentElement.style.zoom = `${pct}%`;
    try {
      sessionStorage.setItem(STORAGE, String(pct));
    } catch (_) {
      /* ignore */
    }
  }
  try {
    const raw = sessionStorage.getItem(STORAGE);
    if (raw != null && raw !== "") {
      const n = Number.parseInt(raw, 10);
      if (Number.isFinite(n) && n >= MIN * 100 && n <= MAX * 100) {
        scale = n / 100;
        apply();
      }
    }
  } catch (_) {
    /* ignore */
  }
  document.addEventListener(
    "keydown",
    (e) => {
      if (!e.ctrlKey && !e.metaKey) return;
      const k = e.key;
      if (k === "=" || k === "+") {
        e.preventDefault();
        scale += STEP;
        apply();
      } else if (k === "-" || k === "_") {
        e.preventDefault();
        scale -= STEP;
        apply();
      } else if (k === "0") {
        e.preventDefault();
        scale = 1;
        apply();
      }
    },
    true
  );
})();

connectWs();
void refreshHangmanSpotify();
setInterval(refreshHangmanSpotify, 4000);
