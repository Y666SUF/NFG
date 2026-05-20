/**
 * Human-readable app names for shared mobile chat / presence.
 */
const { playerBadgesFromStore } = require("./mobile-player-badges");

function appLabelFromClientApp(clientApp) {
  const raw = String(clientApp || "")
    .trim()
    .toLowerCase();
  if (raw === "nfg-crash" || raw === "crash" || raw === "com.nfg.crash") return "NFG Crash";
  if (raw === "nfg-hangman" || raw === "hangman" || raw === "com.nfg.hangman") return "NFG Hangman";
  if (raw === "nfg" || raw === "") return "NFG";
  return raw.replace(/^nfg-/, "NFG ").replace(/-/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function chatDisplayName(pointStore, userId, fallback) {
  if (pointStore && typeof pointStore.getUserPresentation === "function") {
    const view = pointStore.getUserPresentation(userId);
    if (view && view.displayName) return String(view.displayName);
  }
  return String(fallback || userId || "Player");
}

function enrichChatMessage(row, pointStore) {
  if (!row) return row;
  const userId = row.userId;
  const displayName = chatDisplayName(pointStore, userId, row.displayName);
  const clientApp = String(row.clientApp || "nfg").trim().slice(0, 32) || "nfg";
  return {
    ...row,
    displayName,
    clientApp,
    appLabel: appLabelFromClientApp(clientApp),
    ...(userId ? playerBadgesFromStore(pointStore, userId) : {}),
  };
}

module.exports = {
  appLabelFromClientApp,
  chatDisplayName,
  enrichChatMessage,
};
