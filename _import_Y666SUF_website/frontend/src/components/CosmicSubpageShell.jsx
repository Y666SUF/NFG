import React from "react";
import { Link } from "react-router-dom";
import Scene3D from "@/components/Scene3D";

export default function CosmicSubpageShell({ children, testId = "cosmic-subpage-shell" }) {
  return (
    <section className="relative py-24 md:py-32 overflow-hidden" data-testid={testId}>
      <div className="absolute inset-0 opacity-40 pointer-events-none">
        <Scene3D intensity="ambient" />
      </div>
      <div
        className="absolute inset-0 pointer-events-none"
        style={{ background: "linear-gradient(180deg, #05050A 0%, rgba(5,5,10,0.75) 30%, rgba(5,5,10,0.95) 100%)" }}
      />
      <div className="relative mx-auto max-w-7xl px-6 md:px-10">
        <Link to="/" className="btn-ghost text-xs" data-testid="subpage-back-home">
          ← Back to home
        </Link>
      </div>
      <div className="relative">{children}</div>
    </section>
  );
}
