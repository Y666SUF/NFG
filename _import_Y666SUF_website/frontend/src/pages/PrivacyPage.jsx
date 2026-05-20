import React from "react";
import CosmicSubpageShell from "@/components/CosmicSubpageShell";

export default function PrivacyPage() {
  return (
    <CosmicSubpageShell testId="privacy-page-shell">
      <div className="mx-auto max-w-4xl px-6 md:px-10 space-y-4 mt-8">
        <article className="rounded-2xl border border-cyan-400/25 bg-black/60 p-6 md:p-8" data-testid="privacy-header">
          <h1 className="font-display font-black uppercase text-3xl md:text-4xl tracking-tight">Privacy Policy</h1>
          <p className="mt-3 text-zinc-300 text-sm">Last updated: 20 May 2026</p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Introduction</h2>
          <ul className="mt-4 space-y-2 text-zinc-300 text-sm list-disc list-inside">
            <li>
              NFG Crash and NFG Hangman are companion apps for TikTok LIVE games run by the stream host (@y666.suf).
            </li>
            <li>Virtual points are for entertainment and leaderboard competition only (separate boards per game).</li>
            <li>No cash-out, no withdrawals, and no real-money gambling in either app.</li>
            <li>Shared app chat and online presence may show players from multiple NFG companion apps.</li>
          </ul>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Who we are</h2>
          <ul className="mt-4 space-y-2 text-zinc-300 text-sm list-disc list-inside">
            <li>Data controller: operator of the NFG Crash live game service.</li>
            <li>Contact: privacy@y666suf.com</li>
            <li>App services run under y666suf.com.</li>
          </ul>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6" data-testid="privacy-information-collected">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Information we collect</h2>
          <ul className="mt-4 space-y-2 text-zinc-300 text-sm list-disc list-inside">
            <li>Account identity: TikTok username/display name after live verification and app session token.</li>
            <li>Device data: random device ID, iOS version, app version.</li>
            <li>Gameplay data: virtual balance, bets, cash-outs, chat messages, and game state.</li>
            <li>Advertising data: AdMob identifiers/interactions and tracking preferences where applicable.</li>
            <li>Technical logs: IP and timestamps (for example, Cloudflare).</li>
          </ul>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">How we use information</h2>
          <ul className="mt-4 space-y-2 text-zinc-300 text-sm list-disc list-inside">
            <li>Operate the game, verify TikTok linking, run chat/leaderboards, and secure the service.</li>
            <li>Support optional rewarded ads.</li>
            <li>We do not sell personal information.</li>
          </ul>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Legal bases (EEA/UK)</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            Service performance, legitimate interests, and consent where required (for example, ATT).
          </p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Sharing with third parties</h2>
          <ul className="mt-4 space-y-2 text-zinc-300 text-sm list-disc list-inside">
            <li>Service providers like hosting/CDN, Google AdMob when ads are viewed, and TikTok live integration.</li>
            <li>App chat messages are visible to other players in the same session.</li>
            <li>
              Google privacy policy:
              {" "}
              <a className="text-cyan-300" href="https://policies.google.com/privacy">
                https://policies.google.com/privacy
              </a>
            </li>
          </ul>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Retention</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            We keep data only as long as reasonably necessary for service operations, account integrity, troubleshooting,
            legal obligations, and fraud prevention.
          </p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Security</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            We use reasonable technical and organizational safeguards to protect data in transit and at rest. No storage or
            transmission method is completely secure.
          </p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Children</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            NFG companion apps are not intended for children under 13. NFG Crash includes simulated betting mechanics
            (17+ recommended). NFG Hangman is a word-guessing game (13+ with parental guidance).
          </p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Your rights</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            Depending on your location, you may have rights to access, correct, delete, restrict, or object to processing,
            and request data portability.
          </p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">International transfers</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            Data may be processed outside your country of residence. Where required, appropriate safeguards are applied.
          </p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Changes</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            We may update this policy from time to time and will update the date on this page.
          </p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6" data-testid="privacy-contact">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Contact</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            Privacy questions or requests:{" "}
            <a className="text-cyan-300" href="mailto:privacy@y666suf.com">
              privacy@y666suf.com
            </a>
          </p>
        </article>
      </div>
    </CosmicSubpageShell>
  );
}
