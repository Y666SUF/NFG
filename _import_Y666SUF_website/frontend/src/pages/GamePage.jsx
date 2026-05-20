import React from "react";
import { Link, useParams } from "react-router-dom";
import { GAMES } from "@/components/games";
import Leaderboard from "@/components/Leaderboard";
import HangmanLeaderboard from "@/components/HangmanLeaderboard";
import CosmicSubpageShell from "@/components/CosmicSubpageShell";
import CrashGraph from "@/components/animations/CrashGraph";
import { HangmanAnim, WordwheelAnim, WordwichTiles } from "@/components/GameVisuals";
import useFeaturedStats from "@/hooks/useFeaturedStats";

function badgesFor(slug) {
  if (slug === "nfg-crash") {
    return [
      "Shared virtual points",
      "Live leaderboard",
      "Mobile companion support",
      "Virtual points only",
    ];
  }
  if (slug === "nfg-hangman") {
    return [
      "Hangman all-time leaderboard",
      "Shared app chat (all NFG apps)",
      "Live status + online players",
      "iOS companion + sideload",
      "Virtual points only",
    ];
  }
  return ["Replayable sessions", "Competitive scoring", "Skill-based gameplay", "Built by NFG Games"];
}

export default function GamePage({ forcedSlug = "" }) {
  const { slug } = useParams();
  const resolvedSlug = forcedSlug || slug;
  const game = GAMES.find((g) => g.slug === resolvedSlug);
  const { stats: featuredStats } = useFeaturedStats(8000);

  if (!game) {
    return (
      <CosmicSubpageShell testId="game-page-shell">
        <div className="mx-auto max-w-4xl px-6 md:px-10">
          <div className="rounded-2xl border border-cyan-400/30 bg-black/65 p-8 mt-8">
            <h1 className="font-display font-black uppercase text-4xl md:text-5xl tracking-tight">Game not found</h1>
            <p className="mt-4 text-zinc-300">The game page you requested is not available.</p>
            <Link to="/" className="btn-ghost mt-8 inline-flex">
              ← Back to home
            </Link>
          </div>
        </div>
      </CosmicSubpageShell>
    );
  }

  const visualBySlug = {
    "nfg-wordwich": <WordwichTiles className="mt-6" />,
    "nfg-hangman": <HangmanAnim className="mt-6" />,
    "nfg-wordwheel": <WordwheelAnim className="mt-6" />,
  };

  const heroVisual =
    game.slug === "nfg-crash" ? (
      <CrashGraph variant="hero" stats={featuredStats} />
    ) : (
      <img src={game.image} alt={game.name} className="absolute inset-0 h-full w-full object-cover" />
    );

  return (
    <CosmicSubpageShell testId="game-page-shell">
      <div className="mx-auto max-w-7xl px-6 md:px-10 mt-8">
        <div className="grid lg:grid-cols-12 gap-8 md:gap-10">
          <div className="lg:col-span-7">
            <div
              className={`relative rounded-2xl overflow-hidden border border-cyan-400/30 grain-overlay bg-black ${
                game.slug === "nfg-crash" ? "aspect-[4/3] md:aspect-[16/11]" : "aspect-[16/10]"
              }`}
              data-testid="game-detail-hero"
            >
              {heroVisual}
              {game.slug !== "nfg-crash" && (
                <div
                  className="absolute inset-0 pointer-events-none"
                  style={{ background: "linear-gradient(180deg, rgba(5,5,10,0.1) 0%, rgba(5,5,10,0.75) 100%)" }}
                />
              )}
              {game.slug === "nfg-crash" && (
                <div
                  className="absolute inset-0 pointer-events-none"
                  style={{ background: "radial-gradient(ellipse at center, transparent 55%, rgba(5,5,10,0.6))" }}
                />
              )}
              <div className="absolute top-4 left-4 z-10">
                <span
                  className="font-mono text-[0.62rem] uppercase tracking-[0.28em] px-3 py-1 rounded-full border bg-black/50"
                  style={{ borderColor: `${game.accent}88`, color: game.accent }}
                >
                  {game.tag}
                </span>
              </div>
            </div>
            {visualBySlug[game.slug]}
          </div>

          <div className="lg:col-span-5">
            <h1 className="font-display font-black uppercase text-4xl md:text-5xl tracking-tight" data-testid="game-detail-title">
              {game.name.split(" ").map((w, idx) => (
                <span
                  key={`${w}-${idx}`}
                  style={idx === 1 ? { color: game.accent, textShadow: `0 0 16px ${game.accent}88` } : {}}
                >
                  {w}
                  {idx === 0 ? " " : ""}
                </span>
              ))}
            </h1>

            <p className="mt-4 text-zinc-300/90" data-testid="game-detail-description">
              {game.description || game.tagline}
            </p>

            <ul className="mt-6 grid gap-3">
              {badgesFor(game.slug).map((item) => (
                <li
                  key={item}
                  className="rounded-lg border border-cyan-400/20 bg-black/55 px-4 py-3 text-sm text-zinc-200"
                >
                  {item}
                </li>
              ))}
            </ul>

            <div className="mt-8 flex flex-wrap gap-4">
              {game.slug === "nfg-crash" ? (
                <>
                  <Link to="/sideload#crash" className="btn-neon" data-testid="game-detail-install-cta">
                    ► Install on iPhone
                  </Link>
                  <a
                    href="https://www.tiktok.com/@y666.suf"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn-ghost"
                    data-testid="game-detail-watch-live"
                  >
                    ◇ Watch Live
                  </a>
                </>
              ) : game.slug === "nfg-hangman" ? (
                <>
                  <Link
                    to="/sideload#hangman"
                    className="btn-neon"
                    data-testid="game-detail-install-cta-hangman"
                  >
                    ► Install Hangman on iPhone
                  </Link>
                  <a
                    href="/download/nfg-hangman.ipa"
                    className="btn-ghost"
                    data-testid="game-detail-download-ipa-hangman"
                  >
                    ⬇ Download .ipa
                  </a>
                  <a
                    href="https://www.tiktok.com/@y666.suf"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn-ghost"
                    data-testid="game-detail-watch-live-hangman"
                  >
                    ◇ Watch Live
                  </a>
                </>
              ) : (
                <a
                  href="https://www.tiktok.com/@y666.suf"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn-neon"
                  data-testid="game-detail-follow-cta"
                >
                  ► Follow @y666.suf
                </a>
              )}
            </div>
          </div>
        </div>

        {game.slug === "nfg-crash" && (
          <div className="mt-14" data-testid="game-detail-leaderboard">
            <Leaderboard />
          </div>
        )}
        {game.slug === "nfg-hangman" && (
          <div className="mt-14" data-testid="game-detail-hangman-leaderboard">
            <HangmanLeaderboard />
          </div>
        )}
      </div>
    </CosmicSubpageShell>
  );
}
