export const STORAGE_KEY = "nfg-crash-web-session-v1";
export const CLIENT_APP = "nfg-crash";

let session = loadSessionRaw();
let toastTimer = null;
let onUnauthorized = null;

function loadSessionRaw() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      const s = emptySession();
      localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
      return s;
    }
    const parsed = JSON.parse(raw);
    const next = {
      deviceId: String(parsed.deviceId || "").trim() || newDeviceIdOnly(),
      token: String(parsed.token || "").trim(),
      userId: String(parsed.userId || "").trim(),
      displayName: String(parsed.displayName || "").trim(),
    };
    if (!parsed.deviceId) localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    return next;
  } catch {
    const s = emptySession();
    localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
    return s;
  }
}

function newDeviceIdOnly() {
  return "web-" + crypto.randomUUID();
}

function emptySession() {
  return { deviceId: newDeviceIdOnly(), token: "", userId: "", displayName: "" };
}

export function getSession() {
  return session;
}

export function saveSession(next) {
  session = { ...session, ...next };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
}

export function clearSession() {
  const deviceId = session.deviceId || newDeviceIdOnly();
  session = { deviceId, token: "", userId: "", displayName: "" };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
}

export function isLoggedIn() {
  return !!(session.token && session.userId);
}

export function setUnauthorizedHandler(fn) {
  onUnauthorized = fn;
}

function authHeaders(json) {
  const h = {
    "X-Device-Id": session.deviceId,
    "X-Client-App": CLIENT_APP,
  };
  if (session.token) h.Authorization = "Bearer " + session.token;
  if (json) h["Content-Type"] = "application/json";
  return h;
}

export async function api(path, opts = {}) {
  const res = await fetch(path, {
    method: opts.method || "GET",
    headers: authHeaders(!!opts.body),
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }
  if (res.status === 401 && isLoggedIn()) {
    clearSession();
    if (onUnauthorized) onUnauthorized();
    throw new Error("Session expired — link TikTok again.");
  }
  return { ok: res.ok, status: res.status, data };
}

export async function arcadePlay(gameId, action, payload = {}) {
  const { ok, data } = await api("/api/mobile/arcade/play", {
    method: "POST",
    body: { gameId, action, payload },
  });
  if (!ok && data) throw new Error(data.message || data.reason || "Arcade play failed.");
  if (data?.ok === false) throw new Error(data.message || data.reason || "Arcade play failed.");
  return data;
}

export async function fetchArcadeCatalog() {
  const { ok, data } = await api("/api/mobile/arcade/catalog");
  if (!ok) throw new Error("Could not load Vault Arcade.");
  return data;
}

export async function claimArcadeMission(missionId) {
  const { ok, data } = await api("/api/mobile/arcade/mission/claim", {
    method: "POST",
    body: { missionId },
  });
  if (!ok) throw new Error(data?.message || "Could not claim mission.");
  return data;
}

export async function fetchArcadeLeaderboard(gameId, limit = 25) {
  const { ok, data } = await api(`/api/mobile/arcade/leaderboard?gameId=${encodeURIComponent(gameId)}&limit=${limit}`);
  if (!ok) return null;
  return data;
}

export function fmtMult(n) {
  return (Math.round(Number(n) * 100) / 100).toFixed(2) + "×";
}

export function fmtPts(n) {
  const v = Math.floor(Number(n) || 0);
  return v.toLocaleString() + " pts";
}

export function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function parseBetAmount(raw) {
  let s = String(raw || "")
    .trim()
    .replace(/,/g, "")
    .toLowerCase()
    .replace(/\s/g, "");
  if (!s) return null;
  const m = s.match(/^([0-9]+(?:\.[0-9]+)?)([kmb])?$/i);
  if (!m) return null;
  let n = Number(m[1]);
  const suf = (m[2] || "").toLowerCase();
  if (suf === "k") n *= 1000;
  else if (suf === "m") n *= 1000000;
  else if (suf === "b") n *= 1000000000;
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.floor(n);
}

export function showToast(msg, ms = 2800) {
  const el = document.getElementById("toast");
  if (!el) return;
  el.textContent = msg;
  el.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    el.hidden = true;
  }, ms);
}

export const HILO_RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
export const HILO_SUITS = { spades: "♠", hearts: "♥", diamonds: "♦", clubs: "♣" };

export function formatCard(rank, suit) {
  const r = HILO_RANKS[Math.max(0, Math.min(12, Number(rank) - 1))] || "?";
  const s = HILO_SUITS[String(suit || "").toLowerCase()] || "•";
  return `${r}${s}`;
}
