/**
 * Reverse-proxy NFG Word Games (Python/FastAPI) through the NFG platform port.
 * Public: https://y666suf.com/api/word-games/*  →  local Python on WORD_GAMES_PORT (19877).
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");

const WORD_GAMES_BACKEND_URL = String(
  process.env.WORD_GAMES_BACKEND_URL || "http://127.0.0.1:19877"
).replace(/\/$/, "");

function proxyHttpRequest(req, res) {
  let targetUrl;
  try {
    targetUrl = new URL(req.originalUrl || req.url, WORD_GAMES_BACKEND_URL);
  } catch (e) {
    return res.status(502).json({ ok: false, error: "word_games_proxy_bad_url", message: e.message });
  }

  const lib = targetUrl.protocol === "https:" ? https : http;
  const method = String(req.method || "GET").toUpperCase();
  const headers = { ...req.headers, host: targetUrl.host };
  delete headers.connection;

  // express.json() may have already consumed the stream — re-send parsed body.
  let bodyBuffer = null;
  if (["POST", "PUT", "PATCH", "DELETE"].includes(method)) {
    if (Buffer.isBuffer(req.body)) {
      bodyBuffer = req.body;
    } else if (req.body != null && typeof req.body === "object") {
      bodyBuffer = Buffer.from(JSON.stringify(req.body), "utf8");
      headers["content-type"] = headers["content-type"] || "application/json";
    }
  }
  if (bodyBuffer) {
    headers["content-length"] = String(bodyBuffer.length);
  }

  const proxyReq = lib.request(
    targetUrl,
    {
      method: req.method,
      headers,
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode || 502, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on("error", (err) => {
    if (!res.headersSent) {
      res.status(502).json({
        ok: false,
        error: "word_games_unreachable",
        message: err.message,
        backend: WORD_GAMES_BACKEND_URL,
      });
    } else {
      res.end();
    }
  });

  if (bodyBuffer) {
    proxyReq.end(bodyBuffer);
  } else {
    req.pipe(proxyReq);
  }
}

function registerWordGamesHttpProxy(app) {
  app.use("/api/word-games", (req, res, next) => {
    if (req.method === "OPTIONS") return next();
    proxyHttpRequest(req, res);
  });
}

module.exports = {
  WORD_GAMES_BACKEND_URL,
  registerWordGamesHttpProxy,
};
