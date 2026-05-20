const fs = require("fs");
const path = require("path");

const SPOTIFY_TRACK_ID = "[0-9A-Za-z]{22}";
const SPOTIFY_URI_RE = new RegExp(`\\bspotify:track:(${SPOTIFY_TRACK_ID})\\b`, "i");
const SPOTIFY_URL_RE = new RegExp(
  `\\bopen\\.spotify\\.com\\/(?:[\\w-]+\\/)*track\\/(${SPOTIFY_TRACK_ID})\\b`,
  "i"
);

let tokenValue = "";
let tokenExpiresAtMs = 0;
let externalEnvCache = null;

function parseEnvFile(content) {
  const out = {};
  const lines = String(content || "").split(/\r?\n/);
  for (const raw of lines) {
    const line = String(raw || "").trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq < 1) continue;
    const key = line.slice(0, eq).trim();
    if (!key) continue;
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    out[key] = value;
  }
  return out;
}

function readExternalEnv() {
  if (externalEnvCache) return externalEnvCache;
  const candidates = [
    process.env.HANGMAN_ENV_PATH,
    path.join(__dirname, "..", "..", "hangman v2", ".env"),
    path.join(__dirname, "..", ".env"),
  ]
    .filter(Boolean)
    .map((p) => String(p));

  for (const p of candidates) {
    try {
      if (!fs.existsSync(p)) continue;
      const raw = fs.readFileSync(p, "utf8");
      externalEnvCache = parseEnvFile(raw);
      return externalEnvCache;
    } catch {
      // ignore and continue to next candidate
    }
  }
  externalEnvCache = {};
  return externalEnvCache;
}

function envValue(key) {
  const fromProcess = String(process.env[key] || "").trim();
  if (fromProcess) return fromProcess;
  const external = readExternalEnv();
  return String(external[key] || "").trim();
}

function pickEnv(...keys) {
  for (const key of keys) {
    const value = envValue(key);
    if (value) return value;
  }
  return "";
}

function spotifyConfig() {
  const clientId = pickEnv(
    "HANGMAN_SPOTIFY_CLIENT_ID",
    "NFG_SPOTIFY_CLIENT_ID",
    "WORDWICH_SPOTIFY_CLIENT_ID"
  );
  const clientSecret = pickEnv(
    "HANGMAN_SPOTIFY_CLIENT_SECRET",
    "NFG_SPOTIFY_CLIENT_SECRET",
    "WORDWICH_SPOTIFY_CLIENT_SECRET"
  );
  const refreshToken = pickEnv(
    "HANGMAN_SPOTIFY_REFRESH_TOKEN",
    "NFG_SPOTIFY_REFRESH_TOKEN",
    "WORDWICH_SPOTIFY_REFRESH_TOKEN"
  );
  return { clientId, clientSecret, refreshToken };
}

function spotifyConfigured() {
  const cfg = spotifyConfig();
  return Boolean(cfg.clientId && cfg.clientSecret && cfg.refreshToken);
}

function normalizeSpotifyError(status, bodyText, prefix) {
  const body = String(bodyText || "").slice(0, 240);
  return `${prefix}_${status}${body ? `:${body}` : ""}`;
}

async function fetchSpotifyJson(url, options = {}) {
  const res = await fetch(url, options);
  const text = await res.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = null;
    }
  }
  return { res, text, data };
}

async function getAccessToken(forceRefresh = false) {
  if (!forceRefresh && tokenValue && Date.now() < tokenExpiresAtMs) {
    return { ok: true, accessToken: tokenValue };
  }

  const cfg = spotifyConfig();
  if (!cfg.clientId || !cfg.clientSecret || !cfg.refreshToken) {
    return { ok: false, error: "spotify_not_configured" };
  }

  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: cfg.refreshToken,
    client_id: cfg.clientId,
    client_secret: cfg.clientSecret,
  });

  let payload;
  try {
    payload = await fetchSpotifyJson("https://accounts.spotify.com/api/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });
  } catch (err) {
    return { ok: false, error: String(err && err.message ? err.message : err) };
  }

  if (!payload.res.ok) {
    const errCode = String(payload.data && payload.data.error ? payload.data.error : "");
    if (payload.res.status === 400 && errCode === "invalid_grant") {
      return { ok: false, error: "invalid_refresh_token_run_oauth_again" };
    }
    if ((payload.res.status === 400 || payload.res.status === 401) && errCode === "invalid_client") {
      return { ok: false, error: "invalid_client_id_or_secret_check_dashboard" };
    }
    return {
      ok: false,
      error: normalizeSpotifyError(payload.res.status, payload.text, "token_http"),
    };
  }

  const accessToken = String(payload.data && payload.data.access_token ? payload.data.access_token : "");
  if (!accessToken) {
    return { ok: false, error: "token_no_access_token" };
  }

  const expiresInSec = Math.max(60, Number(payload.data.expires_in) || 3600);
  tokenValue = accessToken;
  tokenExpiresAtMs = Date.now() + expiresInSec * 1000 - 45_000;
  return { ok: true, accessToken };
}

function spotifyTrackIdFromInput(inputText) {
  let s = String(inputText || "").trim();
  if (s.startsWith("<") && s.endsWith(">")) {
    s = s.slice(1, -1).trim();
  }
  if (!s) return "";
  const uriMatch = s.match(SPOTIFY_URI_RE);
  if (uriMatch && uriMatch[1]) return uriMatch[1];
  const urlMatch = s.match(SPOTIFY_URL_RE);
  if (urlMatch && urlMatch[1]) return urlMatch[1];
  return "";
}

function trackLine(trackObj, depth = 0) {
  if (!trackObj || typeof trackObj !== "object" || depth > 6) return "";
  if (trackObj.track && typeof trackObj.track === "object" && trackObj.track !== trackObj) {
    const inner = trackLine(trackObj.track, depth + 1);
    if (inner) return inner;
  }
  const name = String(trackObj.name || "").trim();
  let artists = Array.isArray(trackObj.artists) ? trackObj.artists : [];
  if (!artists.length && trackObj.album && typeof trackObj.album === "object") {
    artists = Array.isArray(trackObj.album.artists) ? trackObj.album.artists : [];
  }
  const artistLine = artists
    .filter((a) => a && typeof a === "object")
    .map((a) => String(a.name || "").trim() || "?")
    .filter(Boolean)
    .join(", ");
  if (name && artistLine) return `${name} — ${artistLine}`;
  if (name) return name;
  if (artistLine) return artistLine;
  const uri = String(trackObj.uri || "").trim();
  if (uri.startsWith("spotify:track:") || uri.startsWith("spotify:episode:")) return uri;
  return "";
}

async function spotifyApiGet(path, retry = true) {
  const tok = await getAccessToken(false);
  if (!tok.ok) return { ok: false, error: tok.error };

  let payload;
  try {
    payload = await fetchSpotifyJson(`https://api.spotify.com/v1${path}`, {
      headers: {
        Authorization: `Bearer ${tok.accessToken}`,
        Accept: "application/json",
      },
    });
  } catch (err) {
    return { ok: false, error: String(err && err.message ? err.message : err) };
  }

  if (payload.res.status === 401 && retry) {
    tokenValue = "";
    tokenExpiresAtMs = 0;
    return spotifyApiGet(path, false);
  }

  if (!payload.res.ok) {
    if (payload.res.status === 404) return { ok: false, error: "no_active_device" };
    if (payload.res.status === 403) return { ok: false, error: "queue_list_needs_scope" };
    return {
      ok: false,
      error: normalizeSpotifyError(payload.res.status, payload.text, "spotify_http"),
    };
  }

  return { ok: true, data: payload.data || {} };
}

async function spotifyApiPost(path, retry = true) {
  const tok = await getAccessToken(false);
  if (!tok.ok) return { ok: false, error: tok.error };

  let res;
  let bodyText = "";
  try {
    res = await fetch(`https://api.spotify.com/v1${path}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${tok.accessToken}` },
    });
    bodyText = await res.text();
  } catch (err) {
    return { ok: false, error: String(err && err.message ? err.message : err) };
  }

  if (res.status === 401 && retry) {
    tokenValue = "";
    tokenExpiresAtMs = 0;
    return spotifyApiPost(path, false);
  }
  if (res.status === 403) return { ok: false, error: "queue_forbidden_premium_or_scope" };
  if (res.status === 404) return { ok: false, error: "no_active_device" };
  if (!(res.status === 200 || res.status === 204)) {
    return { ok: false, error: normalizeSpotifyError(res.status, bodyText, "queue_http") };
  }
  return { ok: true };
}

async function fetchTrackLabelById(trackId) {
  if (!new RegExp(`^${SPOTIFY_TRACK_ID}$`).test(trackId)) {
    return { ok: false, error: "bad_track_id" };
  }
  const out = await spotifyApiGet(`/tracks/${encodeURIComponent(trackId)}`);
  if (!out.ok) return out;
  const label = trackLine(out.data);
  return { ok: true, label: label || `spotify:track:${trackId}` };
}

async function searchFirstTrack(query) {
  const q = encodeURIComponent(String(query || "").trim());
  const out = await spotifyApiGet(`/search?q=${q}&type=track&limit=1`);
  if (!out.ok) return out;
  const items =
    out && out.data && out.data.tracks && Array.isArray(out.data.tracks.items)
      ? out.data.tracks.items
      : [];
  if (!items.length) return { ok: false, error: "no_results" };
  const first = items[0] || {};
  const uri = String(first.uri || "");
  if (!uri.startsWith("spotify:track:")) return { ok: false, error: "bad_uri" };
  const label = trackLine(first) || uri;
  return { ok: true, uri, label };
}

async function queueTrackBySearch(query, requestedBy) {
  const requestedByClean = String(requestedBy || "").trim() || "Viewer";
  const q = String(query || "").trim();
  if (!q) {
    return { ok: false, error: "empty_query", requestedBy: requestedByClean };
  }
  if (!spotifyConfigured()) {
    return { ok: false, error: "spotify_not_configured", requestedBy: requestedByClean };
  }

  const trackId = spotifyTrackIdFromInput(q);
  let uri = "";
  let label = "";
  if (trackId) {
    uri = `spotify:track:${trackId}`;
    const track = await fetchTrackLabelById(trackId);
    if (!track.ok) return { ok: false, error: track.error, requestedBy: requestedByClean };
    label = track.label;
  } else {
    const found = await searchFirstTrack(q);
    if (!found.ok) return { ok: false, error: found.error, requestedBy: requestedByClean };
    uri = found.uri;
    label = found.label;
  }

  const queued = await spotifyApiPost(`/me/player/queue?uri=${encodeURIComponent(uri)}`);
  if (!queued.ok) {
    return {
      ok: false,
      error: queued.error,
      requestedBy: requestedByClean,
      track: label,
    };
  }
  return { ok: true, requestedBy: requestedByClean, track: label, uri };
}

async function getSpotifyQueueSnapshot() {
  if (!spotifyConfigured()) {
    return { ok: false, error: "spotify_not_configured", upcoming: [] };
  }
  const out = await spotifyApiGet("/me/player/queue");
  if (!out.ok) return { ok: false, error: out.error, upcoming: [] };

  const queue = Array.isArray(out.data.queue) ? out.data.queue : [];
  const upcoming = queue
    .map((item) => trackLine(item))
    .filter(Boolean)
    .slice(0, 25);
  const currentlyPlaying = trackLine(out.data.currently_playing || {});
  return {
    ok: true,
    error: "",
    current: currentlyPlaying,
    upcoming,
    sourceCount: queue.length,
  };
}

async function getSpotifyNowPlaying() {
  if (!spotifyConfigured()) {
    return { ok: false, error: "spotify_not_configured", line: "Spotify not configured" };
  }
  // /currently-playing returns play state, but can be empty while player is active.
  const now = await spotifyApiGet("/me/player/currently-playing");
  if (!now.ok && now.error === "spotify_http_204") {
    return { ok: true, playing: false, line: "Nothing playing" };
  }
  if (now.ok) {
    const line = trackLine(now.data && now.data.item ? now.data.item : {});
    const isPlaying = Boolean(now.data && now.data.is_playing);
    if (line) {
      return { ok: true, playing: isPlaying, line: isPlaying ? line : `Paused · ${line}` };
    }
  }

  // Fallback to player endpoint.
  const player = await spotifyApiGet("/me/player");
  if (!player.ok) {
    return { ok: false, error: player.error, line: "—" };
  }
  const line = trackLine(player.data && player.data.item ? player.data.item : {});
  const isPlaying = Boolean(player.data && player.data.is_playing);
  if (!line) return { ok: true, playing: false, line: "Nothing playing" };
  return { ok: true, playing: isPlaying, line: isPlaying ? line : `Paused · ${line}` };
}

async function getSpotifyStatus() {
  const [now, queue] = await Promise.all([getSpotifyNowPlaying(), getSpotifyQueueSnapshot()]);
  return {
    ok: Boolean(now.ok || queue.ok),
    nowPlaying: now.line || "—",
    nowPlayingOk: Boolean(now.ok),
    nowPlayingError: now.ok ? "" : now.error || "unknown",
    queueOk: Boolean(queue.ok),
    queueError: queue.ok ? "" : queue.error || "unknown",
    upcoming: Array.isArray(queue.upcoming) ? queue.upcoming : [],
    currentFromQueue: queue.current || "",
  };
}

module.exports = {
  spotifyConfigured,
  queueTrackBySearch,
  getSpotifyNowPlaying,
  getSpotifyQueueSnapshot,
  getSpotifyStatus,
};
