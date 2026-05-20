import type { PlatformStatus } from "../types";

interface Props {
  status: PlatformStatus | null;
  inApps: number;
}

export function TopBar({ status, inApps }: Props) {
  const live = status?.tiktokLive?.isLive === true || status?.tiktokLive?.state === "live";
  const count = inApps > 0 ? inApps : status?.activeAppUsers ?? 0;

  return (
    <header className="top-bar">
      <div className="live-badge">
        <span className={`live-dot ${live ? "on" : ""}`} />
        <span style={{ color: live ? "#ef4444" : "var(--muted)" }}>
          {live ? "LIVE" : "NOT LIVE"}
        </span>
        <span style={{ color: "var(--muted)" }}>•</span>
        <span style={{ color: "var(--accent)" }}>📱 {count} in apps</span>
      </div>
    </header>
  );
}
