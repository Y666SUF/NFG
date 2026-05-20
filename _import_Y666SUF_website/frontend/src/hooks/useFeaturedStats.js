import { useCallback, useEffect, useState } from "react";

function isDevFrontendServer() {
  return typeof window !== "undefined" && window.location.port === "3000";
}

function featuredStatsUrl() {
  if (isDevFrontendServer()) {
    const base = String(process.env.REACT_APP_BACKEND_URL || "http://127.0.0.1:3847").replace(
      /\/+$/,
      ""
    );
    return `${base}/api/website/featured`;
  }
  return "/api/website/featured";
}

export function formatViewerCount(n) {
  if (n == null || !Number.isFinite(Number(n))) return "—";
  const v = Math.floor(Number(n));
  if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1).replace(/\.0$/, "")}M`;
  if (v >= 1000) return `${(v / 1000).toFixed(1).replace(/\.0$/, "")}K`;
  return String(v);
}

export function formatMultiplier(n) {
  if (n == null || !Number.isFinite(Number(n)) || Number(n) <= 0) return "—";
  return `${Number(n).toFixed(2)}×`;
}

export function formatPayoutPoints(n) {
  if (n == null || !Number.isFinite(Number(n)) || Number(n) <= 0) return "—";
  return `+${Math.floor(Number(n)).toLocaleString()} pts`;
}

/** Compact win amount for stat cards and graph overlays. */
export function formatWinAmount(n, { compact = false } = {}) {
  if (n == null || !Number.isFinite(Number(n)) || Number(n) <= 0) return "—";
  const v = Math.floor(Number(n));
  if (compact) {
    if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1).replace(/\.0$/, "")}M`;
    if (v >= 1000) return `${(v / 1000).toFixed(1).replace(/\.0$/, "")}K`;
    return String(v);
  }
  return `${v.toLocaleString()} pts`;
}

export function formatUsername(user) {
  const u = String(user || "").trim();
  if (!u) return "";
  return u.startsWith("@") ? u : `@${u}`;
}

export function liveStatusLabel(stats) {
  if (!stats) return "…";
  if (stats.isLive) return "LIVE";
  const s = String(stats.liveStatus || "").toLowerCase();
  if (s === "waiting") return "STANDBY";
  if (s === "offline") return "OFFLINE";
  if (s === "disabled") return "OFFLINE";
  return "OFFLINE";
}

export function liveStatusClass(stats) {
  if (!stats) return "text-zinc-400";
  if (stats.isLive) return "text-emerald-300";
  if (String(stats.liveStatus || "").toLowerCase() === "waiting") return "text-amber-300";
  return "text-zinc-400";
}

export default function useFeaturedStats(pollMs = 8000) {
  const [stats, setStats] = useState(null);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    try {
      const res = await fetch(featuredStatsUrl(), {
        cache: "no-store",
        credentials: "same-origin",
        headers: { Accept: "application/json" },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setStats(data);
      setError(null);
      return data;
    } catch (e) {
      console.error("[featured-stats]", e);
      setError(e);
      return null;
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    let timer = null;

    const schedule = async () => {
      const data = await load();
      if (cancelled) return;
      const interval = data?.isLive || data?.phase === "running" ? 3000 : pollMs;
      timer = setTimeout(schedule, interval);
    };

    schedule();
    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
    };
  }, [load, pollMs]);

  return { stats, error, refresh: load };
}
