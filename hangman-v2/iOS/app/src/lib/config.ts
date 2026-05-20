const apiBase = (import.meta.env.VITE_NFG_API_BASE || "https://y666suf.com").replace(
  /\/$/,
  ""
);

const hangmanWsPath = import.meta.env.VITE_HANGMAN_WS_PATH || "/hangman/ws";
const platformWsPath = import.meta.env.VITE_PLATFORM_WS_PATH || "";

export const CLIENT_APP = "nfg-hangman";

export function apiUrl(path: string): string {
  return `${apiBase}${path.startsWith("/") ? path : `/${path}`}`;
}

export function hangmanWsUrl(): string {
  const base = apiBase.replace(/^http/, "ws");
  const path = hangmanWsPath.startsWith("/") ? hangmanWsPath : `/${hangmanWsPath}`;
  return `${base}${path}`;
}

/** Platform events: app_chat, presence_update (same host as API). */
export function platformWsUrl(): string {
  const base = apiBase.replace(/^http/, "ws");
  if (platformWsPath) {
    const path = platformWsPath.startsWith("/") ? platformWsPath : `/${platformWsPath}`;
    return `${base}${path}`;
  }
  return base;
}

export const LINK_COMMAND_HINT = "!link";
export const TIKTOK_HANDLE = "y666.suf";
