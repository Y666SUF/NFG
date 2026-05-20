import React from "react";
import { motion } from "framer-motion";
import { Link } from "react-router-dom";
import { GAMES } from "./games";
import CrashGraph from "./animations/CrashGraph";
import WordwichTiles from "./animations/WordwichTiles";
import HangmanAnim from "./animations/HangmanAnim";
import WordwheelAnim from "./animations/WordwheelAnim";

const ANIMATIONS = {
  nfg_crash: CrashGraph,
  nfg_wordwich: WordwichTiles,
  nfg_hangman: HangmanAnim,
  nfg_wordwheel: WordwheelAnim,
};

const cardVariants = {
  hidden: { opacity: 0, y: 30 },
  show: (i) => ({
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, delay: i * 0.08, ease: [0.2, 0.8, 0.2, 1] },
  }),
};

export default function GamesGrid() {
  // Bento layout spans
  const spans = [
    "md:col-span-8 md:row-span-2", // crash large
    "md:col-span-4",               // wordwich
    "md:col-span-4",               // hangman
    "md:col-span-8",               // wordwheel wide
  ];

  return (
    <section id="games" data-testid="games-section" className="relative py-24 md:py-32 border-t border-white/5">
      <div className="mx-auto max-w-7xl px-6 md:px-10">
        <div className="flex items-end justify-between mb-12">
          <div>
            <span className="label-tag">// ARSENAL</span>
            <h2 className="font-display font-black uppercase text-4xl md:text-6xl tracking-tighter mt-3">
              THE <span className="neon-text-magenta">ARSENAL</span>
            </h2>
            <p className="mt-4 text-zinc-400 max-w-xl">
              Four signature games played live on TikTok with chat interaction. Predict. Solve. Spin. Stack.
              From crash simulation to word strategy, the viewer is the controller.
            </p>
          </div>
          <span className="hidden md:block font-mono text-xs text-zinc-500">// 04 NODES ONLINE</span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-12 gap-6 md:gap-7 auto-rows-[260px] md:auto-rows-[280px]">
          {GAMES.map((g, i) => (
            <motion.div
              key={g.id}
              custom={i}
              variants={cardVariants}
              initial="hidden"
              whileInView="show"
              viewport={{ once: true, amount: 0.2 }}
              data-testid={`game-card-${g.id}`}
              className={`tilt-card relative group rounded-2xl overflow-hidden border border-white/10 bg-black ${spans[i]}`}
              style={{ boxShadow: `0 0 0 1px rgba(255,255,255,0.04)` }}
            >
              <div className="absolute inset-0">
                {(() => {
                  const Anim = ANIMATIONS[g.id];
                  if (g.id === "nfg_crash") return <Anim variant="card" />;
                  return Anim ? <Anim accent={g.accent} /> : null;
                })()}
              </div>
              {/* gradient overlay */}
              <div className="absolute inset-0 pointer-events-none" style={{
                background:
                  "linear-gradient(180deg, rgba(5,5,10,0) 0%, rgba(5,5,10,0.2) 50%, rgba(5,5,10,0.92) 100%)",
              }} />
              {/* corner ticks */}
              <div className="pointer-events-none absolute inset-0">
                <span className="absolute top-3 left-3 h-3 w-3 border-l border-t" style={{ borderColor: g.accent }} />
                <span className="absolute top-3 right-3 h-3 w-3 border-r border-t" style={{ borderColor: g.accent }} />
                <span className="absolute bottom-3 left-3 h-3 w-3 border-l border-b" style={{ borderColor: g.accent }} />
                <span className="absolute bottom-3 right-3 h-3 w-3 border-r border-b" style={{ borderColor: g.accent }} />
              </div>

              {/* top tag */}
              <div className="absolute top-4 left-4 right-4 flex justify-between items-start z-10">
                <span
                  className="font-mono text-[0.6rem] uppercase tracking-[0.3em] px-2 py-1 rounded-full border"
                  style={{ borderColor: `${g.accent}66`, color: g.accent }}
                >
                  // {g.tag}
                </span>
                {g.stats?.live && (
                  <span className="font-mono text-[0.6rem] uppercase tracking-[0.3em] text-red-300 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-red-500 animate-pulse" />
                    LIVE
                  </span>
                )}
              </div>

              {/* bottom content */}
              <Link to={`/games/${g.slug}`} className="absolute inset-0 z-20" aria-label={`Open ${g.name}`} />

              <div className="absolute bottom-0 left-0 right-0 p-5 md:p-6 z-10">
                <h3 className="font-display font-black uppercase text-2xl md:text-3xl text-white tracking-tight leading-none">
                  {g.name.split(" ").map((w, idx) => (
                    <span
                      key={idx}
                      style={idx === 1 ? { color: g.accent, textShadow: `0 0 18px ${g.accent}88` } : {}}
                    >
                      {w}{idx === 0 ? " " : ""}
                    </span>
                  ))}
                </h3>
                <p className="mt-2 text-sm text-zinc-300/90 max-w-sm">{g.tagline}</p>

                <div className="mt-4 flex items-center justify-between">
                  <span className="font-mono text-xs text-zinc-500">→ VIEW GAME DETAILS</span>
                  <span
                    className="inline-flex items-center justify-center h-9 w-9 rounded-full border transition-all group-hover:translate-x-1"
                    style={{ borderColor: `${g.accent}88`, color: g.accent }}
                  >
                    ↗
                  </span>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
