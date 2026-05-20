export default function OnlinePanel({ users = [], count = 0 }) {
  return (
    <section className="online-panel panel">
      <header className="section-head">
        <h2>Online now</h2>
        <span className="pill ok">{count} in apps</span>
      </header>
      <ul className="online-list">
        {users.length === 0 ? (
          <li className="muted">No app users detected yet.</li>
        ) : (
          users.map((u) => (
            <li key={`${u.userId}-${u.clientApp || "nfg"}`}>
              <span className="online-name">{u.displayName || u.userId}</span>
              <span className="online-meta">
                {u.isGuest ? "guest" : `@${u.username || u.userId}`}
                {u.clientApp ? ` · ${u.clientApp}` : ""}
              </span>
            </li>
          ))
        )}
      </ul>
    </section>
  );
}
