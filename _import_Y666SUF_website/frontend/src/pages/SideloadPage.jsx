import React from "react";
import { Link } from "react-router-dom";
import CosmicSubpageShell from "@/components/CosmicSubpageShell";
import IpaMetaLine from "@/components/IpaMetaLine";
import useIpaDownloads from "@/hooks/useIpaDownloads";

function AppBlock({
  id,
  accentClass,
  titleAccent,
  titleRest,
  testId,
  downloadHref,
  downloadLabel,
  gamePage,
  ipa,
}) {
  return (
    <section id={id} className="rounded-2xl border border-cyan-400/30 bg-black/65 p-7 md:p-9" data-testid={testId}>
      <span className="label-tag">// iPhone setup</span>
      <h2 className="mt-3 font-display font-black uppercase text-3xl md:text-4xl tracking-tight">
        Install NFG <span className={accentClass}>{titleAccent}</span>
        {titleRest ? ` ${titleRest}` : ""}
      </h2>
      <p className="mt-4 text-zinc-300 text-sm">
        Test install before App Store release. Each game is a <strong>separate app</strong> (own bundle ID and .ipa).
        Download the latest build below, then use Sideloadly or AltStore.
      </p>
      <IpaMetaLine ipa={ipa} className="mt-3" />
      <div className="mt-6 flex flex-wrap gap-4">
        <a href={downloadHref} className="btn-neon" data-testid={`${testId}-download`}>
          {downloadLabel}
        </a>
        <Link to={gamePage} className="btn-ghost">
          Game page →
        </Link>
      </div>
    </section>
  );
}

export default function SideloadPage() {
  const { crash, hangman } = useIpaDownloads();

  return (
    <CosmicSubpageShell testId="sideload-page-shell">
      <div className="mx-auto max-w-5xl px-6 md:px-10 mt-8 space-y-8">
        <div className="rounded-2xl border border-fuchsia-400/25 bg-black/55 p-6">
          <h1 className="font-display font-black uppercase text-4xl md:text-5xl tracking-tight">
            Install <span className="neon-text-cyan">NFG</span> on iPhone
          </h1>
          <p className="mt-4 text-zinc-300">
            NFG Crash and NFG Hangman are two companion apps. They share app chat and live presence, but use
            different game servers and leaderboards. Download links below always point at the latest builds on this
            server.
          </p>
        </div>

        <AppBlock
          id="crash"
          accentClass="neon-text-cyan"
          titleAccent="Crash"
          testId="sideload-crash"
          downloadHref={crash.href}
          downloadLabel={
            crash.mb ? `► Download NFG Crash .ipa (${crash.mb})` : "► Download NFG Crash .ipa"
          }
          gamePage="/games/nfg-crash"
          ipa={crash}
        />

        <AppBlock
          id="hangman"
          accentClass="neon-text-fuchsia"
          titleAccent="Hangman"
          testId="sideload-hangman"
          downloadHref={hangman.href}
          downloadLabel={
            hangman.mb ? `► Download NFG Hangman .ipa (${hangman.mb})` : "► Download NFG Hangman .ipa"
          }
          gamePage="/games/nfg-hangman"
          ipa={hangman}
        />

        <div className="grid md:grid-cols-2 gap-6">
          <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6" data-testid="sideload-method-sideloadly">
            <h2 className="font-display font-black uppercase text-2xl tracking-tight">
              Method 1: Sideloadly (recommended on Windows)
            </h2>
            <ol className="mt-4 space-y-3 text-zinc-300 text-sm list-decimal list-inside">
              <li>Install iTunes + iCloud from Apple website (not Microsoft Store).</li>
              <li>
                Install Sideloadly from{" "}
                <a className="text-cyan-300" href="https://sideloadly.io/">
                  sideloadly.io
                </a>
                .
              </li>
              <li>Connect iPhone to PC/Mac, unlock device, tap Trust if prompted.</li>
              <li>Open Sideloadly, choose your device, drag in the downloaded `.ipa`.</li>
              <li>Sign with your Apple ID and start sideload.</li>
              <li>On iPhone: Settings → General → VPN &amp; Device Management → Trust your developer profile.</li>
              <li>On iOS 16+: enable Developer Mode in Settings → Privacy &amp; Security.</li>
            </ol>
          </article>

          <article className="rounded-2xl border border-fuchsia-400/20 bg-black/55 p-6" data-testid="sideload-video-card">
            <h2 className="font-display font-black uppercase text-2xl tracking-tight">Video tutorial</h2>
            <p className="mt-6 text-zinc-400 text-xs">
              <a className="text-cyan-300" href="https://www.youtube.com/watch?v=x_gvrT2tv-g" data-testid="sideload-video-link">
                Install Sideloadly Properly: Windows Guide
              </a>
            </p>
          </article>
        </div>

        <article className="rounded-2xl border border-fuchsia-400/20 bg-black/55 p-6" data-testid="sideload-method-altstore">
          <h2 className="font-display font-black uppercase text-2xl tracking-tight">Method 2: AltStore</h2>
          <p className="mt-4 text-zinc-300 text-sm">
            <a className="text-cyan-300" href="https://faq.altstore.io/">
              faq.altstore.io
            </a>
          </p>
        </article>

        <article className="rounded-2xl border border-cyan-400/20 bg-black/55 p-6">
          <h2 className="font-display font-black uppercase text-xl tracking-tight">App Store</h2>
          <p className="mt-3 text-zinc-300 text-sm">
            Each game must be submitted as its own App Store listing with its own bundle ID (for example{" "}
            <code className="text-cyan-300">com.nfg.crash</code> vs <code className="text-cyan-300">com.nfg.hangman</code>
            ). You cannot ship one listing for both games.
          </p>
        </article>
      </div>
    </CosmicSubpageShell>
  );
}
