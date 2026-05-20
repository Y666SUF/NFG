import { useEffect, useState } from "react";
import { fetchSession, pollLinkStatus, setToken, startLink } from "../lib/nfgApi";

export default function AccountPanel({ onSession }) {
  const [session, setSession] = useState(null);
  const [link, setLink] = useState(null);
  const [status, setStatus] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    fetchSession().then((body) => {
      if (body.ok && body.session) {
        setSession(body.session);
        onSession?.(body.session);
      }
    });
  }, [onSession]);

  useEffect(() => {
    if (!link?.code || link.status === "linked") return undefined;
    const timer = window.setInterval(async () => {
      const body = await pollLinkStatus(link.code);
      if (body.status === "linked" && body.token) {
        setToken(body.token);
        setLink({ ...link, status: "linked" });
        setStatus("Linked! You can guess from the keyboard.");
        const sess = await fetchSession();
        if (sess.ok && sess.session) {
          setSession(sess.session);
          onSession?.(sess.session);
        }
        window.clearInterval(timer);
      }
    }, 2000);
    return () => window.clearInterval(timer);
  }, [link, onSession]);

  async function beginLink() {
    setError("");
    const body = await startLink();
    if (!body.ok) {
      setError(body.error || "Could not start link");
      return;
    }
    setLink(body);
    setStatus(`On TikTok LIVE chat, type: ${body.tiktokCommand || `!link ${body.code}`}`);
  }

  return (
    <section className="account-panel panel">
      <header className="section-head">
        <h2>Account</h2>
      </header>
      {session?.userId ? (
        <p className="linked">
          Linked as <strong>@{session.userId}</strong>
          <br />
          <span className="muted">{session.displayName}</span>
        </p>
      ) : (
        <>
          <p className="muted">Link your TikTok on live so app guesses count as you.</p>
          <button type="button" className="btn btn-wide" onClick={beginLink}>
            Generate link code
          </button>
          {link?.code ? (
            <p className="link-code">
              Code: <span className="mono">{link.code}</span>
              <br />
              Command: <span className="mono">{link.tiktokCommand || `!link ${link.code}`}</span>
            </p>
          ) : null}
        </>
      )}
      {status ? <p className="status-line">{status}</p> : null}
      {error ? <p className="error">{error}</p> : null}

      <div className="legal-links">
        <a href="https://y666suf.com/privacy" target="_blank" rel="noopener noreferrer">
          Privacy Policy
        </a>
        <a href="https://y666suf.com/legal" target="_blank" rel="noopener noreferrer">
          Legal &amp; Compliance
        </a>
        <a href="https://y666suf.com/sideload#hangman" target="_blank" rel="noopener noreferrer">
          Install / update .ipa
        </a>
      </div>
    </section>
  );
}
