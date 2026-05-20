import { useEffect, useRef, useState } from "react";
import { ApiError, fetchChatHistory, sendChatMessage } from "../lib/api";
import { SuperFanBadge } from "../components/SuperFanBadge";
import type { AppChatMessage } from "../types";

interface Props {
  messages: AppChatMessage[];
  onMessages: (m: AppChatMessage[]) => void;
  onIncoming: (m: AppChatMessage) => void;
  loggedIn: boolean;
  myUserId: string;
}

export function ChatTab({ messages, onMessages, onIncoming, loggedIn, myUserId }: Props) {
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const rows = await fetchChatHistory();
        if (!cancelled) onMessages(rows);
      } catch (e) {
        if (!cancelled) setError(e instanceof ApiError ? e.message : "Chat unavailable");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [onMessages]);

  const send = async () => {
    const text = draft.trim();
    if (!text || !loggedIn) return;
    if (text.startsWith("!")) {
      setError("Commands are not allowed in app chat.");
      return;
    }
    setDraft("");
    setError(null);
    try {
      const row = await sendChatMessage(text);
      onIncoming(row);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Send failed");
    }
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <h2 style={{ margin: "0 0 4px", fontSize: 18 }}>App Chat</h2>
      <p className="muted" style={{ marginTop: 0, marginBottom: 12 }}>
        Shared across all NFG apps
      </p>

      {error && <div className="error-banner" style={{ marginBottom: 8 }}>{error}</div>}

      <div className="chat-list" style={{ flex: 1 }}>
        {messages.length === 0 && (
          <p className="muted" style={{ textAlign: "center" }}>Say hi to other players.</p>
        )}
        {messages.map((m) => {
          const mine = m.userId.toLowerCase() === myUserId.toLowerCase();
          return (
            <div
              key={m.id}
              className={`chat-bubble ${mine ? "mine" : ""}`}
              style={{ alignSelf: mine ? "flex-end" : "flex-start" }}
            >
              <div style={{ display: "flex", gap: 6, alignItems: "center", marginBottom: 4 }}>
                <span style={{ fontSize: 11, fontWeight: 700, color: mine ? "var(--accent)" : "var(--muted)" }}>
                  {m.displayName}
                </span>
                <SuperFanBadge superFan={m.superFan} level={m.superFanLevel} />
              </div>
              <div>{m.message}</div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={loggedIn ? "Message players…" : "Link TikTok first"}
          disabled={!loggedIn}
          style={{
            flex: 1,
            padding: "10px 12px",
            borderRadius: 10,
            border: "1px solid var(--border)",
            background: "var(--panel2)",
            color: "var(--text)",
          }}
          onKeyDown={(e) => e.key === "Enter" && send()}
        />
        <button type="button" className="btn-primary" disabled={!loggedIn} onClick={send}>
          Send
        </button>
      </div>
    </div>
  );
}
