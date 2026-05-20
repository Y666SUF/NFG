import React from "react";
import Scene3D from "./Scene3D";

export default function LiveSection() {
  return (
    <section id="live" data-testid="live-section" className="relative py-24 md:py-32 overflow-hidden border-t border-white/5">
      <div className="absolute inset-0 opacity-60">
        <Scene3D intensity="ambient" />
      </div>
      <div className="absolute inset-0" style={{
        background: "linear-gradient(180deg, #05050A 0%, transparent 30%, transparent 70%, #05050A 100%)"
      }} />

      <div className="relative mx-auto max-w-5xl px-6 md:px-10 text-center">
        <span className="label-tag text-fuchsia-400">// CONTROL DECK</span>
        <h2 className="mt-4 font-display font-black uppercase text-4xl md:text-7xl tracking-tighter">
          THE CHAT IS THE <span className="neon-text-magenta">CONTROLLER</span>
        </h2>
        <p className="mt-6 text-zinc-300/90 max-w-2xl mx-auto">
          Every title is built around live interaction. Drop a comment, send a gift, or smash a like —
          your input can shape crash rounds and word-game momentum in real time.
          Join @y666.suf and become part of the run.
        </p>

        <div className="mt-10 inline-flex flex-col items-center gap-4">
          <a
            href="https://www.tiktok.com/@y666.suf"
            target="_blank" rel="noopener noreferrer"
            data-testid="live-cta"
            className="btn-neon text-base"
          >
            ▶ Watch @y666.suf Live
          </a>
          <span className="font-mono text-xs text-zinc-500 uppercase tracking-[0.3em]">
            Streams nightly · 7PM GMT
          </span>
        </div>

        {/* circular badge */}
        <div className="mt-16 mx-auto h-56 w-56 relative flex items-center justify-center">
          <div className="absolute inset-0 rounded-full border border-cyan-400/30" />
          <div className="absolute inset-3 rounded-full border border-fuchsia-500/20" />
          <svg className="absolute inset-0 spin-slow" viewBox="0 0 200 200">
            <defs>
              <path id="circle-text" d="M 100,100 m -82,0 a 82,82 0 1,1 164,0 a 82,82 0 1,1 -164,0" />
            </defs>
            <text fontFamily="JetBrains Mono" fontSize="11" fill="#00F0FF" letterSpacing="6">
              <textPath href="#circle-text">
                · Y666.SUF · GAME STUDIO · NFG SIGNAL · TIKTOK LIVE · ENTER THE VOID
              </textPath>
            </text>
          </svg>
          <div className="text-center">
            <div className="font-display font-black text-4xl neon-text-cyan">666</div>
            <div className="font-mono text-[0.6rem] tracking-[0.3em] text-zinc-400 mt-1">SIGNAL</div>
          </div>
        </div>
      </div>
    </section>
  );
}
