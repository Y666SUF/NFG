import React from "react";

/** Shows live build size/date from /api/ipa/download-info */
export default function IpaMetaLine({ ipa, className = "" }) {
  if (!ipa) return null;
  if (!ipa.ok) {
    return (
      <p className={`font-mono text-xs text-amber-400/90 ${className}`}>
        Build not on server yet — check back after the PC syncs releases/ipa.
      </p>
    );
  }
  const parts = [];
  if (ipa.mb) parts.push(ipa.mb);
  if (ipa.updated) parts.push(`updated ${ipa.updated}`);
  if (!parts.length) return null;
  return (
    <p className={`font-mono text-xs text-zinc-500 ${className}`} data-testid="ipa-meta-line">
      Latest build: {parts.join(" · ")}
    </p>
  );
}
