import { getSession, isLoggedIn } from "./shared.js";

const REFRESH_MS = 24 * 60 * 60 * 1000;
const CACHE_NAME = "nfg-tiktok-avatars-v1";
const TS_PREFIX = "nfg-avatar-ts:";

function authHeaders() {
  const session = getSession();
  return {
    Authorization: session.token ? `Bearer ${session.token}` : "",
    "X-Device-Id": session.deviceId,
    "X-Client-App": "nfg-crash",
  };
}

function cacheKey(userId) {
  return `/local/tiktok-avatar/${encodeURIComponent(userId)}`;
}

function lastFetchKey(userId) {
  return `${TS_PREFIX}${userId}`;
}

function needsRefresh(userId) {
  const ts = Number(localStorage.getItem(lastFetchKey(userId)) || 0);
  return !ts || Date.now() - ts >= REFRESH_MS;
}

async function readCached(userId) {
  try {
    const cache = await caches.open(CACHE_NAME);
    const hit = await cache.match(cacheKey(userId));
    if (!hit) return null;
    const blob = await hit.blob();
    return URL.createObjectURL(blob);
  } catch {
    return null;
  }
}

async function writeCached(userId, blob) {
  try {
    const cache = await caches.open(CACHE_NAME);
    await cache.put(cacheKey(userId), new Response(blob));
    localStorage.setItem(lastFetchKey(userId), String(Date.now()));
  } catch {
    /* ignore cache write failures */
  }
}

async function fetchDirectTikTokAvatar(userId) {
  const uid = String(userId || "").trim().replace(/^@/, "");
  if (!uid) return null;
  try {
    const pageRes = await fetch(`https://www.tiktok.com/@${encodeURIComponent(uid)}`, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept-Language": "en-GB,en;q=0.9",
      },
    });
    if (!pageRes.ok) return null;
    const html = await pageRes.text();
    let picUrl = null;
    for (const key of ["avatarLarger", "avatarMedium", "avatarThumb"]) {
      const m = html.match(new RegExp(`"${key}"\\s*:\\s*"([^"]+)"`));
      if (m) {
        picUrl = m[1].replace(/\\\//g, "/").replace(/\\u002F/g, "/");
        if (picUrl.startsWith("http")) break;
      }
    }
    if (!picUrl) {
      const m = html.match(/(https:\/\/p\d+-sign[^\s"<>\\]+\.(?:jpe?g|webp)(?:\?[^\s"<>]*)?)/);
      picUrl = m ? m[1].replace(/\\\//g, "/") : null;
    }
    if (!picUrl) return null;
    const picRes = await fetch(picUrl, {
      headers: {
        Referer: `https://www.tiktok.com/@${uid}`,
        "User-Agent":
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
      },
    });
    if (!picRes.ok) return null;
    const blob = await picRes.blob();
    if (!blob || blob.size < 32) return null;
    return blob;
  } catch {
    return null;
  }
}

export async function loadTikTokJumpAvatar({ force = false } = {}) {
  if (!isLoggedIn()) return null;
  const userId = getSession().userId;
  if (!userId) return null;

  if (!force && !needsRefresh(userId)) {
    const cached = await readCached(userId);
    if (cached) return cached;
  }

  const stale = await readCached(userId);
  try {
    const url = force ? "/api/mobile/me/avatar?refresh=1" : "/api/mobile/me/avatar";
    const res = await fetch(url, { headers: authHeaders() });
    if (res.ok) {
      const blob = await res.blob();
      if (blob && blob.size >= 32) {
        await writeCached(userId, blob);
        return URL.createObjectURL(blob);
      }
    }
  } catch {
    /* fall through */
  }

  const directBlob = await fetchDirectTikTokAvatar(userId);
  if (directBlob) {
    await writeCached(userId, directBlob);
    return URL.createObjectURL(directBlob);
  }
  return stale;
}

export function revokeAvatarObjectUrl(url) {
  if (url && String(url).startsWith("blob:")) {
    try {
      URL.revokeObjectURL(url);
    } catch {
      /* ignore */
    }
  }
}
