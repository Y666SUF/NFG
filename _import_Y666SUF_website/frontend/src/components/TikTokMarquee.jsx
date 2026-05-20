import React from "react";
import Marquee from "react-fast-marquee";

export default function TikTokMarquee() {
  const items = [
    "@y666.suf",
    "▲ LIVE NOW",
    "NFG CRASH",
    "@y666.suf",
    "PRESS PLAY",
    "WORDWICH",
    "@y666.suf",
    "HANGMAN",
    "INTERACTIVE",
    "WORDWHEEL",
  ];
  return (
    <div
      data-testid="tiktok-marquee"
      className="relative py-6 border-y border-cyan-400/20 bg-black overflow-hidden mask-marquee"
    >
      <Marquee speed={70} gradient={false} pauseOnHover>
        {items.concat(items).map((t, i) => (
          <span
            key={i}
            className="font-display font-black uppercase text-5xl md:text-7xl tracking-tighter mx-8 inline-flex items-center"
            style={{
              color: i % 3 === 0 ? "#00F0FF" : "#fff",
              WebkitTextStroke: i % 3 === 1 ? "1px #FF003C" : "0",
              WebkitTextFillColor: i % 3 === 1 ? "transparent" : undefined,
              textShadow: i % 3 === 0 ? "0 0 24px rgba(0,240,255,0.5)" : "none",
            }}
          >
            {t}
            <span className="mx-6 text-fuchsia-500/60">✦</span>
          </span>
        ))}
      </Marquee>
    </div>
  );
}
