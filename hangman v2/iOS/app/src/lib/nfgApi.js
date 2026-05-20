const DEVICE_KEY = "nfg_device_id";
const TOKEN_KEY = "nfg_session_token";

export function apiBase() {
  const raw = String(import.meta.env.VITE_NFG_API_BASE || "").trim();
  if (raw) return raw.replace(/\/$/, "");
  if (typeof window !== "undefined" && window.location?.origin) {
    return window.location.origin;
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
  const res = await fetch(`${apiBase()}/api/mobile/platform/status`, {
    cache: "no-store",
    headers: { "X-Client-App": "nfg-hangman" },
  });
  return res.json();
}

export async function startLink() {
  const res = await fetch(`${apiBase()}/api/mobile/link/start`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ deviceId: getDeviceId() }),
  });
  return res.json();
}

export async function pollLinkStatus(code) {
  const res = await fetch(`${apiBase()}/api/mobile/link/status/${encodeURIComponent(code)}`, {
    cache: "no-store",
  });
  return res.json();
}

export async function fetchSession() {
  const res = await fetch(`${apiBase()}/api/mobile/session`, {
    headers: authHeaders(),
    cache: "no-store",
  });
  return res.json();
}

export async function sendPresenceHeartbeat() {
  const res = await fetch(`${apiBase()}/api/mobile/presence/heartbeat`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ deviceId: getDeviceId(), clientApp: "nfg-hangman" }),
  });
  return res.json();
}

export async function fetchChat(limit = 60) {
  const res = await fetch(`${apiBase()}/api/mobile/chat?limit=${limit}`, { cache: "no-store" });
  return res.json();
}

export async function postChat(message) {
  const res = await fetch(`${apiBase()}/api/mobile/chat`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ message }),
  });
  return res.json();
}

export async function guessLetter(letter) {
  const res = await fetch(`${apiBase()}/api/mobile/hangman/guess`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ letter }),
  });
  return res.json();
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
