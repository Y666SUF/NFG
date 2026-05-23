import { Capacitor, CapacitorHttp } from "@capacitor/core";

const DEVICE_KEY = "nfg_device_id";
const TOKEN_KEY = "nfg_session_token";

function parseResponseData(data) {
  if (data == null || data === "") return {};
  if (typeof data === "object") return data;
  try {
    return JSON.parse(String(data));
  } catch {
    return { ok: false, error: "invalid_json" };
  }
}

/** Native Capacitor WebView blocks cross-origin fetch (CORS); use native HTTP on device. */
async function apiRequest(url, { method = "GET", headers = {}, body } = {}) {
  const jsonBody =
    body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body);

  if (Capacitor.isNativePlatform()) {
    const nativeOpts = { url, method, headers };
    if (body !== undefined) {
      nativeOpts.data = typeof body === "string" ? JSON.parse(body) : body;
    }
    const res = await CapacitorHttp.request(nativeOpts);
    return {
      ok: res.status >= 200 && res.status < 300,
      status: res.status,
      data: parseResponseData(res.data),
    };
  }

  const res = await fetch(url, { method, headers, body: jsonBody });
  return { ok: res.ok, status: res.status, data: parseResponseData(await res.text()) };
}

export function apiBase() {
  const raw = String(import.meta.env.VITE_NFG_API_BASE || "").trim();
  if (raw) return raw.replace(/\/$/, "");
  if (typeof window !== "undefined" && window.location?.origin) {
    return window.location.origin.replace(/\/$/, "");
  }
  return "http://127.0.0.1:3847";
}

export function hangmanWsUrl() {
  const path = String(import.meta.env.VITE_HANGMAN_WS_PATH || "/hangman/ws").trim() || "/hangman/ws";
  const base = apiBase().replace(/^http/i, (m) => (m.toLowerCase() === "https" ? "wss" : "ws"));
  return `${base}${path.startsWith("/") ? path : `/${path}`}`;
}

export function getDeviceId() {
  try {
    let id = localStorage.getItem(DEVICE_KEY);
    if (!id) {
      id = `hm-${Math.random().toString(36).slice(2, 10)}${Date.now().toString(36)}`;
      localStorage.setItem(DEVICE_KEY, id);
    }
    return id;
  } catch {
    return `hm-guest-${Date.now()}`;
  }
}

export function getToken() {
  try {
    return localStorage.getItem(TOKEN_KEY) || "";
  } catch {
    return "";
  }
}

export function setToken(token) {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* ignore */
  }
}

function authHeaders(extra = {}) {
  const token = getToken();
  const headers = {
    "Content-Type": "application/json",
    "X-Device-Id": getDeviceId(),
    "X-Client-App": "nfg-hangman",
    ...extra,
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  return headers;
}

export async function fetchPlatformStatus() {
  const { data } = await apiRequest(`${apiBase()}/api/mobile/platform/status`, {
    headers: { "X-Client-App": "nfg-hangman" },
  });
  return data;
}

export async function startLink() {
  const { ok, status, data } = await apiRequest(`${apiBase()}/api/mobile/link/start`, {
    method: "POST",
    headers: authHeaders(),
    body: { deviceId: getDeviceId() },
  });
  if (!ok && data?.ok !== true) {
    return {
      ok: false,
      error: data?.error || data?.message || `Server error (${status})`,
    };
  }
  return { ok: data?.ok !== false, ...data };
}

export async function pollLinkStatus(code) {
  const { data } = await apiRequest(
    `${apiBase()}/api/mobile/link/status/${encodeURIComponent(code)}`,
    { headers: { "X-Client-App": "nfg-hangman" } }
  );
  return data;
}

export async function fetchSession() {
  const { data } = await apiRequest(`${apiBase()}/api/mobile/session`, {
    headers: authHeaders(),
  });
  return data;
}

export async function sendPresenceHeartbeat() {
  const { data } = await apiRequest(`${apiBase()}/api/mobile/presence/heartbeat`, {
    method: "POST",
    headers: authHeaders(),
    body: { deviceId: getDeviceId(), clientApp: "nfg-hangman" },
  });
  return data;
}

export async function fetchChat(limit = 60) {
  const { data } = await apiRequest(`${apiBase()}/api/mobile/chat?limit=${limit}`, {
    headers: { "X-Client-App": "nfg-hangman" },
  });
  return data;
}

export async function postChat(message) {
  const { ok, status, data } = await apiRequest(`${apiBase()}/api/mobile/chat`, {
    method: "POST",
    headers: authHeaders(),
    body: { message },
  });
  if (!ok && data?.ok !== true) {
    return { ok: false, error: data?.error || `HTTP ${status}` };
  }
  return data;
}

export async function fetchHangmanState() {
  const { ok, status, data } = await apiRequest(`${apiBase()}/api/mobile/hangman/state`, {
    headers: authHeaders(),
  });
  if (!data || typeof data !== "object") {
    return { ok: false, error: "bad_response", message: `Server error (${status})` };
  }
  if (!ok && data.ok !== true) {
    return {
      ok: false,
      error: data.error || "state_failed",
      message: data.message || `HTTP ${status}`,
    };
  }
  return data;
}

export async function guessLetter(letter) {
  const { ok, status, data } = await apiRequest(`${apiBase()}/api/mobile/hangman/guess`, {
    method: "POST",
    headers: authHeaders(),
    body: { letter: String(letter || "").toLowerCase() },
  });
  if (!data || typeof data !== "object") {
    return { ok: false, error: "bad_response", message: `Server error (${status})` };
  }
  if (!ok && data.ok !== true) {
    return {
      ok: false,
      error: data.error || "guess_failed",
      message: data.message || `HTTP ${status}`,
      lines: Array.isArray(data.lines) ? data.lines : [],
    };
  }
  return data;
}

export function connectPlatformSocket(handlers = {}) {
  const base = apiBase().replace(/^http/i, (m) => (m.toLowerCase() === "https" ? "wss" : "ws"));
  const ws = new WebSocket(`${base}`);
  ws.onopen = () => handlers.onOpen?.();
  ws.onclose = () => handlers.onClose?.();
  ws.onerror = () => handlers.onError?.();
  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.type === "app_chat" && msg.payload) handlers.onChat?.(msg.payload);
      if (msg.type === "presence_update" && msg.payload) handlers.onPresence?.(msg.payload);
    } catch {
      /* ignore */
    }
  };
  return ws;
}
