const TOKEN_KEY = "nfg_web_token";
const USER_KEY = "nfg_web_user";
const NAME_KEY = "nfg_web_name";
const DEVICE_KEY = "nfg_web_device";

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
  if (!res.ok) {
    const err = new Error((data && (data.message || data.error)) || `HTTP ${res.status}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

export function fmt(n) {
  return Math.floor(Number(n) || 0).toLocaleString();
}

export function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
