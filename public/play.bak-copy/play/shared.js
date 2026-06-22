const TOKEN_KEY = "nfg_web_token";
const USER_KEY = "nfg_web_user";
const NAME_KEY = "nfg_web_name";
const DEVICE_KEY = "nfg_web_device";

let unauthorizedHandler = null;

export function setUnauthorizedHandler(fn) {
  unauthorizedHandler = typeof fn === "function" ? fn : null;
}

export function getDeviceId() {
  let id = localStorage.getItem(DEVICE_KEY);
  if (!id) {
    id = `web-${crypto.randomUUID()}`;
    localStorage.setItem(DEVICE_KEY, id);
  }
  return id;
}

export function getSession() {
  return {
    token: localStorage.getItem(TOKEN_KEY) || "",
    userId: localStorage.getItem(USER_KEY) || "",
    displayName: localStorage.getItem(NAME_KEY) || "",
    deviceId: getDeviceId(),
  };
}

export function saveSession({ token, userId, displayName }) {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  if (userId) localStorage.setItem(USER_KEY, userId);
  if (displayName) localStorage.setItem(NAME_KEY, displayName);
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
  localStorage.removeItem(NAME_KEY);
}

export function isLoggedIn() {
  const s = getSession();
  return !!(s.token && s.userId);
}

export function wsURL() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${location.host}`;
}

export async function api(path, { method = "GET", body, auth = true } = {}) {
  const headers = {
    "Content-Type": "application/json",
    "X-Client-App": "nfg-crash-web",
    "X-Device-Id": getDeviceId(),
  };
  const session = getSession();
  if (auth && session.token) {
    headers.Authorization = `Bearer ${session.token}`;
  }
  const res = await fetch(path, {
    method,
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { ok: false, raw: text };
  }
  if (res.status === 401 && unauthorizedHandler) {
    unauthorizedHandler();
  }
  if (!res.ok) {
    const err = new Error((data && (data.message || data.error)) || `HTTP ${res.status}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  const ok = data == null || data.ok !== false;
  return { ok, data };
}

export function fmt(n) {
  return Math.floor(Number(n) || 0).toLocaleString();
}

export function fmtPts(n) {
  return `${fmt(n)} pts`;
}

export function fmtMult(m) {
  return `${Number(m || 1).toFixed(2)}×`;
}

export function parseBetAmount(raw) {
  const s = String(raw || "")
    .trim()
    .toLowerCase()
    .replace(/,/g, "");
  if (!s || s === "all") return s === "all" ? "all" : null;
  const m = s.match(/^(\d+(?:\.\d+)?)([kmb])?$/);
  if (!m) return null;
  let n = Number(m[1]);
  if (!Number.isFinite(n) || n <= 0) return null;
  const suffix = m[2];
  if (suffix === "k") n *= 1000;
  else if (suffix === "m") n *= 1_000_000;
  else if (suffix === "b") n *= 1_000_000_000;
  return Math.floor(n);
}

/** True on phones / touch-first devices — used to gate NFG Jump on desktop. */
export function isMobileGameDevice() {
  const ua = navigator.userAgent || "";
  const mobileUa = /iPhone|iPad|iPod|Android|Mobile/i.test(ua);
  const coarse = window.matchMedia("(hover: none) and (pointer: coarse)").matches;
  const narrow = window.matchMedia("(max-width: 520px)").matches;
  return coarse || (mobileUa && narrow);
}

export function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

export function showToast(msg) {
  const el = document.getElementById("toast");
  if (!el) return;
  el.textContent = String(msg || "");
  el.hidden = false;
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => {
    el.hidden = true;
  }, 2800);
}

const RANK_LABELS = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
const SUIT_SYM = { spades: "♠", hearts: "♥", diamonds: "♦", clubs: "♣" };

export function formatCard(rank, suit) {
  return `${RANK_LABELS[rank] || rank}${SUIT_SYM[suit] || suit}`;
}

export async function arcadePlay(gameId, action, payload = {}) {
  const { ok, data } = await api("/api/mobile/arcade/play", {
    method: "POST",
    body: { gameId, action, payload },
  });
  const res = data || {};
  if (!ok) {
    throw new Error(res.message || res.error || String(res.reason || "Arcade error").replace(/_/g, " "));
  }
  return res;
}

export async function fetchArcadeCatalog() {
  const { ok, data } = await api("/api/mobile/arcade/catalog");
  if (!ok) throw new Error(data?.message || "Could not load arcade");
  return data;
}

export async function claimArcadeMission(missionId) {
  const { ok, data } = await api("/api/mobile/arcade/mission/claim", {
    method: "POST",
    body: { missionId },
  });
  if (!ok) throw new Error(data?.message || "Could not claim mission");
  return data;
}

export async function fetchArcadeLeaderboard(gameId) {
  try {
    const { ok, data } = await api(`/api/mobile/arcade/leaderboard/${encodeURIComponent(gameId)}`);
    if (!ok) return null;
    return data;
  } catch {
    return null;
  }
}
