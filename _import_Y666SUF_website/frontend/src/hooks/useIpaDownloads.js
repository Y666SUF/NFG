import { useEffect, useState } from "react";

function formatMb(bytes) {
  const n = Number(bytes) || 0;
  if (n <= 0) return null;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

function formatUpdated(iso) {
  if (!iso) return null;
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  } catch {
    return null;
  }
}

export default function useIpaDownloads() {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    fetch("/api/ipa/download-info", { cache: "no-store" })
      .then((res) => {
        if (!res.ok) throw new Error(`download-info ${res.status}`);
        return res.json();
      })
      .then((body) => {
        if (!cancelled) setData(body && body.apps ? body : null);
      })
      .catch((e) => {
        if (!cancelled) setError(e.message || "unavailable");
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const crash = data?.apps?.crash;
  const hangman = data?.apps?.hangman;

  return {
    loading: !data && !error,
    error,
    crash: crash
      ? {
          ok: !!crash.ok,
          href: crash.downloadUrl || "/download/nfg-crash.ipa",
          mb: formatMb(crash.sizeBytes),
          updated: formatUpdated(crash.updatedAt),
        }
      : { ok: false, href: "/download/nfg-crash.ipa", mb: null, updated: null },
    hangman: hangman
      ? {
          ok: !!hangman.ok,
          href: hangman.downloadUrl || "/download/nfg-hangman.ipa",
          mb: formatMb(hangman.sizeBytes),
          updated: formatUpdated(hangman.updatedAt),
        }
      : { ok: false, href: "/download/nfg-hangman.ipa", mb: null, updated: null },
  };
}
