/**
 * Forward TikTok LIVE chat from the Node bridge into Hangman (Python).
 * One TikTok connection on port 3847 feeds Crash + Hangman guesses.
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");
const { HANGMAN_BACKEND_URL } = require("./hangman-proxy");

const NFG_INTERNAL_SECRET = String(process.env.NFG_INTERNAL_SECRET || "nfg-dev-internal").trim();
const FORWARD_TIMEOUT_MS = Math.max(2000, Number(process.env.NFG_HANGMAN_CHAT_FORWARD_MS) || 8000);
const ENABLED = process.env.HANGMAN_TIKTOK_COMMENTS_VIA_PLATFORM !== "0";

function forwardTikTokCommentToHangman(payload) {
  if (!ENABLED) return Promise.resolve({ skipped: true });
  const userId = String(payload?.userId || "").trim();
  const message = String(payload?.message || "").trim();
  if (!userId || !message) return Promise.resolve({ skipped: true });

  const body = JSON.stringify({
    userId,
    displayName: String(payload?.displayName || userId).trim() || userId,
    message,
    superFan: payload?.superFan === true,
    fanClubMember: payload?.fanClubMember === true,
  });

  let targetUrl;
  try {
    targetUrl = new URL("/api/hangman/tiktok/comment", HANGMAN_BACKEND_URL);
  } catch (e) {
    return Promise.reject(e);
  }

  const lib = targetUrl.protocol === "https:" ? https : http;

  return new Promise((resolve, reject) => {
    const req = lib.request(
      {
        hostname: targetUrl.hostname,
        port: targetUrl.port || (targetUrl.protocol === "https:" ? 443 : 80),
        path: targetUrl.pathname + targetUrl.search,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body, "utf8"),
          "X-NFG-Internal": NFG_INTERNAL_SECRET,
        },
        timeout: FORWARD_TIMEOUT_MS,
      },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          const text = Buffer.concat(chunks).toString("utf8");
          if (res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve(text ? JSON.parse(text) : { ok: true });
            } catch {
              resolve({ ok: true });
            }
            return;
          }
          reject(new Error(`Hangman tiktok/comment HTTP ${res.statusCode}: ${text.slice(0, 200)}`));
        });
      }
    );
    req.on("timeout", () => {
      req.destroy();
      reject(new Error("Hangman tiktok/comment timeout"));
    });
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

module.exports = { forwardTikTokCommentToHangman };
