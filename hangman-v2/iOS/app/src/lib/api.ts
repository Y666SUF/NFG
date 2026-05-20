import { apiUrl, CLIENT_APP } from "./config";
import { getDeviceId, getSession } from "./storage";
import type {
  AppChatMessage,
  GuessResult,
  HangmanLeaderboardRow,
  HangmanState,
  LinkStartResponse,
  LinkStatusResponse,
  PlatformStatus,
  PresenceSnapshot,
} from "../types";

export class ApiError extends Error {
  constructor(
    message: string,
    public status?: number
  ) {
    super(message);
  }
}

async function authHeaders(): Promise<HeadersInit> {
  const [{ token }, deviceId] = await Promise.all([getSession(), getDeviceId()]);
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "X-Device-Id": deviceId,
    "X-Client-App": CLIENT_APP,
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  return headers;
}

async function parseJson<T>(res: Response): Promise<T> {
  const text = await res.text();
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new ApiError(text || `HTTP ${res.status}`, res.status);
  }
}

export async function fetchPlatformStatus(): Promise<PlatformStatus> {
  const res = await fetch(apiUrl("/api/mobile/platform/status"), {
    headers: { "X-Client-App": CLIENT_APP },
  });
  if (!res.ok) throw new ApiError("Could not load platform status", res.status);
  return parseJson(res);
}

export async function sendPresenceHeartbeat(): Promise<PresenceSnapshot> {
  const res = await fetch(apiUrl("/api/mobile/presence/heartbeat"), {
    method: "POST",
    headers: await authHeaders(),
    body: JSON.stringify({ deviceId: await getDeviceId() }),
  });
  if (!res.ok) throw new ApiError("Presence update failed", res.status);
  return parseJson(res);
}

export async function fetchActiveUsers(): Promise<PresenceSnapshot> {
  const res = await fetch(apiUrl("/api/mobile/presence/active"));
  if (!res.ok) throw new ApiError("Could not load online players", res.status);
  return parseJson(res);
}

export async function fetchChatHistory(limit = 60): Promise<AppChatMessage[]> {
  const res = await fetch(apiUrl(`/api/mobile/chat?limit=${limit}`), {
    headers: await authHeaders(),
  });
  if (!res.ok) throw new ApiError("Could not load chat", res.status);
  const data = await parseJson<{ messages?: AppChatMessage[] }>(res);
  return data.messages || [];
}

export async function sendChatMessage(message: string): Promise<AppChatMessage> {
  const res = await fetch(apiUrl("/api/mobile/chat"), {
    method: "POST",
    headers: await authHeaders(),
    body: JSON.stringify({ message }),
  });
  if (!res.ok) {
    const err = await parseJson<{ message?: string; error?: string }>(res).catch(
      () => ({ message: `HTTP ${res.status}` })
    );
    throw new ApiError(err.message || err.error || "Send failed", res.status);
  }
  const data = await parseJson<{ message: AppChatMessage }>(res);
  return data.message;
}

export async function fetchHangmanLeaderboard(): Promise<HangmanLeaderboardRow[]> {
  const res = await fetch(apiUrl("/api/hangman/leaderboard"));
  if (!res.ok) throw new ApiError("Could not load leaderboard", res.status);
  const data = await parseJson<{ rows?: HangmanLeaderboardRow[]; leaderboard?: HangmanLeaderboardRow[] }>(
    res
  );
  return data.rows || data.leaderboard || [];
}

export async function postHangmanGuess(letter: string): Promise<GuessResult> {
  const res = await fetch(apiUrl("/api/mobile/hangman/guess"), {
    method: "POST",
    headers: await authHeaders(),
    body: JSON.stringify({ letter: letter.toLowerCase() }),
  });
  const data = await parseJson<GuessResult>(res);
  if (!res.ok) {
    throw new ApiError(data.message || data.error || "Guess failed", res.status);
  }
  return data;
}

export async function startLink(): Promise<LinkStartResponse> {
  const res = await fetch(apiUrl("/api/mobile/link/start"), {
    method: "POST",
    headers: await authHeaders(),
    body: JSON.stringify({ deviceId: await getDeviceId() }),
  });
  if (!res.ok) throw new ApiError("Could not start linking", res.status);
  return parseJson(res);
}

export async function linkStatus(code: string): Promise<LinkStatusResponse> {
  const res = await fetch(apiUrl(`/api/mobile/link/status/${encodeURIComponent(code)}`), {
    headers: await authHeaders(),
  });
  if (!res.ok) throw new ApiError("Link status unavailable", res.status);
  return parseJson(res);
}

/** Optional REST fallback if WS not connected yet. */
export async function fetchHangmanState(): Promise<HangmanState | null> {
  const res = await fetch(apiUrl("/api/mobile/hangman/state"), {
    headers: await authHeaders(),
  });
  if (res.status === 404) return null;
  if (!res.ok) return null;
  return parseJson(res);
}
