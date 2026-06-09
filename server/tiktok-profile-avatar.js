/**
 * Best-effort TikTok profile avatar fetch + 24h disk cache.
 */
const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const CACHE_DIR = path.join(getAppRoot(), "data", "tiktok-avatars");

function ensureCacheDir() {
  if (!fs.existsSync(CACHE_DIR)) fs.mkdirSync(CACHE_DIR, { recursive: true });
}

function safeUserKey(uniqueId) {
  return String(uniqueId || "")
    .trim()
    .replace(/^@/, "")
    .toLowerCase()
    .replace(/[^a-z0-9._-]/g, "");
}

function cachePaths(userKey) {
  return {
    bytes: path.join(CACHE_DIR, `${userKey}.bin`),
    meta: path.join(CACHE_DIR, `${userKey}.json`),
  };
}

function detectMime(bytes) {
  if (!bytes || bytes.length < 4) return "image/jpeg";
  if (bytes[0] === 0x89 && bytes[1] === 0x50) return "image/png";
  if (bytes[0] === 0x47 && bytes[1] === 0x49) return "image/gif";
  if (bytes[0] === 0x52 && bytes[1] === 0x49) return "image/webp";
  return "image/jpeg";
}

function extractAvatarUrl(html) {
  const text = String(html || "");
  for (const key of ["avatarLarger", "avatarMedium", "avatarThumb"]) {
    const re = new RegExp(`"${key}"\\s*:\\s*"([^"]+)"`);
    const m = text.match(re);
    if (m) {
      const url = m[1].replace(/\\\//g, "/").replace(/\\u002F/g, "/");
      if (url.startsWith("http")) return url;
    }
  }
  const signMatch = text.match(
    /(https:\/\/p\d+-sign[^\s"<>\\]+\.(?:jpe?g|webp)(?:\?[^\s"<>]*)?)/
  );
  if (signMatch) return signMatch[1].replace(/\\\//g, "/");
  return null;
}

async function fetchHtml(url, headers) {
  const res = await fetch(url, { headers, redirect: "follow" });
  if (!res.ok) return null;
  return res.text();
}

async function fetchBytes(url, headers) {
  const res = await fetch(url, { headers, redirect: "follow" });
  if (!res.ok) return null;
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length < 16) return null;
  const head = buf.subarray(0, 4).toString("utf8");
  if (head.startsWith("<htm") || head.startsWith("<!DO")) return null;
  return buf;
}

async function downloadAvatarFromTikTok(uniqueId) {
  const uid = safeUserKey(uniqueId);
  if (!uid) return null;
  const pageUrl = `https://www.tiktok.com/@${uid}`;
  const headers = {
    "User-Agent": UA,
    "Accept-Language": "en-GB,en;q=0.9",
  };
  try {
    const html = await fetchHtml(pageUrl, headers);
    if (!html) return null;
    const picUrl = extractAvatarUrl(html);
    if (!picUrl) return null;
    const bytes = await fetchBytes(picUrl, { ...headers, Referer: pageUrl });
    return bytes;
  } catch {
    return null;
  }
}

function readCachedAvatar(userKey) {
  const { bytes, meta } = cachePaths(userKey);
  if (!fs.existsSync(bytes) || !fs.existsSync(meta)) return null;
  try {
    const metaRaw = JSON.parse(fs.readFileSync(meta, "utf8"));
    const age = Date.now() - (Number(metaRaw.fetchedAt) || 0);
    return {
      bytes: fs.readFileSync(bytes),
      mime: metaRaw.mime || "image/jpeg",
      fetchedAt: Number(metaRaw.fetchedAt) || 0,
      fresh: age < CACHE_TTL_MS,
      stale: age >= CACHE_TTL_MS,
    };
  } catch {
    return null;
  }
}

function writeCachedAvatar(userKey, bytes, mime) {
  ensureCacheDir();
  const paths = cachePaths(userKey);
  fs.writeFileSync(paths.bytes, bytes);
  fs.writeFileSync(
    paths.meta,
    JSON.stringify({ fetchedAt: Date.now(), mime: mime || detectMime(bytes) }, null, 2),
    "utf8"
  );
}

async function getAvatarBytes(uniqueId, { forceRefresh = false } = {}) {
  const userKey = safeUserKey(uniqueId);
  if (!userKey) return null;

  const cached = readCachedAvatar(userKey);
  if (!forceRefresh && cached && cached.fresh) {
    return {
      bytes: cached.bytes,
      mime: cached.mime,
      cached: true,
      stale: false,
    };
  }

  const downloaded = await downloadAvatarFromTikTok(userKey);
  if (downloaded) {
    const mime = detectMime(downloaded);
    writeCachedAvatar(userKey, downloaded, mime);
    return { bytes: downloaded, mime, cached: false, stale: false };
  }

  if (cached) {
    return {
      bytes: cached.bytes,
      mime: cached.mime,
      cached: true,
      stale: true,
    };
  }
  return null;
}

function registerTikTokAvatarRoutes(app, { validateBearer }) {
  app.get("/api/mobile/me/avatar", async (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account first.",
      });
    }
    const forceRefresh = String(req.query.refresh || "") === "1";
    try {
      const result = await getAvatarBytes(session.userId, { forceRefresh });
      if (!result) {
        return res.status(404).json({
          ok: false,
          error: "avatar_not_found",
          message: "Could not load TikTok profile picture.",
        });
      }
      res.set("Cache-Control", "private, max-age=3600");
      if (result.stale) res.set("X-Avatar-Stale", "1");
      return res.type(result.mime).send(result.bytes);
    } catch (err) {
      return res.status(500).json({
        ok: false,
        error: "avatar_fetch_failed",
        message: err && err.message ? err.message : "Avatar fetch failed.",
      });
    }
  });
}

module.exports = {
  registerTikTokAvatarRoutes,
  getAvatarBytes,
  CACHE_TTL_MS,
};
