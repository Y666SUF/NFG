import React, { useEffect, useState } from "react";
import { formatMultiplier, formatWinAmount } from "../../hooks/useFeaturedStats";

/**
 * Animated crash graph for NFG Crash.
 * When `stats` is passed (from /api/website/featured), overlays use live TikTok + game data.
 */
export default function CrashGraph({ variant = "hero", stats = null }) {
  const [cycle, setCycle] = useState(0);

  const DURATION = 5200;
  const CLIMB_END = 0.78;
  const CRASH_END = 0.86;
  const PAUSE_END = 1.0;

  const useLiveRound = stats?.phase === "running" && Number.isFinite(Number(stats?.currentMultiplier));
  const liveMult = useLiveRound ? Number(stats.currentMultiplier) : null;

  useEffect(() => {
    if (useLiveRound) return undefined;
    let raf;
    const start = performance.now();
    const tick = (now) => {
      const t = ((now - start) % DURATION) / DURATION;
      setCycle(t);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [useLiveRound]);

  const climbT = useLiveRound ? Math.min((liveMult - 1) / 23.62, 1) : Math.min(cycle / CLIMB_END, 1);
  const displayMult = useLiveRound
    ? liveMult.toFixed(2)
    : (1 + Math.pow(Math.min(cycle / CLIMB_END, 1), 1.8) * 23.62).toFixed(2);

  const crashing = !useLiveRound && cycle >= CLIMB_END && cycle < CRASH_END;
  const crashed = !useLiveRound && cycle >= CRASH_END && cycle < PAUSE_END;

  const W = 400;
  const H = 220;

  const samples = 50;
  let d = `M 8 ${H - 18}`;
  const lastClimbPoint = { x: 8, y: H - 18 };
  for (let i = 1; i <= samples; i++) {
    const p = i / samples;
    if (p > climbT) break;
    const x = 8 + p * (W - 80);
    const y = H - 18 - Math.pow(p, 1.6) * (H - 60);
    d += ` L ${x.toFixed(1)} ${y.toFixed(1)}`;
    lastClimbPoint.x = x;
    lastClimbPoint.y = y;
  }

  let crashPath = "";
  if (crashing || crashed) {
    const crashT = Math.min((cycle - CLIMB_END) / (CRASH_END - CLIMB_END), 1);
    const fallY = lastClimbPoint.y + crashT * (H - 18 - lastClimbPoint.y);
    crashPath = `M ${lastClimbPoint.x.toFixed(1)} ${lastClimbPoint.y.toFixed(1)} L ${lastClimbPoint.x.toFixed(1)} ${fallY.toFixed(1)}`;
  }

  const headX = lastClimbPoint.x;
  const headY = crashing || crashed ? H - 18 : lastClimbPoint.y;

  const lineColor = crashing || crashed ? "#FF003C" : "#00F0FF";
  const glowColor = lineColor;

  const isLive = !!stats?.isLive;
  const roundLabel = stats?.roundId
    ? String(stats.roundId).padStart(4, "0")
    : String(Math.floor((Date.now() / DURATION) % 9999)).padStart(4, "0");
  const topWinLabel = formatWinAmount(stats?.dayBestWin?.payout ?? stats?.highestWin24h, { compact: true });

  return (
    <div className="relative w-full h-full">
      <svg
        viewBox={`0 0 ${W} ${H}`}
        preserveAspectRatio="none"
        className="absolute inset-0 w-full h-full"
        style={{ filter: `drop-shadow(0 0 12px ${glowColor}88)` }}
      >
        <g stroke="rgba(255,255,255,0.05)" strokeWidth="1">
          {[0.2, 0.4, 0.6, 0.8].map((p) => (
            <line key={`h${p}`} x1="0" y1={H * p} x2={W} y2={H * p} />
          ))}
          {[0.25, 0.5, 0.75].map((p) => (
            <line key={`v${p}`} x1={W * p} y1="0" x2={W * p} y2={H} />
          ))}
        </g>

        <path
          d={d}
          fill="none"
          stroke={lineColor}
          strokeWidth={variant === "hero" ? 3 : 2.2}
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        <path
          d={`${d} L ${lastClimbPoint.x.toFixed(1)} ${H} L 8 ${H} Z`}
          fill={`url(#crash-grad-${variant})`}
          opacity={crashing || crashed ? 0.15 : 0.28}
        />

        {(crashing || crashed) && (
          <path
            d={crashPath}
            stroke="#FF003C"
            strokeWidth="3"
            strokeLinecap="round"
            strokeDasharray="4 3"
          />
        )}

        <circle
          cx={headX}
          cy={headY}
          r={crashing ? 7 : 5}
          fill={lineColor}
          opacity={crashed ? 0.4 : 1}
        >
          {!crashing && !crashed && !useLiveRound && (
            <animate attributeName="r" values="4;7;4" dur="1.2s" repeatCount="indefinite" />
          )}
        </circle>

        <defs>
          <linearGradient id={`crash-grad-${variant}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={lineColor} stopOpacity="0.8" />
            <stop offset="100%" stopColor={lineColor} stopOpacity="0" />
          </linearGradient>
        </defs>
      </svg>

      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
        <div className="text-center">
          <div
            className="font-display font-black tracking-tighter leading-none"
            style={{
              fontSize: variant === "hero" ? "clamp(3rem, 8vw, 6rem)" : "2.2rem",
              color: crashing || crashed ? "#FF003C" : "#fff",
              textShadow:
                crashing || crashed
                  ? "0 0 30px rgba(255,0,60,0.8), 0 0 60px rgba(255,0,60,0.4)"
                  : "0 0 24px rgba(0,240,255,0.6)",
              transition: "color .15s linear",
            }}
          >
            {crashed ? "CRASHED" : crashing ? "CRASH!" : `${displayMult}×`}
          </div>
          {variant === "hero" && (
            <div className="mt-2 font-mono text-[0.65rem] tracking-[0.3em] text-zinc-500 uppercase">
              {useLiveRound
                ? "live round in progress"
                : crashed
                  ? "round complete · next in"
                  : crashing
                    ? "void wins"
                    : "multiplier climbing"}
            </div>
          )}
        </div>
      </div>

      <div className="absolute top-3 left-3 right-3 flex justify-between items-start text-[0.6rem] font-mono uppercase tracking-[0.25em] pointer-events-none">
        <span className={`flex items-center gap-1.5 ${isLive ? "text-cyan-400" : "text-zinc-500"}`}>
          {isLive && <span className="h-1.5 w-1.5 rounded-full bg-red-500 animate-pulse" />}
          {isLive ? "LIVE" : "OFFLINE"}
        </span>
        <span className="text-zinc-500">ROUND · {roundLabel}</span>
      </div>
      <div className="absolute bottom-3 left-3 right-3 flex justify-between items-end text-[0.6rem] font-mono uppercase tracking-[0.25em] pointer-events-none">
        <span className="text-zinc-500">TOP WIN · {topWinLabel}</span>
        <span className="text-fuchsia-400">CASH-OUT WINDOW</span>
      </div>
    </div>
  );
}
