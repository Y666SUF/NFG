import { useCallback, useState } from "react";
import { ApiError, linkStatus, startLink } from "../lib/api";
import { apiUrl, TIKTOK_HANDLE } from "../lib/config";
import { clearSession, saveSession } from "../lib/storage";

interface Props {
  loggedIn: boolean;
  userId: string;
  displayName: string;
  onSession: (token: string, userId: string, displayName: string) => void;
  onLogout: () => void;
}

export function AccountTab({
  loggedIn,
  userId,
  displayName,
  onSession,
  onLogout,
}: Props) {
  const [code, setCode] = useState("");
  const [command, setCommand] = useState("!link");
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [polling, setPolling] = useState(false);

  const beginLink = async () => {
    setError(null);
    setStatus(null);
    try {
      const resp = await startLink();
      setCode(resp.code);
      setCommand(resp.tiktokCommand || `!link ${resp.code}`);
      setStatus(`Comment ${resp.tiktokCommand || command} on @${TIKTOK_HANDLE} LIVE from your TikTok.`);
      pollLink(resp.code, resp.expiresInSeconds || 120);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Could not start link");
    }
  };

  const pollLink = useCallback(
    async (linkCode: string, expiresIn: number) => {
      setPolling(true);
      const end = Date.now() + expiresIn * 1000;
      while (Date.now() < end) {
        await new Promise((r) => setTimeout(r, 2000));
        try {
          const s = await linkStatus(linkCode);
          if (s.status === "verified" && s.token && s.userId) {
            await saveSession(s.token, s.userId, s.displayName || s.userId);
            onSession(s.token, s.userId, s.displayName || s.userId);
            setStatus(`Linked as @${s.userId}`);
            setPolling(false);
            return;
          }
          if (s.status === "expired") break;
        } catch {
          /* retry */
        }
      }
      setPolling(false);
      setStatus("Link timed out — try again on LIVE.");
    },
    [onSession, command]
  );

  const logout = async () => {
    await clearSession();
    onLogout();
    setCode("");
    setStatus(null);
  };

  const open = (path: string) => window.open(apiUrl(path), "_blank");

  return (
    <div>
      <h2 style={{ margin: "0 0 8px", fontSize: 18 }}>Account</h2>

      {error && <div className="error-banner" style={{ marginBottom: 12 }}>{error}</div>}

      {loggedIn ? (
        <div className="panel" style={{ marginBottom: 16 }}>
          <p style={{ margin: "0 0 4px", fontWeight: 700 }}>{displayName}</p>
          <p className="muted" style={{ margin: 0 }}>@{userId}</p>
          <button
            type="button"
            className="btn-primary"
            style={{ marginTop: 12, width: "100%", background: "var(--panel2)", color: "var(--danger)" }}
            onClick={logout}
          >
            Sign out
          </button>
        </div>
      ) : (
        <div className="panel" style={{ marginBottom: 16 }}>
          <p className="muted">Link TikTok while @y666.suf is LIVE to play and chat.</p>
          <button
            type="button"
            className="btn-primary"
            style={{ width: "100%", marginTop: 12 }}
            disabled={polling}
            onClick={beginLink}
          >
            {polling ? "Waiting for comment…" : "Link TikTok"}
          </button>
          {code && (
            <p style={{ marginTop: 12, fontFamily: "monospace", color: "var(--accent)" }}>{command}</p>
          )}
        </div>
      )}

      {status && <p className="muted">{status}</p>}

      <div className="panel">
        <h3 style={{ margin: "0 0 10px", fontSize: 14 }}>Legal & install</h3>
        <button type="button" className="btn-primary" style={{ width: "100%", marginBottom: 8 }} onClick={() => open("/privacy")}>
          Privacy Policy
        </button>
        <button type="button" className="btn-primary" style={{ width: "100%", marginBottom: 8 }} onClick={() => open("/legal")}>
          Legal & compliance
        </button>
        <button type="button" className="btn-primary" style={{ width: "100%" }} onClick={() => open("/sideload#hangman")}>
          Sideload help
        </button>
        <p className="muted" style={{ marginTop: 12, marginBottom: 0 }}>
          Virtual points only. No cash-out. Word game — 13+.
        </p>
      </div>
    </div>
  );
}
