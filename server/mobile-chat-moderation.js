/**
 * App chat moderation — delete messages, mute/unmute players.
 * Admins: NFG_CHAT_ADMIN_USERS (comma-separated TikTok ids), default y666.suf
 */
const { normalizeUser } = require("./store");

const DEFAULT_ADMINS = ["y666.suf"];
const mutedUsers = new Map();

function normChatUser(id) {
  const u = normalizeUser(id);
  return u ? u.toLowerCase() : "";
}

function parseAdminList() {
  const raw = String(process.env.NFG_CHAT_ADMIN_USERS || DEFAULT_ADMINS.join(",")).trim();
  return raw
    .split(",")
    .map((s) => normChatUser(s))
    .filter(Boolean);
}

let adminSet = new Set(parseAdminList());

function isChatAdmin(userId) {
  if (!userId) return false;
  return adminSet.has(normChatUser(userId));
}

function isUserMuted(userId) {
  const key = normChatUser(userId);
  if (!key || key.startsWith("guest:")) return false;
  return mutedUsers.has(key);
}

function listMutedUsers() {
  return [...mutedUsers.values()].sort((a, b) => (b.mutedAt || 0) - (a.mutedAt || 0));
}

function muteUser(targetId, mutedBy, displayName) {
  const key = normChatUser(targetId);
  if (!key) return { ok: false, error: "invalid_user" };
  if (key.startsWith("guest:")) {
    return { ok: false, error: "guest_not_mutable", message: "Guests cannot be muted (not linked)." };
  }
  if (isChatAdmin(key)) {
    return { ok: false, error: "cannot_mute_admin", message: "Chat admins cannot be muted." };
  }
  const entry = {
    userId: normalizeUser(targetId),
    displayName: String(displayName || targetId || "").trim() || normalizeUser(targetId),
    mutedAt: Date.now(),
    mutedBy: normalizeUser(mutedBy),
  };
  mutedUsers.set(key, entry);
  return { ok: true, entry };
}

function unmuteUser(targetId) {
  const key = normChatUser(targetId);
  if (!key) return false;
  return mutedUsers.delete(key);
}

function moderationStatusForSession(session) {
  const userId = session?.userId || "";
  const isAdmin = isChatAdmin(userId);
  const isMuted = isUserMuted(userId);
  const out = { ok: true, isAdmin, isMuted };
  if (isAdmin) out.mutedUsers = listMutedUsers();
  return out;
}

function broadcastMuteState(broadcast) {
  if (typeof broadcast !== "function") return;
  broadcast({
    type: "app_chat_mute_state",
    payload: { mutedUsers: listMutedUsers() },
  });
}

function requireAdmin(session, res) {
  if (!session) {
    res.status(401).json({
      ok: false,
      error: "auth_required",
      message: "Link your TikTok account on live first.",
    });
    return false;
  }
  if (!isChatAdmin(session.userId)) {
    res.status(403).json({
      ok: false,
      error: "not_chat_admin",
      message: "Only chat moderators can do that.",
    });
    return false;
  }
  return true;
}

function registerMobileChatModerationRoutes(app, ctx) {
  const { broadcast, validateBearer, deleteMessageById } = ctx;

  app.get("/api/mobile/chat/moderation", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    res.json(moderationStatusForSession(session));
  });

  app.post("/api/mobile/chat/moderation/delete", (req, res) => {
    const session = validateBearer(req);
    if (!requireAdmin(session, res)) return;

    const messageId = String(req.body?.messageId || "").trim();
    if (!messageId) {
      return res.status(400).json({ ok: false, error: "message_id_required" });
    }
    const removed = typeof deleteMessageById === "function" && deleteMessageById(messageId);
    if (!removed) {
      return res.status(404).json({ ok: false, error: "message_not_found" });
    }
    if (typeof broadcast === "function") {
      broadcast({ type: "app_chat_delete", payload: { messageId } });
    }
    console.log(`[App chat mod] @${session.userId} deleted message ${messageId}`);
    res.json({ ok: true, messageId });
  });

  app.post("/api/mobile/chat/moderation/mute", (req, res) => {
    const session = validateBearer(req);
    if (!requireAdmin(session, res)) return;

    const targetId = String(req.body?.userId || req.body?.username || "").trim();
    const displayName = String(req.body?.displayName || "").trim();
    const result = muteUser(targetId, session.userId, displayName);
    if (!result.ok) {
      const status = result.error === "invalid_user" ? 400 : 403;
      return res.status(status).json({ ok: false, ...result });
    }
    broadcastMuteState(broadcast);
    console.log(`[App chat mod] @${session.userId} muted @${result.entry.userId}`);
    res.json({ ok: true, entry: result.entry, mutedUsers: listMutedUsers() });
  });

  app.post("/api/mobile/chat/moderation/unmute", (req, res) => {
    const session = validateBearer(req);
    if (!requireAdmin(session, res)) return;

    const targetId = String(req.body?.userId || req.body?.username || "").trim();
    if (!normChatUser(targetId)) {
      return res.status(400).json({ ok: false, error: "user_id_required" });
    }
    unmuteUser(targetId);
    broadcastMuteState(broadcast);
    console.log(`[App chat mod] @${session.userId} unmuted ${targetId}`);
    res.json({ ok: true, mutedUsers: listMutedUsers() });
  });
}

module.exports = {
  registerMobileChatModerationRoutes,
  isChatAdmin,
  isUserMuted,
  listMutedUsers,
  normChatUser,
};
