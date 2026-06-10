/**
 * Reverse-proxy Retro Pixel Jump (Python/FastAPI) through the NFG platform port.
 * Public: https://y666suf.com/api/pixel-jump/*  →  local API on PIXEL_JUMP_PORT (8001).
 * WebSocket: wss://y666suf.com/api/ws/mp/*     →  ws://127.0.0.1:8001/api/ws/mp/*
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");
const WebSocket = require("ws");

const PIXEL_JUMP_BACKEND_URL = String(
  process.env.PIXEL_JUMP_BACKEND_URL || "http://127.0.0.1:8001"
).replace(/\/$/, "");

const PIXEL_JUMP_WS_BASE = PIXEL_JUMP_BACKEND_URL.replace(/^http/i, "ws");

const pixelJumpWss = new WebSocket.Server({ noServer: true });

function proxyHttpRequest(req, res) {
  let targetUrl;
  try {
    targetUrl = new URL(req.originalUrl || req.url, PIXEL_JUMP_BACKEND_URL);
  } catch (e) {
    return res.status(502).json({ ok: false, error: "pixel_jump_proxy_bad_url", message: e.message });
  }

  const lib = targetUrl.protocol === "https:" ? https : http;
  const headers = { ...req.headers, host: targetUrl.host };
  delete headers.connection;

  const method = String(req.method || "GET").toUpperCase();
  const hasParsedBody =
    req.body != null &&
    typeof req.body === "object" &&
    !Buffer.isBuffer(req.body) &&
    ["POST", "PUT", "PATCH", "DELETE"].includes(method);
  let bodyBuffer = null;
  if (hasParsedBody) {
    bodyBuffer = Buffer.from(JSON.stringify(req.body), "utf8");
    headers["content-type"] = headers["content-type"] || "application/json";
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
        error: "pixel_jump_unreachable",
        message: err.message,
        backend: PIXEL_JUMP_BACKEND_URL,
        hint: "Start Pixel Jump API on port 8001 (docker compose or uvicorn).",
      });
    } else {
      res.end();
    }
  });

  if (bodyBuffer) {
    proxyReq.write(bodyBuffer);
    proxyReq.end();
  } else {
    req.pipe(proxyReq);
  }
}

function registerPixelJumpHttpProxy(app) {
  app.use("/api/pixel-jump", (req, res, next) => {
    if (req.method === "OPTIONS") return next();
    proxyHttpRequest(req, res);
  });
}

function tryPixelJumpUpgrade(request, socket, head) {
  let pathname = "/";
  try {
    pathname = new URL(request.url || "/", "http://localhost").pathname;
  } catch {
    pathname = String(request.url || "/").split("?")[0] || "/";
  }

  if (!pathname.startsWith("/api/ws/mp/")) return false;

  const upstreamUrl = `${PIXEL_JUMP_WS_BASE}${request.url || pathname}`;
  pixelJumpWss.handleUpgrade(request, socket, head, (ws) => {
    const upstream = new WebSocket(upstreamUrl);
    let clientOpen = true;

    upstream.on("open", () => {
      ws.on("message", (data) => {
        if (upstream.readyState === WebSocket.OPEN) upstream.send(data);
      });
      upstream.on("message", (data) => {
        if (ws.readyState === WebSocket.OPEN) ws.send(data);
      });
    });

    upstream.on("error", () => {
      if (clientOpen && ws.readyState === WebSocket.OPEN) {
        try {
          ws.close(1011, "pixel jump upstream error");
        } catch {
          /* ignore */
        }
      }
    });

    ws.on("error", () => {
      try {
        upstream.close();
      } catch {
        /* ignore */
      }
    });
    ws.on("close", () => {
      clientOpen = false;
      try {
        upstream.close();
      } catch {
        /* ignore */
      }
    });
    upstream.on("close", () => {
      if (clientOpen && ws.readyState === WebSocket.OPEN) ws.close();
    });
  });
  return true;
}

function pixelJumpHealthUrl() {
  return `${PIXEL_JUMP_BACKEND_URL}/api/`;
}

function waitForPixelJump(timeoutMs = 45000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    function tick() {
      const req = http.get(pixelJumpHealthUrl(), (res) => {
        let body = "";
        res.on("data", (c) => {
          body += c;
        });
        res.on("end", () => {
          if (res.statusCode >= 200 && res.statusCode < 400) {
            try {
              const json = JSON.parse(body);
              if (json && json.app === "retro-pixel-jump") return resolve(true);
            } catch {
              /* fall through */
            }
          }
          if (Date.now() - start > timeoutMs) return reject(new Error("Pixel Jump health check timeout"));
          setTimeout(tick, 400);
        });
      });
      req.on("error", () => {
        if (Date.now() - start > timeoutMs) {
          return reject(new Error("Timed out waiting for Pixel Jump API"));
        }
        setTimeout(tick, 400);
      });
      req.setTimeout(2000, () => {
        req.destroy();
        if (Date.now() - start > timeoutMs) return reject(new Error("Pixel Jump health check timeout"));
        setTimeout(tick, 400);
      });
    }
    tick();
  });
}

module.exports = {
  PIXEL_JUMP_BACKEND_URL,
  registerPixelJumpHttpProxy,
  tryPixelJumpUpgrade,
  pixelJumpHealthUrl,
  waitForPixelJump,
};
