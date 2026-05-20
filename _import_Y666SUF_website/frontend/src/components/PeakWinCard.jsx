import React from "react";
import { formatMultiplier, formatUsername, formatWinAmount } from "../hooks/useFeaturedStats";

/**
 * 24h highest win (points) — player identity + cash-out multiplier as secondary detail.
 */
export default function PeakWinCard({ win, className = "" }) {
  const winAmount = formatWinAmount(win?.payout);
  const mult = formatMultiplier(win?.multiplier);
  const hasWinner = win && (win.displayName || win.username);

  return (
    <div
      data-testid="featured-stat-peak"
      className={`rounded-xl border border-fuchsia-400/30 bg-gradient-to-br from-black/80 via-[#0a0612] to-black/70 p-4 ${className}`}
      style={{ boxShadow: "inset 0 0 0 1px rgba(255,0,120,0.06), 0 0 24px -12px rgba(255,0,120,0.25)" }}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="text-zinc-500 uppercase text-[0.6rem] tracking-[0.28em] font-mono">
            Highest win · 24h
          </div>
          {hasWinner ? (
            <>
              <div className="mt-2 font-display font-bold text-white text-base truncate leading-tight">
                {win.displayName || win.username}
              </div>
              {win.username && win.displayName && win.displayName !== win.username ? (
                <div className="mt-0.5 font-mono text-[0.65rem] text-fuchsia-300/90 truncate">
                  {formatUsername(win.username)}
                </div>
              ) : win.username ? (
                <div className="mt-0.5 font-mono text-[0.65rem] text-zinc-500 truncate">
                  {formatUsername(win.username)}
                </div>
              ) : null}
              <div className="mt-1.5 font-mono text-[0.65rem] text-zinc-500 tabular-nums">
                Cashed at {mult}
              </div>
            </>
          ) : (
            <div className="mt-2 text-sm text-zinc-500 font-mono">No wins recorded in the last 24h</div>
          )}
        </div>
        <div className="text-right shrink-0">
          <div className="font-display font-black text-xl md:text-2xl neon-text-cyan leading-tight tabular-nums">
            {winAmount}
          </div>
          {hasWinner && (
            <div className="mt-1 font-mono text-[0.6rem] uppercase tracking-[0.2em] text-zinc-500">
              points won
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
