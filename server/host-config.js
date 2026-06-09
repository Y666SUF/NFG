/** Game host TikTok id — mobile admin panel + economy edits. */
const GAME_HOST_USER = "y666.suf";

function normHostUser(id) {
  return String(id || "")
    .trim()
    .replace(/^@+/, "")
    .toLowerCase();
}

function isGameHost(userId) {
  return normHostUser(userId) === GAME_HOST_USER;
}

module.exports = { GAME_HOST_USER, normHostUser, isGameHost };
