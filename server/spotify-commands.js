/**
 * NFG Crash Spotify chat commands — prefixed so they do not clash with Hangman (!hsong / !hqueue).
 *
 * Crash:  !csong  !cqueue  !caddsong  (long: !crashsong !crashqueue !crashaddsong)
 * Hangman uses: !hsong !hqueue !haddsong (see hangman v2/server.py)
 *
 * Bare !song / !queue / !addsong are rejected with a hint (both games may be live).
 */

const CRASH_QUEUE_RE =
  /^!(?:c(?:song|queue|addsong)|crash(?:song|queue|addsong))\b(.*)$/i;

const LEGACY_GENERIC_RE = /^!(?:song|queue|addsong)\b/i;

function parseCrashSpotifyQueueCommand(text) {
  const raw = String(text || "").trim();
  if (!raw) return null;
  if (LEGACY_GENERIC_RE.test(raw)) {
    return {
      rejected: true,
      reason: "ambiguous",
      help: "Use !csong or !cqueue for NFG Crash (Hangman uses !hsong / !hqueue).",
    };
  }
  const m = raw.match(CRASH_QUEUE_RE);
  if (!m) return null;
  const full = raw.slice(1).toLowerCase();
  let command = "song";
  if (full.startsWith("cqueue") || full.startsWith("crashqueue")) command = "queue";
  else if (full.startsWith("caddsong") || full.startsWith("crashaddsong")) command = "addsong";
  else if (full.startsWith("csong") || full.startsWith("crashsong")) command = "song";
  return {
    command,
    query: String(m[1] || "").trim(),
  };
}

module.exports = { parseCrashSpotifyQueueCommand };
