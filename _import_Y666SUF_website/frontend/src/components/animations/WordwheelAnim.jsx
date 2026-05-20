import React, { useEffect, useState } from "react";
import { motion } from "framer-motion";

/**
 * Wordwheel — rotating circle of letters with a "selector" tick that lands
 * on different letters as the wheel spins and decelerates.
 */
const LETTERS = "ABCDEFGHIJKLMNO".split("");

export default function WordwheelAnim({ accent = "#00F0FF" }) {
  const [highlight, setHighlight] = useState(0);

  useEffect(() => {
    let i = 0;
    const tick = setInterval(() => {
      i = (i + 1) % LETTERS.length;
      setHighlight(i);
    }, 350);
    return () => clearInterval(tick);
  }, []);

  const radius = 70;

  return (
    <div className="absolute inset-0 flex items-center justify-center">
      <div className="relative" style={{ width: 200, height: 200 }}>
        {/* outer ring */}
        <div
          className="absolute inset-0 rounded-full border"
          style={{
            borderColor: `${accent}55`,
            boxShadow: `0 0 24px ${accent}33, inset 0 0 24px ${accent}22`,
          }}
        />
        <div
          className="absolute inset-4 rounded-full border"
          style={{ borderColor: `${accent}33` }}
        />

        {/* center dot */}
        <div
          className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 h-3 w-3 rounded-full"
          style={{ background: accent, boxShadow: `0 0 16px ${accent}` }}
        />

        {/* selector pointer (top of wheel) */}
        <div
          className="absolute left-1/2 -translate-x-1/2 -top-2 h-0 w-0"
          style={{
            borderLeft: "8px solid transparent",
            borderRight: "8px solid transparent",
            borderTop: `12px solid ${accent}`,
            filter: `drop-shadow(0 0 6px ${accent})`,
          }}
        />

        {/* spinning letters */}
        <motion.div
          className="absolute inset-0"
          animate={{ rotate: 360 }}
          transition={{ duration: 14, repeat: Infinity, ease: "linear" }}
        >
          {LETTERS.map((ch, i) => {
            const angle = (i / LETTERS.length) * Math.PI * 2 - Math.PI / 2;
            const x = Math.cos(angle) * radius;
            const y = Math.sin(angle) * radius;
            const isOn = i === highlight;
            return (
              <span
                key={i}
                className="absolute font-display font-black text-sm"
                style={{
                  left: "50%",
                  top: "50%",
                  transform: `translate(calc(-50% + ${x}px), calc(-50% + ${y}px))`,
                  color: isOn ? "#fff" : `${accent}aa`,
                  textShadow: isOn ? `0 0 12px ${accent}, 0 0 24px ${accent}` : "none",
                  transition: "color .2s, text-shadow .2s",
                  fontSize: isOn ? "1.05rem" : "0.85rem",
                }}
              >
                {ch}
              </span>
            );
          })}
        </motion.div>

        {/* current letter readout */}
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 translate-y-12 text-center pointer-events-none">
          <div className="font-mono text-[0.55rem] tracking-[0.3em] text-zinc-500 uppercase">selected</div>
          <div className="font-display font-black text-2xl" style={{ color: accent, textShadow: `0 0 16px ${accent}aa` }}>
            {LETTERS[highlight]}
          </div>
        </div>
      </div>
    </div>
  );
}
