import { getSession } from "./shared.js";

export class JumpVsClient {
  constructor(hooks = {}) {
    this.hooks = hooks;
    this.ws = null;
    this.phase = "waiting";
    this.players = [];
    this.countdownSeconds = 0;
    this.matchSeed = null;
    this.matchId = null;
    this.opponents = new Map();
    this.eliminated = false;
    this.pot = 0;
    this.winnerId = null;
  }

  connect() {
    if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
      return;
    }
    const session = getSession();
    if (!session.token) throw new Error("Link TikTok to join Jump VS.");
    const proto = location.protocol === "https:" ? "wss" : "ws";
    const url = `${proto}://${location.host}/api/mobile/jump/vs/ws?token=${encodeURIComponent(session.token)}`;
    this.ws = new WebSocket(url);
    this.ws.onopen = () => {
      this.sendJoin();
      this.hooks.onConnected?.();
    };
    this.ws.onmessage = (ev) => this.handleMessage(ev.data);
    this.ws.onclose = () => {
      this.hooks.onDisconnected?.();
    };
    this.ws.onerror = () => {
      this.hooks.onError?.("Jump VS connection failed.");
    };
  }

  disconnect() {
    if (this.ws) {
      try {
        this.ws.close();
      } catch {
        /* ignore */
      }
      this.ws = null;
    }
  }

  sendJoin() {
    const session = getSession();
    this.send({
      type: "join",
      displayName: session.displayName || session.userId || "Player",
      skinId: this.hooks.skinId || "classic",
      fill: this.hooks.fill || "#596ff2",
      ring: this.hooks.ring || "#f2c733",
    });
  }

  send(obj) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(obj));
    }
  }

  reportProgress(height, sessionPoints) {
    if (this.phase !== "match" || this.eliminated) return;
    this.send({ type: "progress", height, sessionPoints });
  }

  handleMessage(raw) {
    let msg;
    try {
      msg = JSON.parse(String(raw));
    } catch {
      return;
    }
    if (!msg || typeof msg !== "object") return;
    const type = String(msg.type || "");

    if (type === "lobby_state") {
      this.phase = msg.phase || this.phase;
      this.players = Array.isArray(msg.players) ? msg.players : [];
      this.countdownSeconds = msg.countdownSeconds || 0;
      if (msg.match?.matchSeed) this.matchSeed = msg.match.matchSeed;
      this.hooks.onLobbyState?.(this.snapshot());
      return;
    }

    if (type === "match_start") {
      this.phase = "match";
      this.matchSeed = msg.matchSeed;
      this.matchId = msg.matchId;
      this.eliminated = false;
      this.opponents.clear();
      for (const p of msg.players || []) {
        if (p.id !== getSession().userId) this.opponents.set(p.id, { ...p });
      }
      this.hooks.onMatchStart?.(this.snapshot());
      return;
    }

    if (type === "opponent_progress") {
      if (msg.id === getSession().userId) return;
      this.opponents.set(msg.id, {
        id: msg.id,
        height: msg.height || 0,
        skinId: msg.skinId,
        fill: msg.fill,
        ring: msg.ring,
        sessionPoints: msg.sessionPoints || 0,
        eliminated: !!msg.eliminated,
      });
      this.hooks.onOpponents?.(this.opponentList());
      return;
    }

    if (type === "eliminated" && msg.id === getSession().userId) {
      this.eliminated = true;
      this.hooks.onEliminated?.(msg.reason || "pace");
      return;
    }

    if (type === "match_end") {
      this.phase = "results";
      this.pot = msg.pot || 0;
      this.winnerId = msg.winnerId || null;
      this.hooks.onMatchEnd?.(msg);
      return;
    }

    if (type === "player_join" || type === "player_leave") {
      this.hooks.onLobbyState?.(this.snapshot());
    }
  }

  opponentList() {
    return [...this.opponents.values()].filter((p) => !p.eliminated);
  }

  snapshot() {
    return {
      phase: this.phase,
      players: this.players,
      countdownSeconds: this.countdownSeconds,
      matchSeed: this.matchSeed,
      matchId: this.matchId,
      eliminated: this.eliminated,
      opponents: this.opponentList(),
      pot: this.pot,
      winnerId: this.winnerId,
    };
  }
}
