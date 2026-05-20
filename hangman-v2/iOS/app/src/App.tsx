import { useCallback, useEffect, useMemo, useState } from "react";
import { TopBar } from "./components/TopBar";
import { TabBar, type TabId } from "./components/TabBar";
import { PlayTab } from "./tabs/PlayTab";
import { BoardTab } from "./tabs/BoardTab";
import { ChatTab } from "./tabs/ChatTab";
import { AccountTab } from "./tabs/AccountTab";
import {
  fetchPlatformStatus,
  sendPresenceHeartbeat,
} from "./lib/api";
import { connectHangmanWs, connectPlatformWs } from "./lib/ws";
import { getSession } from "./lib/storage";
import type {
  AppChatMessage,
  HangmanLeaderboardRow,
  HangmanState,
  PlatformStatus,
  WsEnvelope,
} from "./types";

export default function App() {
  const [tab, setTab] = useState<TabId>("play");
  const [platform, setPlatform] = useState<PlatformStatus | null>(null);
  const [inApps, setInApps] = useState(0);
  const [hangman, setHangman] = useState<HangmanState | null>(null);
  const [leaderboard, setLeaderboard] = useState<HangmanLeaderboardRow[]>([]);
  const [chat, setChat] = useState<AppChatMessage[]>([]);
  const [token, setToken] = useState<string | null>(null);
  const [userId, setUserId] = useState("");
  const [displayName, setDisplayName] = useState("");

  const loggedIn = !!token && !!userId;

  const refreshPlatform = useCallback(async () => {
    try {
      const s = await fetchPlatformStatus();
      setPlatform(s);
      const n = s.activeAppUserList?.length ?? s.activeAppUsers ?? 0;
      setInApps(Math.max(0, n));
    } catch {
      /* keep last */
    }
  }, []);

  const heartbeat = useCallback(async () => {
    try {
      const snap = await sendPresenceHeartbeat();
      const n = snap.activeAppUserList?.length ?? snap.activeAppUsers ?? 0;
      if (n > 0) setInApps(n);
    } catch {
      /* server may not have presence yet */
    }
  }, []);

  useEffect(() => {
    void (async () => {
      const s = await getSession();
      setToken(s.token);
      setUserId(s.userId);
      setDisplayName(s.displayName);
    })();
    void refreshPlatform();
    const platformInterval = setInterval(refreshPlatform, 12_000);
    const hbInterval = setInterval(() => void heartbeat(), 20_000);
    void heartbeat();
    return () => {
      clearInterval(platformInterval);
      clearInterval(hbInterval);
    };
  }, [refreshPlatform, heartbeat]);

  const ingestChat = useCallback((row: AppChatMessage) => {
    setChat((prev) => {
      if (prev.some((m) => m.id === row.id)) return prev;
      return [...prev, row].sort((a, b) => a.at - b.at).slice(-80);
    });
  }, []);

  const onHangmanWs = useCallback((env: WsEnvelope) => {
    if (env.type === "update" && env.payload) {
      setHangman(env.payload as HangmanState);
    }
    if (env.type === "alltime" && env.payload) {
      const p = env.payload as { rows?: HangmanLeaderboardRow[]; leaderboard?: HangmanLeaderboardRow[] };
      setLeaderboard(p.rows || p.leaderboard || []);
    }
  }, []);

  const onPlatformWs = useCallback(
    (env: WsEnvelope) => {
      if (env.type === "app_chat" && env.payload) {
        ingestChat(env.payload as AppChatMessage);
      }
      if (env.type === "presence_update" && env.payload) {
        const p = env.payload as { activeAppUsers?: number; activeAppUserList?: unknown[] };
        const n = p.activeAppUserList?.length ?? p.activeAppUsers;
        if (typeof n === "number") setInApps(Math.max(0, n));
      }
    },
    [ingestChat]
  );

  useEffect(() => {
    const stopH = connectHangmanWs(onHangmanWs);
    const stopP = connectPlatformWs(onPlatformWs);
    return () => {
      stopH();
      stopP();
    };
  }, [onHangmanWs, onPlatformWs]);

  const sessionHandlers = useMemo(
    () => ({
      onSession: (t: string, u: string, d: string) => {
        setToken(t);
        setUserId(u);
        setDisplayName(d);
        void heartbeat();
      },
      onLogout: () => {
        setToken(null);
        setUserId("");
        setDisplayName("");
      },
    }),
    [heartbeat]
  );

  return (
    <div className="app-shell">
      <TopBar status={platform} inApps={inApps} />
      <main className="tab-content">
        {tab === "play" && (
          <PlayTab state={hangman} loggedIn={loggedIn} onState={setHangman} />
        )}
        {tab === "board" && (
          <BoardTab leaderboard={leaderboard} onLeaderboard={setLeaderboard} />
        )}
        {tab === "chat" && (
          <ChatTab
            messages={chat}
            onMessages={setChat}
            onIncoming={ingestChat}
            loggedIn={loggedIn}
            myUserId={userId}
          />
        )}
        {tab === "account" && (
          <AccountTab
            loggedIn={loggedIn}
            userId={userId}
            displayName={displayName}
            onSession={sessionHandlers.onSession}
            onLogout={sessionHandlers.onLogout}
          />
        )}
      </main>
      <TabBar active={tab} onChange={setTab} />
    </div>
  );
}
