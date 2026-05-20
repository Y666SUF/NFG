import React from "react";
import { Link } from "react-router-dom";
import CosmicSubpageShell from "@/components/CosmicSubpageShell";

export default function LegalPage() {
  return (
    <CosmicSubpageShell testId="legal-page-shell">
      <div className="mx-auto max-w-4xl px-6 md:px-10 space-y-4 mt-8">
        <article className="rounded-2xl border border-fuchsia-400/25 bg-black/60 p-6 md:p-8" data-testid="legal-header">
          <h1 className="font-display font-black uppercase text-3xl md:text-4xl tracking-tight">Legal &amp; Compliance</h1>
          <p className="mt-3 text-zinc-300 text-sm">Last updated: 20 May 2026</p>
        </article>

        <article className="rounded-2xl border border-fuchsia-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">1. Entertainment only</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            NFG Crash and NFG Hangman are TikTok LIVE companion apps for entertainment and leaderboard play. Virtual points
            have no cash value, no cash-out, and no real-money gambling function. Hangman uses a separate all-time
            leaderboard from Crash.
          </p>
        </article>

        <article className="rounded-2xl border border-fuchsia-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">2. Points and purchases</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            Virtual points are for gameplay only and cannot be redeemed for money. If paid packs are introduced in future iOS
            releases, Apple In-App Purchase will be used where required.
          </p>
        </article>

        <article className="rounded-2xl border border-fuchsia-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">3. Advertising</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            Optional rewarded video ads (Google AdMob) may be used to grant in-game points. Tracking preferences can be
            managed in iOS privacy settings.
          </p>
        </article>

        <article className="rounded-2xl border border-fuchsia-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">4. TikTok account linking</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            Verification requires a live TikTok comment from your account. Manual username entry is not accepted for wallet
            or betting features.
          </p>
        </article>

        <article className="rounded-2xl border border-fuchsia-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">5. Age guidance</h2>
          <p className="mt-4 text-zinc-300 text-sm">Recommended for ages 17+ due to simulated betting-style mechanics.</p>
        </article>

        <article className="rounded-2xl border border-fuchsia-400/20 bg-black/55 p-6" data-testid="legal-privacy-link">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Privacy policy</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            Read the privacy policy at{" "}
            <Link className="text-cyan-300" to="/privacy">
              /privacy
            </Link>
          </p>
        </article>
      </div>
    </CosmicSubpageShell>
  );
}
