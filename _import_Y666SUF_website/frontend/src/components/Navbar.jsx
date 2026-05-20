import React, { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";

const links = [
  { href: "/games/nfg-crash", label: "NFG Crash" },
  { href: "/#games", label: "Game Suite" },
  { href: "/#install", label: "Install" },
  { href: "/#leaderboard", label: "Leaderboard" },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const location = useLocation();
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", onScroll);
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    if (!location.hash) return;
    const id = location.hash.replace("#", "");
    const el = document.getElementById(id);
    if (el) {
      setTimeout(() => {
        el.scrollIntoView({ behavior: "smooth", block: "start" });
      }, 50);
    }
  }, [location.pathname, location.hash]);

  return (
    <header
      data-testid="navbar"
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled ? "py-3" : "py-5"
      }`}
    >
      <div
        className={`mx-auto max-w-7xl px-6 md:px-10 flex items-center justify-between rounded-2xl ${
          scrolled ? "glass-panel border-b border-cyan-500/20" : ""
        }`}
        style={{ transition: "all .35s ease" }}
      >
        <Link
          to="/"
          data-testid="logo-link"
          className="flex items-center gap-3 group py-2"
        >
          <span className="relative inline-flex h-8 w-8 items-center justify-center rounded-md border border-cyan-400/60 bg-black">
            <span className="absolute inset-0 rounded-md bg-cyan-400/10 blur-md" />
            <span className="font-display font-black text-cyan-300 text-sm relative">Y</span>
          </span>
          <span className="font-display font-black text-white tracking-tight text-lg">
            Y666<span className="neon-text-cyan">.</span>SUF
          </span>
        </Link>

        <nav className="hidden md:flex items-center gap-1">
          {links.map((l) => (
            <Link
              key={l.href}
              to={l.href}
              data-testid={`nav-${l.label.toLowerCase().replace(/\s+/g, "-")}`}
              className="px-4 py-2 rounded-full text-sm font-mono uppercase tracking-widest text-zinc-400 hover:text-cyan-300 hover:bg-cyan-400/5 transition-colors"
            >
              {l.label}
            </Link>
          ))}
        </nav>

        <a
          href="https://www.tiktok.com/@y666.suf"
          target="_blank"
          rel="noopener noreferrer"
          data-testid="navbar-tiktok-cta"
          className="btn-ghost text-xs"
        >
          @y666.suf
        </a>
      </div>
    </header>
  );
}
