/**
 * Human-readable labels for X-Client-App / clientApp in shared app chat & presence.
 */
function normalizeClientApp(raw) {
  return String(raw || "nfg")
    .trim()
    .toLowerCase()
    .slice(0, 32);
}

function formatAppLabel(clientApp) {
  const key = normalizeClientApp(clientApp);
  if (key === "nfg-hangman" || key === "hangman") return "NFG Hangman";
  if (key === "nfg-crash" || key === "crash") return "NFG Crash";
  if (key === "nfg") return "NFG";
  return key ? key.replace(/^nfg-/, "NFG ").replace(/-/g, " ") : "NFG";
}

function resolveChatDisplayName(pointStore, userId, sessionDisplayName) {
  const uid = String(userId || "").trim();
  if (!uid) return "Player";
  const fromStore =
    pointStore && typeof pointStore.getDisplayName === "function"
      ? String(pointStore.getDisplayName(uid) || "").trim()
      : "";
  const fromSession = String(sessionDisplayName || "").trim();
  return fromStore || fromSession || uid;
}

module.exports = {
  normalizeClientApp,
  formatAppLabel,
  resolveChatDisplayName,
};
