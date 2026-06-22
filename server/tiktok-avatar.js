/** Best-effort TikTok profile avatar fetch (page HTML parse). */
const https = require("https");
const http = require("http");

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

const cache = new Map();
const CACHE_MS = 30 * 60 * 1000;

function fallbackAvatarSvg(initial = "NFG") {
  const letter = String(initial || "NFG")
    .trim()
    .charAt(0)
    .toUpperCase() || "N";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="a" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#8b5cf6"/><stop offset="100%" style="stop-color:#ec4899"/>
    </linearGradient>
  </defs>
  <circle cx="64" cy="64" r="64" fill="url(#a)"/>
  <text x="64" y="76" text-anchor="middle" fill="#eef6ff" font-family="Segoe UI,system-ui,sans-serif"
    font-size="42" font-weight="800">${letter}</text>
</svg>`;
}

function extractAvatarUrl(html) {
  if (!html) return null;
  for (const key of ["avatarLarger", "avatarMedium", "avatarThumb"]) {
    const re = new RegExp(`"${key}"\\s*:\\s*"([^"]+)"`);
    const m = html.match(re);
    if (m) {
      const url = m[1].replace(/\\\//g, "/").replace(/\\u002F/g, "/");
      if (url.startsWith("http")) return url;
    }
  }
  const m2 = html.match(/(https:\/\/p\d+-sign[^\s"<>\\]+\.(?:jpe?g|webp)(?:\?[^\s"<>]*)?)/);
  if (m2) return m2[1].replace(/\\\//g, "/");
  return null;
}

function fetchUrl(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith("https") ? https : http;
    const req = lib.get(
      url,
      {
        headers: { "User-Agent": UA, "Accept-Language": "en-GB,en;q=0.9", ...headers },
        timeout: 18000,
      },
      (res) => {
        if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          fetchUrl(res.headers.location, headers).then(resolve).catch(reject);
          return;
        }
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve({ status: res.statusCode || 0, headers: res.headers, body: Buffer.concat(chunks) }));
      }
    );
    req.on("error", reject);
    req.on("timeout", () => {
      req.destroy();
      reject(new Error("timeout"));
    });
  });
}

async function fetchProfileAvatarBytes(uniqueId) {
  const uid = String(uniqueId || "")
    .trim()
    .replace(/^@/, "");
  if (!uid) return null;
  const pageUrl = `https://www.tiktok.com/@${encodeURIComponent(uid)}`;
  try {
    const page = await fetchUrl(pageUrl);
    const html = page.body.toString("utf8");
    const picUrl = extractAvatarUrl(html);
    if (!picUrl) return null;
    const img = await fetchUrl(picUrl, { Referer: pageUrl });
    if (img.status !== 200 || !img.body || img.body.length < 64) return null;
    const head = img.body.slice(0, 4).toString("utf8");
    if (head.startsWith("<htm") || head.startsWith("<!DO")) return null;
    return img.body;
  } catch {
    return null;
  }
}

async function getPlayerAvatar(uniqueId) {
  const uid = String(uniqueId || "")
    .trim()
    .replace(/^@/, "");
  if (!uid) return { bytes: null, mime: "image/svg+xml", fallback: true };
  const hit = cache.get(uid);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.data;

  const bytes = await fetchProfileAvatarBytes(uid);
  let data;
  if (bytes) {
    const mime = bytes[0] === 0xff && bytes[1] === 0xd8 ? "image/jpeg" : "image/webp";
    data = { bytes, mime, fallback: false };
  } else {
    data = {
      bytes: Buffer.from(fallbackAvatarSvg(uid.charAt(0)), "utf8"),
      mime: "image/svg+xml",
      fallback: true,
    };
  }
  cache.set(uid, { at: Date.now(), data });
  return data;
}

module.exports = { getPlayerAvatar, fallbackAvatarSvg };
