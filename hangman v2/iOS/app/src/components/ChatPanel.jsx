import { useEffect, useRef, useState } from "react";
import { fetchChat, postChat } from "../lib/nfgApi";

function esc(s) {
  return String(s || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function fmtTime(at) {
  return new Date(Number(at) || Date.now()).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function ChatPanel({ session, registerAppend }) {
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState("");
  const [sending, setSending] = useState(false);
  const logRef = useRef(null);
  const seen = useRef(new Set());

  function append(row) {
    if (!row?.id || seen.current.has(row.id)) return;
    seen.current.add(row.id);
    setMessages((prev) => [...prev, row].slice(-120));
  }

  useEffect(() => {
    fetchChat(80)
      .then((body) => {
        const rows = Array.isArray(body.messages) ? body.messages : [];
        rows.sort((a, b) => Number(a.at) - Number(b.at));
        rows.forEach(append);
      })
      .catch((e) => setError(e.message));
  }, []);

  useEffect(() => {
    if (typeof registerAppend === "function") registerAppend(append);
    return () => {
      if (typeof registerAppend === "function") registerAppend(null);
    };
  }, [registerAppend]);

  useEffect(() => {
    if (!logRef.current) return;
    logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [messages]);

  async function send() {
    const text = draft.trim();
    if (!text || sending) return;
    if (!session?.userId) {
      setError("Link TikTok on live first (!link CODE).");
      return;
    }
    setSending(true);
    setError("");
    try {
      const out = await postChat(text);
      if (!out.ok) {
        setError(out.message || out.error || "Send failed");
      } else if (out.message) {
        append(out.message);
        setDraft("");
      }
    } catch (e) {
      setError(e.message);
    } finally {
      setSending(false);
    }
  }

  return (
    <section className="chat-panel panel">
      <header className="section-head">
        <h2>App chat</h2>
        <span className="sub">Shared across all NFG apps</span>
      </header>
      <div className="chat-log" ref={logRef}>
        {messages.length === 0 ? (
          <p className="muted center">No messages yet. Say hi to other app players.</p>
        ) : (
          messages.map((row) => (
            <article key={row.id} className="chat-msg">
              <div className="chat-who">
                {esc(row.displayName || row.userId)}
                {row.superFan ? <span className="sf"> ★</span> : null}
                {row.appLabel ? (
                  <span className="chat-app"> · {esc(row.appLabel)}</span>
                ) : row.clientApp && row.clientApp !== "nfg" ? (
                  <span className="chat-app"> · {esc(row.clientApp)}</span>
                ) : null}
              </div>
              <div className="chat-text">{esc(row.message)}</div>
              <div className="chat-time">{fmtTime(row.at)}</div>
            </article>
          ))
        )}
      </div>
      {!session?.userId ? (
        <p className="warn center">Link account in Account tab to send messages.</p>
      ) : (
        <div className="chat-compose">
          <input
            type="text"
            maxLength={240}
            placeholder="Message other app players…"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && send()}
          />
          <button type="button" className="btn" onClick={send} disabled={sending}>
            Send
          </button>
        </div>
      )}
      {error ? <p className="error">{error}</p> : null}
    </section>
  );
}
