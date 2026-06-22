/**
 * Reverse-proxy Retro Pixel Jump (FastAPI) through the NFG platform port.
 * Public: https://y666suf.com/api/pixel-jump/*  →  local uvicorn on PIXEL_JUMP_PORT (8001).
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");
const WebSocket = require("ws");

const PIXEL_JUMP_BACKEND_URL = String(
  process.env.PIXEL_JUMP_BACKEND_URL || "http://127.0.0.1:8001"
).replace(/\/$/, "");

const PUBLIC_PREFIX = "/api/pixel-jump";

function rewritePixelJumpPath(urlPath) {
  let path = String(urlPath || "/");
  if (path.startsWith(PUBLIC_PREFIX)) {
    path = path.slice(PUBLIC_PREFIX.length) || "/";
  }
  if (path.startsWith("/api/")) return path;
  if (path === "/") return "/api/";
  return `/api${path.startsWith("/") ? path : `/${path}`}`;
}

function pixelJumpTargetUrl(req) {
  const orig = req.originalUrl || req.url || "/";
  const qIndex = orig.indexOf("?");
  const pathOnly = qIndex >= 0 ? orig.slice(0, qIndex) : orig;
  const query = qIndex >= 0 ? orig.slice(qIndex) : "";
  const backendPath = rewritePixelJumpPath(pathOnly);
  return new URL(`${backendPath}${query}`, PIXEL_JUMP_BACKEND_URL);
}

function pixelJumpWsTarget(request) {
  let pathname = "/";
  let search = "";
  try {
    const parsed = new URL(request.url || "/", "http://localhost");
    pathname = parsed.pathname;
    search = parsed.search || "";
  } catch {
    const raw = String(request.url || "/");
    pathname = raw.split("?")[0] || "/";
    search = raw.includes("?") ? `?${raw.split("?").slice(1).join("?")}` : "";
  }
  const backendPath = rewritePixelJumpPath(pathname);
  const wsBase = PIXEL_JUMP_BACKEND_URL.replace(/^http/i, "ws");
  return `${wsBase}${backendPath}${search}`;
}

function proxyHttpRequest(req, res) {
  let targetUrl;
  try {
    targetUrl = pixelJumpTargetUrl(req);
  } catch (e) {
    return res.status(502).json({ ok: false, error: "pixel_jump_proxy_bad_url", message: e.message });
  }

  const lib = targetUrl.protocol === "https:" ? https : http;
  const headers = { ...req.headers, host: targetUrl.host };
  delete headers.connection;

  const hasParsedBody =
    req.body !== undefined &&
    req.body !== null &&
    ["POST", "PUT", "PATCH", "DELETE"].includes(String(req.method || "").toUpperCase());

  let bodyData = null;
  if (hasParsedBody) {
    bodyData = Buffer.isBuffer(req.body)
      ? req.body
      : Buffer.from(typeof req.body === "string" ? req.body : JSON.stringify(req.body), "utf8");
    headers["content-length"] = String(bodyData.length);
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
      });
    } else {
      res.end();
    }
  });

  if (bodyData) {
    proxyReq.write(bodyData);
    proxyReq.end();
    return;
  }

  req.pipe(proxyReq);
}

function registerPixelJumpHttpProxy(app) {
  app.use(PUBLIC_PREFIX, (req, res, next) => {
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

  if (!pathname.startsWith(`${PUBLIC_PREFIX}/ws/`) && !pathname.startsWith(`${PUBLIC_PREFIX}/api/ws/`)) {
    return false;
  }

  const pixelWss = new WebSocket.Server({ noServer: true });
  pixelWss.handleUpgrade(request, socket, head, (clientWs) => {
    const upstream = new WebSocket(pixelJumpWsTarget(request));
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
          clientWs.close(1011, "pixel jump upstream error");
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

  return true;
}

module.exports = {
  PIXEL_JUMP_BACKEND_URL,
  PUBLIC_PREFIX,
  registerPixelJumpHttpProxy,
  tryPixelJumpUpgrade,
};
