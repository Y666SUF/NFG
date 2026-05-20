import React from "react";
import { motion } from "framer-motion";

const steps = [
  {
    n: "01",
    title: "Open on iPhone",
    body: "Install links are shown on phones only. Open y666suf.com on your iPhone to access the mobile install flow.",
  },
  {
    n: "02",
    title: "Download .ipa",
    body: "Tap the direct download link to grab the latest NFG Crash iOS build.",
  },
  {
    n: "03",
    title: "Follow sideload guide",
    body: "Step-by-step sideload tutorial walks you through trusting and launching the app.",
  },
  {
    n: "04",
    title: "Sign in & play",
    body: "Open NFG Crash, link to a live round, and your wallet + leaderboard sync instantly.",
  },
];

export default function InstallSection() {
  return (
    <section
      id="install"
      data-testid="install-section"
      className="relative py-24 md:py-32 border-t border-white/5"
    >
      <div className="mx-auto max-w-7xl px-6 md:px-10">
        <div className="grid lg:grid-cols-12 gap-10 items-start">
          <div className="lg:col-span-5">
            <span className="label-tag">// MOBILE</span>
            <h2 className="font-display font-black uppercase text-4xl md:text-6xl tracking-tighter mt-3">
              INSTALL ON <span className="neon-text-cyan">iPHONE</span>
            </h2>
            <p className="mt-5 text-zinc-400 max-w-md">
              Get NFG Crash or NFG Hangman on iOS. Each title has its own .ipa and App Store listing.
              Shared app chat works across both companions.
            </p>

            <div className="mt-8 flex flex-wrap gap-4">
              <a href="/download/nfg-crash.ipa" data-testid="install-download-crash" className="btn-neon">
                ⬇ Crash .ipa
              </a>
              <a href="/download/nfg-hangman.ipa" data-testid="install-download-hangman" className="btn-ghost">
                ⬇ Hangman .ipa
              </a>
              <a href="/sideload" data-testid="install-sideload-guide" className="btn-ghost">
                ◇ Sideload Tutorial
              </a>
            </div>

            <p className="mt-6 font-mono text-[0.65rem] uppercase tracking-[0.25em] text-zinc-500">
              ▲ Open on iPhone to access the mobile install flow
            </p>
          </div>

          <div className="lg:col-span-7 grid sm:grid-cols-2 gap-5">
            {steps.map((s, i) => (
              <motion.div
                key={s.n}
                initial={{ opacity: 0, y: 24 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.2 }}
                transition={{ duration: 0.5, delay: i * 0.08 }}
                data-testid={`install-step-${i}`}
                className="relative rounded-2xl border border-cyan-400/20 bg-black/50 p-6 hover:border-cyan-400/60 transition-colors"
                style={{ boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.02)" }}
              >
                <div className="flex items-start justify-between">
                  <span className="font-display font-black text-5xl neon-text-cyan opacity-80">
                    {s.n}
                  </span>
                  <span className="font-mono text-[0.6rem] tracking-[0.3em] text-zinc-500 uppercase">
                    STEP
                  </span>
                </div>
                <h3 className="font-display font-bold uppercase mt-3 text-lg tracking-tight">
                  {s.title}
                </h3>
                <p className="mt-2 text-sm text-zinc-400 leading-relaxed">{s.body}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
