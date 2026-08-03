/**
 * Reverse-proxy Hangman (Python/FastAPI) through the NFG platform port.
 * Keeps one public origin (3847) while Hangman runs on HANGMAN_PORT (default 19876).
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");
const WebSocket = require("ws");
const { tryTowerWorldUpgrade } = require("./tower-world");
const { tryJumpVsUpgrade } = require("./jump-vs-lobby");
const { tryPixelJumpUpgrade } = require("./pixel-jump-proxy");

const HANGMAN_BACKEND_URL = String(process.env.HANGMAN_BACKEND_URL || "http://127.0.0.1:19876").replace(
  /\/$/,
  ""
);

function hangmanWsTarget() {
  return HANGMAN_BACKEND_URL.replace(/^http/i, "ws") + "/ws";
}

function proxyHttpRequest(req, res) {
  let targetUrl;
  try {
    targetUrl = new URL(req.originalUrl || req.url, HANGMAN_BACKEND_URL);
  } catch (e) {
    return res.status(502).json({ ok: false, error: "hangman_proxy_bad_url", message: e.message });
  }

  const lib = targetUrl.protocol === "https:" ? https : http;
  const method = String(req.method || "GET").toUpperCase();
  const headers = { ...req.headers, host: targetUrl.host };
  delete headers.connection;

  let bodyBuffer = null;
  if (["POST", "PUT", "PATCH"].includes(method)) {
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
        error: "hangman_unreachable",
        message: err.message,
        backend: HANGMAN_BACKEND_URL,
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

function registerHangmanHttpProxy(app) {
  app.use("/api/hangman", (req, res, next) => {
    if (req.method === "OPTIONS") return next();
    proxyHttpRequest(req, res);
  });
}

function attachHangmanWebSocketProxy(httpServer, crashWss, ctx = {}) {
  const hangmanEnabled = ctx.hangmanWs !== false && String(process.env.NFG_START_HANGMAN || "0").trim() !== "0";
  const hangmanWss = hangmanEnabled ? new WebSocket.Server({ noServer: true }) : null;

  httpServer.on("upgrade", (request, socket, head) => {
    let pathname = "/";
    try {
      pathname = new URL(request.url || "/", "http://localhost").pathname;
    } catch {
      pathname = String(request.url || "/").split("?")[0] || "/";
    }

    if (hangmanEnabled && (pathname === "/hangman/ws" || pathname === "/api/hangman/ws")) {
      hangmanWss.handleUpgrade(request, socket, head, (clientWs) => {
        const upstream = new WebSocket(hangmanWsTarget());
        let clientOpen = true;
        let upstreamOpen = false;

        const closeBoth = () => {
          try {
            if (clientWs.readyState === WebSocket.OPEN) clientWs.close();
          } catch {
            /* ignore */
          }
          try {
            if (upstream.readyState === WebSocket.OPEN) upstream.close();
          } catch {
            /* ignore */
          }
        };

        upstream.on("open", () => {
          upstreamOpen = true;
          clientWs.on("message", (data) => {
            if (upstream.readyState === WebSocket.OPEN) upstream.send(data);
          });
          upstream.on("message", (data) => {
            if (clientWs.readyState === WebSocket.OPEN) clientWs.send(data);
          });
        });

        upstream.on("error", () => {
          if (clientOpen && clientWs.readyState === WebSocket.OPEN) {
            try {
              clientWs.close(1011, "hangman upstream error");
            } catch {
              /* ignore */
            }
          }
        });

        clientWs.on("error", closeBoth);
        clientWs.on("close", () => {
          clientOpen = false;
          if (upstreamOpen) upstream.close();
        });
        upstream.on("close", () => {
          if (clientOpen && clientWs.readyState === WebSocket.OPEN) clientWs.close();
        });
      });
      return;
    }

    if (tryPixelJumpUpgrade(request, socket, head)) return;
    if (tryTowerWorldUpgrade(request, socket, head)) return;
    if (tryJumpVsUpgrade(request, socket, head, ctx)) return;
    if (tryPixelJumpUpgrade(request, socket, head)) return;

    crashWss.handleUpgrade(request, socket, head, (ws) => {
      crashWss.emit("connection", ws, request);
    });
  });
}

async function fetchHangmanJson(pathname, timeoutMs = 1200) {
  const url = `${HANGMAN_BACKEND_URL}${pathname.startsWith("/") ? pathname : `/${pathname}`}`;
  return new Promise((resolve) => {
    const lib = url.startsWith("https:") ? https : http;
    const req = lib.get(url, (res) => {
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => {
        try {
          const body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
          resolve({ ok: res.statusCode >= 200 && res.statusCode < 300, status: res.statusCode, body });
        } catch {
          resolve({ ok: false, status: res.statusCode, body: null });
        }
      });
    });
    req.on("error", () => resolve({ ok: false, status: 0, body: null }));
    req.setTimeout(timeoutMs, () => {
      req.destroy();
      resolve({ ok: false, status: 0, body: null, timeout: true });
    });
  });
}

module.exports = {
  HANGMAN_BACKEND_URL,
  hangmanWsTarget,
  registerHangmanHttpProxy,
  attachHangmanWebSocketProxy,
  fetchHangmanJson,
};
