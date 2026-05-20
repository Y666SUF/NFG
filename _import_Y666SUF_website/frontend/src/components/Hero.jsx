import React from "react";
import { motion } from "framer-motion";
import { Link } from "react-router-dom";
import Scene3D from "./Scene3D";

export default function Hero() {
  return (
    <section id="top" data-testid="hero-section" className="relative w-full h-[100svh] min-h-[640px] overflow-hidden">
      {/* 3D background */}
      <div className="absolute inset-0">
        <Scene3D intensity="hero" />
      </div>
      {/* Vignette */}
      <div className="pointer-events-none absolute inset-0" style={{
        background:
          "radial-gradient(ellipse at center, transparent 35%, rgba(5,5,10,0.55) 70%, #05050A 100%)",
      }} />
      <div className="pointer-events-none absolute inset-0 scan-lines opacity-40" />

      {/* Side rails */}
      <div className="pointer-events-none absolute left-0 top-0 h-full w-px bg-gradient-to-b from-transparent via-cyan-400/40 to-transparent" />
      <div className="pointer-events-none absolute right-0 top-0 h-full w-px bg-gradient-to-b from-transparent via-fuchsia-500/40 to-transparent" />

      {/* Vertical ticker */}
      <div className="absolute left-6 top-1/2 -translate-y-1/2 hidden md:block">
        <span className="block label-tag text-cyan-400 rotate-[-90deg] origin-left translate-y-12 whitespace-nowrap">
          // SECTOR 666 — TRANSMISSION 01
        </span>
      </div>
      <div className="absolute right-6 top-1/2 -translate-y-1/2 hidden md:block">
        <span className="block label-tag text-fuchsia-400 rotate-90 origin-right -translate-y-12 whitespace-nowrap">
          NFG//SIGNAL-LOCK · 24.6X
        </span>
      </div>

      {/* Content */}
      <div className="relative z-10 mx-auto max-w-7xl px-6 md:px-10 h-full flex flex-col justify-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.1 }}
        >
          <span data-testid="hero-tag" className="label-tag inline-flex items-center gap-2">
            <span className="inline-block h-2 w-2 rounded-full bg-cyan-400 animate-pulse" />
            Y666.SUF // GAME STUDIO ── EST. 2025
          </span>
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.25 }}
          data-testid="hero-title"
          className="glitch font-display font-black uppercase mt-6 text-5xl sm:text-6xl md:text-7xl lg:text-[7.5rem] leading-[0.92] tracking-tighter text-white max-w-5xl"
        >
          PLAY. <span className="neon-text-cyan">COMPETE</span>.
          <br />
          FOLLOW EVERY ROUND <span className="neon-text-magenta">LIVE</span>.
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.45 }}
          className="mt-6 max-w-xl text-zinc-300/90 text-base md:text-lg"
        >
          NFG Games blends number-based crash simulation with fast word challenges.
          Jump between NFG Crash, Wordwich, Hangman, and Wordwheel with shared virtual
          points and real-time leaderboard action.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.6 }}
          className="mt-10 flex flex-wrap items-center gap-4"
        >
          <Link to="/games/nfg-crash" data-testid="hero-cta-play" className="btn-neon">
            ► Explore NFG Crash
          </Link>
          <a href="/#games" data-testid="hero-cta-arsenal" className="btn-ghost">
            ◇ View Game Suite
          </a>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.9, delay: 0.85 }}
          className="mt-6 font-mono text-[0.65rem] uppercase tracking-[0.25em] text-zinc-500 max-w-xl"
          data-testid="hero-compliance"
        >
          ▲ Virtual points only · No cash-out · No withdrawals · No real-money gambling
        </motion.p>

        {/* Bottom strip */}
        <div className="absolute left-6 right-6 md:left-10 md:right-10 bottom-6 flex items-end justify-between text-xs font-mono text-zinc-500">
          <div className="hidden md:flex flex-col gap-1">
            <span className="label-tag text-cyan-400">// LIVE METRIC</span>
            <span className="text-zinc-300">RUNS_TODAY · <span className="neon-text-cyan">2,418</span></span>
          </div>
          <div className="flex items-center gap-3">
            <span className="h-px w-14 bg-cyan-400/50" />
            <span className="label-tag text-fuchsia-400">SCROLL ↓</span>
          </div>
          <div className="hidden md:flex flex-col gap-1 text-right">
            <span className="label-tag text-fuchsia-400">PEAK MULT</span>
            <span className="text-zinc-300">24.62x · <span className="neon-text-magenta">VOIDRUNNER</span></span>
          </div>
        </div>
      </div>
    </section>
  );
}
