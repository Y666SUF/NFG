/**
 * Reverse-proxy Hangman (Python/FastAPI) through the NFG platform port.
 * Keeps one public origin (3847) while Hangman runs on HANGMAN_PORT (default 19876).
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");
const WebSocket = require("ws");

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
  const headers = { ...req.headers, host: targetUrl.host };
  delete headers.connection;

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

  req.pipe(proxyReq);
}

function registerHangmanHttpProxy(app) {
  app.use("/api/hangman", (req, res, next) => {
    if (req.method === "OPTIONS") return next();
    proxyHttpRequest(req, res);
  });
}

function attachHangmanWebSocketProxy(httpServer, crashWss) {
  const hangmanWss = new WebSocket.Server({ noServer: true });

  httpServer.on("upgrade", (request, socket, head) => {
    let pathname = "/";
    try {
      pathname = new URL(request.url || "/", "http://localhost").pathname;
    } catch {
      pathname = String(request.url || "/").split("?")[0] || "/";
    }

    if (pathname === "/hangman/ws" || pathname === "/api/hangman/ws") {
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
