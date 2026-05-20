import React from "react";
import { motion } from "framer-motion";
import { Link } from "react-router-dom";
import { GAMES } from "./games";
import CrashGraph from "./animations/CrashGraph";
import PeakWinCard from "./PeakWinCard";
import useFeaturedStats, {
  formatViewerCount,
  liveStatusClass,
  liveStatusLabel,
} from "../hooks/useFeaturedStats";

export default function FeaturedGame() {
  const game = GAMES[0]; // NFG Crash
  const { stats } = useFeaturedStats(8000);

  const viewers = formatViewerCount(stats?.viewerCount);
  const statusText = liveStatusLabel(stats);
  const statusClass = liveStatusClass(stats);
  const dayBestWin = stats?.dayBestWin || null;

  return (
    <section id="featured" data-testid="featured-section" className="relative py-24 md:py-32">
      <div className="mx-auto max-w-7xl px-6 md:px-10">
        <div className="flex items-end justify-between mb-10 md:mb-14">
          <div>
            <span data-testid="featured-tag" className="label-tag">// LATEST RELEASE — 01</span>
            <h2 className="font-display font-black uppercase text-4xl md:text-6xl tracking-tighter mt-3">
              FEATURED <span className="neon-text-cyan">DROP</span>
            </h2>
          </div>
          <span className="hidden md:block font-mono text-xs text-zinc-500">/ 04 GAMES IN ROTATION</span>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.7 }}
          data-testid="featured-card"
          className="relative grid md:grid-cols-12 gap-8 md:gap-10 items-center rounded-3xl border border-cyan-400/30 bg-gradient-to-br from-black via-[#080813] to-black p-6 md:p-10 overflow-hidden"
          style={{ boxShadow: "0 0 60px -20px rgba(0,240,255,0.35), inset 0 0 0 1px rgba(0,240,255,0.08)" }}
        >
          <div className="pointer-events-none absolute -top-20 -right-20 h-72 w-72 rounded-full" style={{ background: "radial-gradient(closest-side, rgba(0,240,255,0.25), transparent)" }} />
          <div className="pointer-events-none absolute -bottom-24 -left-24 h-80 w-80 rounded-full" style={{ background: "radial-gradient(closest-side, rgba(255,0,60,0.18), transparent)" }} />

          <div className="md:col-span-7 relative">
            <div className="relative aspect-[4/3] md:aspect-[16/11] rounded-2xl overflow-hidden border border-cyan-400/30 bg-black grain-overlay">
              <CrashGraph variant="hero" stats={stats} />
              <div
                className="absolute inset-0 pointer-events-none"
                style={{
                  background: "radial-gradient(ellipse at center, transparent 55%, rgba(5,5,10,0.6))",
                }}
              />
            </div>
          </div>

          <div className="md:col-span-5 relative">
            <span className="label-tag text-fuchsia-400">// {game.tag}</span>
            <h3
              data-testid="featured-title"
              className="font-display font-black uppercase mt-3 text-4xl md:text-5xl leading-[0.95] tracking-tight"
            >
              NFG <span className="neon-text-cyan">CRASH</span>
            </h3>
            <p className="mt-5 text-zinc-300/90 max-w-md">
              Companion app for TikTok LIVE crash-style rounds. Time your cash-out in a number simulator,
              earn virtual points, chat with the room, and watch the leaderboard update in real time.
              iPhone install available.
            </p>
            <p className="mt-2 text-xs text-zinc-500 max-w-md">
              Virtual points only — no cash-out, no withdrawals, no real-money gambling.
            </p>

            <div className="mt-6 space-y-3 font-mono text-xs">
              <ul className="grid grid-cols-2 gap-3">
                <li
                  className="rounded-lg border border-cyan-400/25 bg-black/60 p-3"
                  data-testid="featured-stat-viewers"
                >
                  <div className="text-zinc-500 uppercase text-[0.6rem] tracking-widest">Viewers</div>
                  <div className="text-white text-lg font-semibold">{viewers}</div>
                </li>
                <li
                  className="rounded-lg border border-purple-400/25 bg-black/60 p-3"
                  data-testid="featured-stat-status"
                >
                  <div className="text-zinc-500 uppercase text-[0.6rem] tracking-widest">Status</div>
                  <div className={`text-lg font-semibold ${statusClass}`}>{statusText}</div>
                </li>
              </ul>
              <PeakWinCard win={dayBestWin} />
            </div>

            <div className="mt-8 flex flex-wrap gap-4">
              <Link to="/games/nfg-crash" data-testid="featured-cta-play" className="btn-neon">
                ► See Game Details
              </Link>
              <a href="/#install" data-testid="featured-cta-install" className="btn-ghost">
                ◇ Install on iPhone
              </a>
              <a href="/#leaderboard" data-testid="featured-cta-leaderboard" className="btn-ghost">
                ◇ Leaderboard
              </a>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
