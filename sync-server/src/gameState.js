/** @typedef {'idle'|'betting'|'flying'|'crashed'} GamePhase */

/**
 * @typedef {Object} Player
 * @property {string} id
 * @property {string} displayName
 * @property {number} balance
 */

/**
 * @typedef {Object} Bet
 * @property {string} playerId
 * @property {string} displayName
 * @property {number} amount
 * @property {number|null} cashedOutAt
 */

/**
 * @typedef {Object} ChatLine
 * @property {string} user
 * @property {string} text
 * @property {number} ts
 */

/**
 * @typedef {Object} GameState
 * @property {GamePhase} phase
 * @property {string} roundId
 * @property {number} multiplier
 * @property {number|null} crashPoint
 * @property {number} countdownMs
 * @property {Player[]} players
 * @property {Bet[]} activeBets
 * @property {ChatLine[]} recentChat
 */

/** @returns {GameState} */
export function createInitialState() {
  return {
    phase: 'idle',
    roundId: 'r-0',
    multiplier: 1,
    crashPoint: null,
    countdownMs: 0,
    players: [],
    activeBets: [],
    recentChat: [],
  };
}

/** @param {unknown} raw */
export function mergeState(current, raw) {
  if (!raw || typeof raw !== 'object') return current;
  const next = { ...current, ...raw };
  next.players = Array.isArray(raw.players) ? raw.players : current.players;
  next.activeBets = Array.isArray(raw.activeBets) ? raw.activeBets : current.activeBets;
  next.recentChat = Array.isArray(raw.recentChat) ? raw.recentChat : current.recentChat;
  return next;
}
