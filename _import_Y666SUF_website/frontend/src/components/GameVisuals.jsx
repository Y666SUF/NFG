import React from "react";

export function CrashGraph({ compact = false, className = "" }) {
  const height = compact ? 120 : 180;
  return (
    <div
      data-testid={compact ? "crash-graph-compact" : "crash-graph"}
      className={`rounded-2xl border border-cyan-400/25 bg-black/60 p-4 ${className}`}
    >
      <div className="flex items-center justify-between font-mono text-[0.65rem] uppercase tracking-[0.3em] text-zinc-400">
        <span>NFG Crash graph</span>
        <span className="text-red-400">Looping</span>
      </div>
      <svg viewBox="0 0 420 200" className="mt-4 w-full" style={{ height }}>
        <defs>
          <linearGradient id="crashLine" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#00F0FF" />
            <stop offset="70%" stopColor="#00F0FF" />
            <stop offset="100%" stopColor="#FF003C" />
          </linearGradient>
        </defs>
        <line x1="20" y1="170" x2="400" y2="170" stroke="#2c2c3f" strokeWidth="1" />
        <line x1="20" y1="20" x2="20" y2="170" stroke="#2c2c3f" strokeWidth="1" />
        <path
          d="M20 165 C100 155, 160 130, 220 92 S320 45, 360 40 L392 170"
          fill="none"
          stroke="url(#crashLine)"
          strokeWidth="4"
          strokeLinecap="round"
          className="graph-curve"
        />
        <circle cx="392" cy="170" r="6" fill="#FF003C" className="graph-crash-dot" />
        <text x="308" y="56" fill="#00F0FF" fontSize="13" fontFamily="JetBrains Mono">
          18.42x
        </text>
        <text x="364" y="192" fill="#FF003C" fontSize="12" fontFamily="JetBrains Mono">
          CRASH!
        </text>
      </svg>
    </div>
  );
}

export function WordwichTiles({ compact = false, className = "" }) {
  const letters = ["W", "O", "R", "D", "W", "I", "C", "H"];
  return (
    <div
      data-testid={compact ? "wordwich-tiles-compact" : "wordwich-tiles"}
      className={`rounded-2xl border border-fuchsia-400/25 bg-black/60 p-4 ${className}`}
    >
      <div className="font-mono text-[0.65rem] uppercase tracking-[0.3em] text-zinc-400">Wordwich tiles</div>
      <div className="mt-4 grid grid-cols-4 gap-2">
        {letters.map((letter, idx) => (
          <div
            key={`${letter}-${idx}`}
            className="word-tile h-12 rounded-md border border-fuchsia-400/35 bg-fuchsia-500/10 flex items-center justify-center font-display font-black text-lg"
            style={{ animationDelay: `${idx * 120}ms` }}
          >
            {letter}
          </div>
        ))}
      </div>
    </div>
  );
}

export function HangmanAnim({ compact = false, className = "" }) {
  return (
    <div
      data-testid={compact ? "hangman-anim-compact" : "hangman-anim"}
      className={`rounded-2xl border border-purple-400/25 bg-black/60 p-4 ${className}`}
    >
      <div className="font-mono text-[0.65rem] uppercase tracking-[0.3em] text-zinc-400">Hangman</div>
      <svg viewBox="0 0 220 160" className="mt-4 w-full h-36">
        <line x1="24" y1="140" x2="122" y2="140" stroke="#8A2BE2" strokeWidth="4" />
        <line x1="44" y1="140" x2="44" y2="18" stroke="#8A2BE2" strokeWidth="4" />
        <line x1="44" y1="18" x2="116" y2="18" stroke="#8A2BE2" strokeWidth="4" />
        <line x1="116" y1="18" x2="116" y2="34" stroke="#8A2BE2" strokeWidth="4" />
        <circle cx="116" cy="52" r="16" stroke="#00F0FF" fill="transparent" strokeWidth="4" className="hang-head" />
        <line x1="116" y1="68" x2="116" y2="104" stroke="#00F0FF" strokeWidth="4" className="hang-body" />
        <line x1="116" y1="80" x2="96" y2="94" stroke="#00F0FF" strokeWidth="4" className="hang-arm-left" />
        <line x1="116" y1="80" x2="136" y2="94" stroke="#00F0FF" strokeWidth="4" className="hang-arm-right" />
      </svg>
    </div>
  );
}

export function WordwheelAnim({ compact = false, className = "" }) {
  const ring = ["W", "O", "R", "D", "W", "H", "E", "E", "L"];
  return (
    <div
      data-testid={compact ? "wordwheel-anim-compact" : "wordwheel-anim"}
      className={`rounded-2xl border border-cyan-400/25 bg-black/60 p-4 ${className}`}
    >
      <div className="font-mono text-[0.65rem] uppercase tracking-[0.3em] text-zinc-400">Wordwheel spin</div>
      <div className="mt-4 flex items-center justify-center">
        <div className="relative h-36 w-36 rounded-full border border-cyan-300/50 wordwheel-spin">
          {ring.map((letter, idx) => {
            const angle = (360 / ring.length) * idx;
            return (
              <span
                key={`${letter}-${idx}`}
                className="absolute left-1/2 top-1/2 font-display font-black text-cyan-300"
                style={{
                  transform: `rotate(${angle}deg) translateY(-56px) rotate(${-angle}deg)`,
                  transformOrigin: "center center",
                }}
              >
                {letter}
              </span>
            );
          })}
          <span className="absolute inset-0 m-auto h-3 w-3 rounded-full bg-fuchsia-400 shadow-[0_0_12px_rgba(255,0,60,0.8)]" />
        </div>
      </div>
    </div>
  );
}

