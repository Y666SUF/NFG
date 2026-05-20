import React from "react";
import { motion } from "framer-motion";

/**
 * Wordwich — stacked letter "sandwich" of tiles animating in and out.
 * Letters slide in from bottom, hold, slide out top in a loop.
 */
const STACK = ["W", "O", "R", "D", "W", "I", "C", "H"];

export default function WordwichTiles({ accent = "#FF003C" }) {
  return (
    <div className="absolute inset-0 flex items-center justify-center overflow-hidden">
      {/* Subtle bread-slice top + bottom plates */}
      <div
        className="absolute left-1/2 -translate-x-1/2 w-44 h-3 rounded-full"
        style={{
          top: "calc(50% - 92px)",
          background: "linear-gradient(180deg, rgba(255,0,60,0.35), transparent)",
          filter: "blur(2px)",
        }}
      />
      <div
        className="absolute left-1/2 -translate-x-1/2 w-44 h-3 rounded-full"
        style={{
          bottom: "calc(50% - 92px)",
          background: "linear-gradient(0deg, rgba(0,240,255,0.35), transparent)",
          filter: "blur(2px)",
        }}
      />

      <div className="flex flex-col gap-1.5">
        {STACK.map((ch, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, x: -40, rotate: -8 }}
            animate={{
              opacity: [0, 1, 1, 0],
              x: [-40, 0, 0, 40],
              rotate: [-8, 0, 0, 6],
            }}
            transition={{
              duration: 3.4,
              times: [0, 0.18, 0.82, 1],
              repeat: Infinity,
              delay: i * 0.18,
              ease: "easeInOut",
            }}
            className="font-display font-black text-center mx-auto"
            style={{
              width: "2.4rem",
              height: "2.4rem",
              lineHeight: "2.4rem",
              fontSize: "1.4rem",
              color: i % 2 ? "#fff" : accent,
              background: i % 2 ? "rgba(255,255,255,0.04)" : "rgba(255,0,60,0.08)",
              border: `1px solid ${i % 2 ? "rgba(255,255,255,0.15)" : `${accent}55`}`,
              borderRadius: "6px",
              boxShadow: i % 2 ? "none" : `0 0 16px ${accent}55`,
            }}
          >
            {ch}
          </motion.div>
        ))}
      </div>
    </div>
  );
}
