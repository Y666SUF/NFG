import React, { useEffect, useState } from "react";
import { motion } from "framer-motion";

/**
 * Hangman — gallows + dashed letter slots that fill in over time.
 * Shows a word being progressively revealed, then resets.
 */
const WORDS = ["HANGMAN", "VOIDRUN", "NFG", "STREAKS"];

export default function HangmanAnim({ accent = "#8A2BE2" }) {
  const [wordIdx, setWordIdx] = useState(0);
  const [reveal, setReveal] = useState(0);

  useEffect(() => {
    const wordTimer = setInterval(() => {
      setWordIdx((w) => (w + 1) % WORDS.length);
      setReveal(0);
    }, 6000);
    const tick = setInterval(() => setReveal((r) => r + 1), 600);
    return () => {
      clearInterval(wordTimer);
      clearInterval(tick);
    };
  }, []);

  const word = WORDS[wordIdx];

  return (
    <div className="absolute inset-0 flex flex-col items-center justify-center gap-6 px-6">
      {/* Gallows */}
      <svg viewBox="0 0 120 110" width="110" height="100" style={{ filter: `drop-shadow(0 0 8px ${accent}66)` }}>
        {/* base */}
        <motion.line
          x1="10" y1="100" x2="80" y2="100"
          stroke={accent} strokeWidth="3" strokeLinecap="round"
          initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.6 }}
        />
        {/* pole */}
        <motion.line
          x1="30" y1="100" x2="30" y2="10"
          stroke={accent} strokeWidth="3" strokeLinecap="round"
          initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.6, delay: 0.3 }}
        />
        {/* top */}
        <motion.line
          x1="30" y1="10" x2="80" y2="10"
          stroke={accent} strokeWidth="3" strokeLinecap="round"
          initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.6, delay: 0.6 }}
        />
        {/* rope */}
        <motion.line
          x1="80" y1="10" x2="80" y2="28"
          stroke="#FF003C" strokeWidth="2" strokeLinecap="round"
          initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.4, delay: 0.9 }}
        />
        {/* head */}
        <motion.circle
          cx="80" cy="36" r="8"
          fill="none" stroke="#FF003C" strokeWidth="2"
          initial={{ opacity: 0, scale: 0 }}
          animate={{ opacity: [0, 1], scale: [0, 1] }}
          transition={{ duration: 0.5, delay: 1.2 }}
        />
        {/* body */}
        <motion.line
          x1="80" y1="44" x2="80" y2="72"
          stroke="#FF003C" strokeWidth="2" strokeLinecap="round"
          initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.4, delay: 1.6 }}
        />
        {/* arms */}
        <motion.line x1="80" y1="52" x2="68" y2="62" stroke="#FF003C" strokeWidth="2" strokeLinecap="round" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.4, delay: 1.9 }} />
        <motion.line x1="80" y1="52" x2="92" y2="62" stroke="#FF003C" strokeWidth="2" strokeLinecap="round" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.4, delay: 2.1 }} />
        {/* legs */}
        <motion.line x1="80" y1="72" x2="70" y2="86" stroke="#FF003C" strokeWidth="2" strokeLinecap="round" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.4, delay: 2.3 }} />
        <motion.line x1="80" y1="72" x2="90" y2="86" stroke="#FF003C" strokeWidth="2" strokeLinecap="round" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.4, delay: 2.5 }} />
      </svg>

      {/* Word slots */}
      <div className="flex gap-2 items-end">
        {word.split("").map((ch, i) => (
          <div key={`${wordIdx}-${i}`} className="flex flex-col items-center gap-1">
            <motion.span
              className="font-display font-black text-xl md:text-2xl"
              style={{
                color: i < reveal ? "#fff" : "transparent",
                textShadow: i < reveal ? `0 0 12px ${accent}aa` : "none",
                transition: "color .25s",
              }}
              animate={i < reveal ? { scale: [0, 1.2, 1] } : {}}
              transition={{ duration: 0.4 }}
            >
              {ch}
            </motion.span>
            <span
              className="block h-[2px] w-5 md:w-6 rounded-full"
              style={{ background: accent, opacity: 0.55 }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
