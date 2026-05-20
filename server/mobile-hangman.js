/**
 * Hangman companion API on the NFG platform port (3847).
 * Guesses use the same Python path as TikTok chat: process_chat_message (via /api/hangman/app/guess).
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");
const { fetchHangmanJson, HANGMAN_BACKEND_URL } = require("./hangman-proxy");

const NFG_INTERNAL_SECRET = String(process.env.NFG_INTERNAL_SECRET || "nfg-dev-internal").trim();
const GUESS_TIMEOUT_MS = Math.max(3000, Number(process.env.NFG_HANGMAN_GUESS_TIMEOUT_MS) || 12000);

/** HTTP headers must be ASCII; TikTok display names may include emoji. */
function safeInternalHeaderValue(value, fallback = "App player") {
  const ascii = String(value || "")
    .replace(/[^\x20-\x7E]/g, "")
    .trim()
    .slice(0, 120);
  return ascii || fallback;
}

function hangmanGuessRequest(body, headers) {
  const url = `${HANGMAN_BACKEND_URL}/api/hangman/app/guess`;
  const parsed = new URL(url);
  const lib = parsed.protocol === "https:" ? https : http;
  const payload = JSON.stringify(body || {});
  return new Promise((resolve) => {
    const req = lib.request(
      {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === "https:" ? 443 : 80),
        path: parsed.pathname,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
          ...headers,
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          try {
            resolve({
              status: res.statusCode,
              body: JSON.parse(Buffer.concat(chunks).toString("utf8")),
            });
          } catch {
            resolve({ status: res.statusCode, body: { ok: false, error: "bad_hangman_response" } });
          }
        });
      }
    );
    req.on(
      "error",
      (err) =>
        resolve({ status: 502, body: { ok: false, error: "hangman_unreachable", message: err.message } })
    );
    req.setTimeout(GUESS_TIMEOUT_MS, () => {
      req.destroy();
      resolve({
        status: 504,
        body: { ok: false, error: "hangman_timeout", message: `Hangman did not respond within ${GUESS_TIMEOUT_MS}ms` },
      });
    });
    req.write(payload);
    req.end();
  });
}

function sanitizeKeyboard(kb) {
  if (!kb || typeof kb !== "object" || Array.isArray(kb)) return undefined;
  const correct = Array.isArray(kb.correct) ? kb.correct : [];
  const wrong = Array.isArray(kb.wrong) ? kb.wrong : [];
  return { correct, wrong };
}

/** Map Python app/guess payload → iOS companion shape. */
function mapHangmanGuessResponse(body) {
  if (!body || body.ok === false) {
    return {
      ok: false,
      error: (body && body.error) || "hangman_error",
      message: body && body.message ? String(body.message) : undefined,
      lines: Array.isArray(body?.lines) ? body.lines.map((l) => String(l)) : [],
    };
  }
  const guessed = Array.isArray(body.guessed)
    ? body.guessed.map((c) => String(c).toLowerCase())
    : [];
  return {
    ok: true,
    masked: body.masked || body.maskedWord || "",
    maskedWord: body.maskedWord || body.masked || "",
    slots: Array.isArray(body.slots) ? body.slots : undefined,
    keyboard: sanitizeKeyboard(body.keyboard),
    length: Number(body.length) || undefined,
    wrong: Number(body.wrong ?? body.wrongGuesses ?? 0),
    maxWrong: Number(body.maxWrong ?? 6),
    guessed,
    correct: body.correct === true ? true : body.correct === false ? false : undefined,
    eliminated: !!body.eliminated,
    won: !!body.won,
    lines: Array.isArray(body.lines) ? body.lines.map((l) => String(l)) : [],
  };
}

/** Map Python app/state (or snapshot) → iOS companion poll shape. */
function mapHangmanStateResponse(body, linkedSession) {
  if (!body || body.ok === false) {
    return {
      ok: false,
      error: (body && body.error) || "hangman_unreachable",
      message: body && body.message ? String(body.message) : undefined,
    };
  }
  const snap = body.state && typeof body.state === "object" ? body.state : body;
  const keyboard = sanitizeKeyboard(body.keyboard || snap.keyboard) || { correct: [], wrong: [] };
  let wrongGuesses = 0;
  const maxWrong = 6;
  if (linkedSession && linkedSession.userId) {
    const uk = String(linkedSession.userId).toLowerCase();
    const players = Array.isArray(snap.players) ? snap.players : [];
    const pl = players.find((p) => String(p.user_key || "").toLowerCase() === uk);
    if (pl) wrongGuesses = Number(pl.wrong) || 0;
  }
  const maskedWord = String(body.maskedWord || body.masked || snap.mask || "");
  return {
    ok: true,
    maskedWord,
    masked: maskedWord,
    slots: Array.isArray(body.slots) ? body.slots : snap.slots,
    keyboard,
    length: Number(body.length || snap.length) || 0,
    guessed_letters: body.guessed_letters || snap.guessed_letters || [],
    word_theme: String(body.word_theme || snap.word_theme || ""),
    tiktok: String(body.tiktok || ""),
    tiktok_status: String(body.tiktok_status || ""),
    wrong: wrongGuesses,
    wrongGuesses,
    maxWrong,
    phase: String(snap.phase || ""),
  };
}

function mapLeaderboardRows(top) {
  const rows = Array.isArray(top) ? top : [];
  return rows.map((r) => ({
    user: r.user_key || r.username || r.user || "",
    displayName: r.display_name || r.displayName || r.name || r.user_key || "",
    wins: Number(r.wins ?? r.total ?? r.score ?? 0),
    score: Number(r.score ?? r.total ?? r.wins ?? 0),
    user_key: r.user_key,
    display_name: r.display_name,
  }));
}

function registerHangmanMobileRoutes(app, ctx) {
  const { validateBearer } = ctx;

  app.get("/api/hangman/leaderboard", async (req, res) => {
    const limit = Math.min(50, Math.max(1, parseInt(String(req.query.limit || "12"), 10) || 12));
    const probe = await fetchHangmanJson(`/api/hangman/leaderboard?limit=${limit}`);
    if (!probe.ok || !probe.body) {
      return res.status(probe.status || 502).json({
        ok: false,
        error: "hangman_unreachable",
        backend: HANGMAN_BACKEND_URL,
      });
    }
    const top = probe.body.top || [];
    res.json({
      ok: true,
      rows: mapLeaderboardRows(top),
      top,
      service: "nfg-hangman",
    });
  });

  app.get("/api/mobile/hangman/state", async (req, res) => {
    try {
      const clientApp = String(req.headers["x-client-app"] || "").trim().toLowerCase();
      if (clientApp && clientApp !== "nfg-hangman") {
        return res.status(400).json({
          ok: false,
          error: "wrong_client_app",
          message: "Use X-Client-App: nfg-hangman",
        });
      }

      const probe = await fetchHangmanJson("/api/hangman/app/state");
      if (!probe.ok || !probe.body) {
        return res.status(probe.status || 502).json({
          ok: false,
          error: "hangman_unreachable",
          backend: HANGMAN_BACKEND_URL,
        });
      }

      const linked = typeof validateBearer === "function" ? validateBearer(req) : null;
      return res.json(mapHangmanStateResponse(probe.body, linked));
    } catch (err) {
      console.error("[mobile-hangman] state error:", err);
      if (!res.headersSent) {
        return res.status(500).json({
          ok: false,
          error: "state_failed",
          message: err && err.message ? String(err.message) : "State failed",
        });
      }
    }
  });

  app.post("/api/mobile/hangman/guess", async (req, res) => {
    try {
      const clientApp = String(req.headers["x-client-app"] || "").trim().toLowerCase();
      if (clientApp && clientApp !== "nfg-hangman") {
        return res.status(400).json({
          ok: false,
          error: "wrong_client_app",
          message: "Use X-Client-App: nfg-hangman",
        });
      }

      const session = typeof validateBearer === "function" ? validateBearer(req) : null;
      if (!session || !session.userId) {
        return res.status(401).json({
          ok: false,
          error: "auth_required",
          message: "Link your TikTok account on live first (!link CODE).",
        });
      }

      const letter = String(req.body?.letter || "")
        .trim()
        .toLowerCase()
        .replace(/[^a-z]/g, "");
      const word = String(req.body?.word || "").trim();
      const body =
        word.length >= 2 ? { word } : letter.length === 1 ? { letter: letter.toUpperCase() } : null;
      if (!body) {
        return res.status(400).json({ ok: false, error: "invalid_letter", message: "Send one letter A–Z." });
      }

      const out = await hangmanGuessRequest(body, {
        "X-NFG-Internal": NFG_INTERNAL_SECRET,
        "X-NFG-User-Id": String(session.userId).toLowerCase(),
        "X-NFG-Display-Name": safeInternalHeaderValue(
          session.displayName || session.userId,
          String(session.userId || "App player")
        ),
      });

      const mapped = mapHangmanGuessResponse(out.body);
      const status = mapped.ok === false ? out.status || 502 : out.status || 200;
      return res.status(status).json(mapped);
    } catch (err) {
      console.error("[mobile-hangman] guess error:", err);
      if (!res.headersSent) {
        return res.status(500).json({
          ok: false,
          error: "guess_failed",
          message: err && err.message ? String(err.message) : "Guess failed",
        });
      }
    }
  });
}

module.exports = {
  registerHangmanMobileRoutes,
  mapHangmanGuessResponse,
  mapHangmanStateResponse,
  hangmanGuessRequest,
  NFG_INTERNAL_SECRET,
};
