export interface PlatformStatus {
  ok?: boolean;
  tiktokLive?: {
    enabled?: boolean;
    uniqueId?: string;
    state?: string;
    isLive?: boolean;
    roomId?: string;
  };
  activeAppUsers?: number;
  activeAppUserList?: ActiveAppUser[];
}

export interface ActiveAppUser {
  userId: string;
  displayName: string;
  username?: string | null;
  isGuest?: boolean;
  superFan?: boolean;
  superFanLevel?: number;
}

export interface PresenceSnapshot {
  ok?: boolean;
  activeAppUsers?: number;
  activeAppUserList?: ActiveAppUser[];
}

export interface AppChatMessage {
  id: string;
  userId: string;
  displayName: string;
  message: string;
  at: number;
  superFan?: boolean;
  superFanLevel?: number;
}

export interface HangmanLeaderboardRow {
  user?: string;
  name?: string;
  displayName?: string;
  wins?: number;
  score?: number;
  rank?: number;
}

export interface HangmanState {
  masked?: string;
  word?: string;
  wrong?: number;
  maxWrong?: number;
  guessed?: string[];
  eliminated?: boolean;
  won?: boolean;
  lost?: boolean;
  roundId?: number;
  message?: string;
}

export interface GuessResult extends HangmanState {
  ok?: boolean;
  error?: string;
  correct?: boolean;
}

export interface LinkStartResponse {
  ok?: boolean;
  code: string;
  expiresInSeconds: number;
  tiktokCommand?: string;
  instructions?: string;
}

export interface LinkStatusResponse {
  ok?: boolean;
  status: string;
  userId?: string;
  displayName?: string;
  token?: string;
}

export type WsEnvelope = {
  type: string;
  payload?: unknown;
};
