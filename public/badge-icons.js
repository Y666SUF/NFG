/**
 * NFG vault badges — high-contrast purple gambling & crypto SVGs.
 */
(function (global) {
  const BADGE_LEGACY = { voidmark: "acespades", pulsecore: "chip", prism: "dice", nova: "bullion", eclipse: "lucky7", nebula: "ltc", sovereign: "bitcoin", astral: "ethereum", transcend: "whale", apex: "imperial" };
  function resolveBadgeId(id) {
    const k = String(id || "").trim().toLowerCase();
    return BADGE_LEGACY[k] || k;
  }

  const OUTLINE = "#0a0014";
  const OW = 1.6;

  const LABELS = {
    acespades: "Ace of Spades",
    chip: "Vault Chip",
    dice: "High Roller",
    bullion: "Gold Bullion",
    lucky7: "Lucky Seven",
    ltc: "Litecoin",
    bitcoin: "Crypto Coin",
    ethereum: "Ether Gem",
    whale: "Whale Vault",
    imperial: "NFG Imperial",
    crown: "Royal Vault",
  };

  const SVG = {
    acespades: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <rect x="7" y="3" width="34" height="42" rx="4" fill="#2e1065" stroke="${OUTLINE}" stroke-width="${OW}"/>
      <rect x="9" y="5" width="30" height="38" rx="3" fill="#f5f0ff" stroke="#d8b4fe" stroke-width="1.2"/>
      <rect x="11" y="7" width="26" height="34" rx="2" fill="#ede9fe" stroke="#a855f7" stroke-width="0.8"/>
      <text x="13" y="14" font-size="9" font-weight="800" fill="${OUTLINE}" font-family="Georgia,serif">A</text>
      <text x="30" y="39" font-size="10" font-weight="800" fill="${OUTLINE}" font-family="Georgia,serif">♠</text>
      <path fill="${OUTLINE}" stroke="#ffffff" stroke-width="1"
        d="M24 13c-6.5 0-11 4.8-11 10.5 0 4 2.2 7.5 6 9.5v7h10v-7c3.8-2 6-5.5 6-9.5 0-5.7-4.5-10.5-11-10.5zm0 2.8c4.6 0 8.2 3.6 8.2 7.7s-3.6 7.7-8.2 7.7-8.2-3.6-8.2-7.7 3.6-7.7 8.2-7.7z"/>
      <path fill="#7c3aed" d="M24 14.5c-5.4 0-9.5 4-9.5 9 0 3.4 1.8 6.2 5 7.8v5.8h9V31.3c3.2-1.6 5-4.4 5-7.8 0-5-4.1-9-9.5-9zm0 2.5c3.8 0 6.8 3 6.8 6.5s-3 6.5-6.8 6.5-6.8-3-6.8-6.5 3-6.5 6.8-6.5z"/>
      <path fill="${OUTLINE}" d="M24 25c-2 0-3.4 1.4-3.4 3.2h1.8c0-1.1.9-1.8 1.6-1.8s1.6.7 1.6 1.8c0 2.2-3.6 2.4-3.6 5h1.8c0-1.8 3.6-2 3.6-5 0-1.8-1.4-3.2-3.4-3.2z"/>
    </svg>`,

    chip: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <circle cx="24" cy="24" r="19" fill="${OUTLINE}"/>
      <circle cx="24" cy="24" r="17" fill="#5b21b6" stroke="#f5f3ff" stroke-width="1.2"/>
      <circle cx="24" cy="24" r="14" fill="#9333ea" stroke="#e9d5ff" stroke-width="0.8"/>
      ${[0, 45, 90, 135, 180, 225, 270, 315]
        .map((d) => `<rect x="23" y="9" width="2" height="3" fill="#f5f3ff" transform="rotate(${d} 24 24)"/>`)
        .join("")}
      <circle cx="24" cy="24" r="9" fill="#2e1065" stroke="#ffffff" stroke-width="1"/>
      <path fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"
        d="M24 17v14M20 19.5c0-2.2 1.7-3 3.5-3s3.5.8 3.5 3-1.7 3-3.5 3m0 1.6c2.1 0 3.6 1 3.6 2.9s-1.5 2.9-3.6 2.9-3.6-1.2-3.6-2.9 1.5-2.9 3.6-2.9z"/>
    </svg>`,

    dice: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <g transform="translate(5 9) rotate(-14 15 15)">
        <rect x="1" y="1" width="26" height="26" rx="4" fill="${OUTLINE}"/>
        <rect x="3" y="3" width="22" height="22" rx="3" fill="#f5f3ff" stroke="#c084fc" stroke-width="1"/>
        <circle cx="8" cy="8" r="2.5" fill="${OUTLINE}"/><circle cx="18" cy="18" r="2.5" fill="${OUTLINE}"/>
        <circle cx="21" cy="9" r="2.5" fill="${OUTLINE}"/>
      </g>
      <g transform="translate(17 13) rotate(12 15 15)">
        <rect x="1" y="1" width="26" height="26" rx="4" fill="${OUTLINE}"/>
        <rect x="3" y="3" width="22" height="22" rx="3" fill="#ede9fe" stroke="#a855f7" stroke-width="1"/>
        <circle cx="8" cy="8" r="2.5" fill="${OUTLINE}"/><circle cx="14" cy="14" r="2.5" fill="${OUTLINE}"/>
        <circle cx="20" cy="8" r="2.5" fill="${OUTLINE}"/><circle cx="20" cy="20" r="2.5" fill="${OUTLINE}"/>
      </g>
    </svg>`,

    bullion: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <defs>
        <linearGradient id="nova-gold" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#fef9c3"/>
          <stop offset="40%" stop-color="#fbbf24"/>
          <stop offset="100%" stop-color="#d97706"/>
        </linearGradient>
        <linearGradient id="nova-shine" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#ffffff" stop-opacity="0.55"/>
          <stop offset="50%" stop-color="#ffffff" stop-opacity="0"/>
        </linearGradient>
      </defs>
      <rect x="6" y="34" width="36" height="8" rx="2" fill="${OUTLINE}"/>
      <rect x="8" y="35" width="32" height="5" rx="1" fill="#4c1d95" stroke="#c084fc" stroke-width="0.8"/>
      <path fill="${OUTLINE}" d="M11 34 L14 12 H34 L37 34 Z"/>
      <path fill="url(#nova-gold)" stroke="#ffffff" stroke-width="1.1" d="M13 33 L15.5 14 H32.5 L35 33 Z"/>
      <path fill="url(#nova-shine)" d="M15 16 L18 14 H26 L22 30 H16 Z" opacity="0.85"/>
      <rect x="14" y="20" width="20" height="3" rx="1" fill="#b45309" opacity="0.35"/>
      <rect x="14" y="26" width="20" height="3" rx="1" fill="#b45309" opacity="0.35"/>
      <text x="24" y="27" text-anchor="middle" font-size="11" font-weight="900" fill="${OUTLINE}" font-family="Arial Black,Impact,sans-serif">$</text>
      <text x="24" y="27" text-anchor="middle" font-size="11" font-weight="900" fill="#ffffff" font-family="Arial Black,Impact,sans-serif">$</text>
      <circle cx="24" cy="10" r="3" fill="#a855f7" stroke="#ffffff" stroke-width="0.8"/>
      <path fill="#f5f3ff" d="M24 7.5 L25.2 9.8 H27.8 L25.8 11.4 L26.5 14 L24 12.5 L21.5 14 L22.2 11.4 L20.2 9.8 H22.8 Z"/>
    </svg>`,

    lucky7: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <rect x="5" y="9" width="38" height="30" rx="4" fill="${OUTLINE}"/>
      <rect x="7" y="11" width="34" height="26" rx="3" fill="#2e1065"/>
      <rect x="9" y="13" width="30" height="22" rx="2" fill="#4c1d95" stroke="#e9d5ff" stroke-width="1"/>
      <text x="24" y="31" text-anchor="middle" font-size="20" font-weight="900" fill="#ffffff" font-family="Impact,Arial Black,sans-serif">7</text>
      <text x="24" y="31" text-anchor="middle" font-size="20" font-weight="900" fill="none" stroke="${OUTLINE}" stroke-width="1.2" font-family="Impact,Arial Black,sans-serif">7</text>
      <circle cx="11" cy="15" r="2.5" fill="#ef4444" stroke="#fff" stroke-width="0.8"/>
      <circle cx="37" cy="33" r="2.5" fill="#ef4444" stroke="#fff" stroke-width="0.8"/>
    </svg>`,

    ltc: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <defs>
        <linearGradient id="nebula-ltc-rim" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#ddd6fe"/>
          <stop offset="40%" stop-color="#8b5cf6"/>
          <stop offset="100%" stop-color="#4c1d95"/>
        </linearGradient>
        <linearGradient id="nebula-ltc-silver" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#f8fafc"/>
          <stop offset="45%" stop-color="#cbd5e1"/>
          <stop offset="100%" stop-color="#94a3b8"/>
        </linearGradient>
        <radialGradient id="nebula-ltc-shine" cx="32%" cy="28%" r="58%">
          <stop offset="0%" stop-color="#ffffff" stop-opacity="0.9"/>
          <stop offset="100%" stop-color="#a855f7" stop-opacity="0"/>
        </radialGradient>
      </defs>
      <circle cx="24" cy="24" r="19" fill="${OUTLINE}"/>
      <circle cx="24" cy="24" r="17" fill="url(#nebula-ltc-rim)" stroke="#f5f3ff" stroke-width="1.2"/>
      <circle cx="24" cy="24" r="14.2" fill="#5b21b6" stroke="#e9d5ff" stroke-width="0.9"/>
      <circle cx="24" cy="24" r="11.5" fill="url(#nebula-ltc-silver)" stroke="#ffffff" stroke-width="1.1"/>
      <circle cx="24" cy="24" r="11.5" fill="url(#nebula-ltc-shine)"/>
      <text x="24" y="29" text-anchor="middle" font-size="16" font-weight="900" fill="${OUTLINE}" font-family="Arial Black,Impact,sans-serif">Ł</text>
      <text x="24" y="29" text-anchor="middle" font-size="16" font-weight="900" fill="#ffffff" font-family="Arial Black,Impact,sans-serif">Ł</text>
      <text x="24" y="29" text-anchor="middle" font-size="16" font-weight="900" fill="none" stroke="#7c3aed" stroke-width="0.5" font-family="Arial Black,Impact,sans-serif">Ł</text>
    </svg>`,

  bitcoin: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <circle cx="24" cy="24" r="19" fill="${OUTLINE}"/>
      <circle cx="24" cy="24" r="17" fill="#f59e0b" stroke="#ffffff" stroke-width="1.2"/>
      <circle cx="24" cy="24" r="14" fill="#fbbf24" stroke="${OUTLINE}" stroke-width="0.8"/>
      <circle cx="24" cy="24" r="11" fill="#7c3aed" stroke="#f5f3ff" stroke-width="1"/>
      <text x="24" y="29" text-anchor="middle" font-size="14" font-weight="900" fill="#ffffff" font-family="Arial Black,sans-serif">₿</text>
      <text x="24" y="29" text-anchor="middle" font-size="14" font-weight="900" fill="none" stroke="${OUTLINE}" stroke-width="0.6" font-family="Arial Black,sans-serif">₿</text>
    </svg>`,

    ethereum: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <polygon points="24,4 42,14 42,34 24,44 6,34 6,14" fill="${OUTLINE}"/>
      <polygon points="24,7 39,15 39,33 24,41 9,33 9,15" fill="#7c3aed" stroke="#f5f3ff" stroke-width="1.2"/>
      <polygon points="24,11 35,17 35,31 24,37 13,31 13,17" fill="#a855f7" stroke="#ffffff" stroke-width="0.8"/>
      <polygon points="24,15 31,19 31,29 24,33 17,29 17,19" fill="#c084fc" opacity="0.9"/>
      <polygon points="24,19 27,21 27,27 24,29 21,27 21,21" fill="#ffffff"/>
    </svg>`,

    whale: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <rect x="8" y="10" width="32" height="28" rx="3" fill="${OUTLINE}"/>
      <rect x="10" y="12" width="28" height="24" rx="2" fill="#4c1d95" stroke="#e9d5ff" stroke-width="1.2"/>
      <rect x="12" y="14" width="24" height="20" rx="1" fill="#2e1065"/>
      <circle cx="24" cy="24" r="7" fill="#fbbf24" stroke="#ffffff" stroke-width="1.2"/>
      <text x="24" y="27.5" text-anchor="middle" font-size="9" font-weight="800" fill="${OUTLINE}" font-family="Arial,sans-serif">$</text>
      <rect x="14" y="16" width="4" height="16" rx="1" fill="#a855f7" stroke="#fff" stroke-width="0.6"/>
      <rect x="30" y="16" width="4" height="16" rx="1" fill="#a855f7" stroke="#fff" stroke-width="0.6"/>
      <path fill="none" stroke="#22d3ee" stroke-width="1.5" d="M16 20 h16 M16 24 h16 M16 28 h16"/>
      <circle cx="11" cy="24" r="2" fill="#22d3ee" stroke="#fff" stroke-width="0.6"/>
      <circle cx="37" cy="24" r="2" fill="#22d3ee" stroke="#fff" stroke-width="0.6"/>
    </svg>`,

    imperial: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <defs>
        <radialGradient id="apex-halo" cx="50%" cy="45%" r="55%">
          <stop offset="0%" stop-color="#faf5ff"/>
          <stop offset="35%" stop-color="#e9d5ff" stop-opacity="0.85"/>
          <stop offset="70%" stop-color="#a855f7" stop-opacity="0.35"/>
          <stop offset="100%" stop-color="#2e1065" stop-opacity="0"/>
        </radialGradient>
        <linearGradient id="apex-shield" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#7c3aed"/>
          <stop offset="45%" stop-color="#5b21b6"/>
          <stop offset="100%" stop-color="#1e1b4b"/>
        </linearGradient>
        <linearGradient id="apex-gold" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#fef08a"/>
          <stop offset="50%" stop-color="#fbbf24"/>
          <stop offset="100%" stop-color="#d97706"/>
        </linearGradient>
        <filter id="apex-glow" x="-70%" y="-70%" width="240%" height="240%">
          <feGaussianBlur stdDeviation="2.8" result="blur"/>
          <feColorMatrix in="blur" values="0 0 0 0 0.85  0 0 0 0 0.55  0 0 0 0 1  0 0 0 1 0"/>
          <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <circle cx="24" cy="24" r="22" fill="url(#apex-halo)"/>
      <circle cx="24" cy="24" r="20" fill="none" stroke="#fbbf24" stroke-width="1.4" opacity="0.9"/>
      <circle cx="24" cy="24" r="17" fill="none" stroke="#f5f3ff" stroke-width="0.7" opacity="0.6"/>
      <g filter="url(#apex-glow)">
        <path fill="${OUTLINE}" d="M24 4 L40 11 V25 C40 33 33 40 24 44 S8 33 8 25 V11 Z"/>
        <path fill="url(#apex-shield)" stroke="#fbbf24" stroke-width="1.5"
          d="M24 6 L38 12 V25 C38 32 32 38 24 42 S10 32 10 25 V12 Z"/>
        <path fill="none" stroke="#c084fc" stroke-width="0.8" opacity="0.7"
          d="M24 9 L35 14 V24 C35 30 30 35 24 38 S13 30 13 24 V14 Z"/>
        <path fill="url(#apex-gold)" stroke="${OUTLINE}" stroke-width="0.6"
          d="M10 34 L12 30 H14 L13 34 Z M34 34 L36 30 H38 L37 34 Z M20 36 H28 L27 39 H21 Z"/>
        <circle cx="12" cy="32" r="3" fill="#fbbf24" stroke="#fff" stroke-width="0.6"/>
        <text x="12" y="33.5" text-anchor="middle" font-size="4.5" font-weight="900" fill="${OUTLINE}" font-family="Arial">$</text>
        <circle cx="36" cy="32" r="3" fill="#fbbf24" stroke="#fff" stroke-width="0.6"/>
        <text x="36" y="33.5" text-anchor="middle" font-size="4.5" font-weight="900" fill="${OUTLINE}" font-family="Arial">$</text>
        <text x="24" y="27" text-anchor="middle" font-size="13" font-weight="900" fill="#ffffff" font-family="Arial Black,Impact,sans-serif" letter-spacing="0.5">NFG</text>
        <text x="24" y="27" text-anchor="middle" font-size="13" font-weight="900" fill="none" stroke="${OUTLINE}" stroke-width="1.2" font-family="Arial Black,Impact,sans-serif" letter-spacing="0.5">NFG</text>
        <text x="24" y="35.5" text-anchor="middle" font-size="8" font-weight="900" fill="#fbbf24" font-family="Arial Black,sans-serif" letter-spacing="1">$ $ $</text>
      </g>
    </svg>`,

    crown: `<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <rect x="5" y="31" width="38" height="9" rx="2" fill="${OUTLINE}"/>
      <rect x="7" y="33" width="34" height="5" rx="1" fill="#7c3aed" stroke="#f5f3ff" stroke-width="0.8"/>
      <path fill="${OUTLINE}" d="M6 31 L10 12 L16 21 L24 6 L32 21 L38 12 L42 31 Z"/>
      <path fill="#fbbf24" stroke="#ffffff" stroke-width="1" d="M8 30 L11 14 L16 22 L24 9 L32 22 L37 14 L40 30 Z"/>
      <circle cx="24" cy="22" r="9" fill="#2e1065" stroke="#ffffff" stroke-width="1.2"/>
      <path fill="none" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round"
        d="M24 17v10M20.5 19.5c0-2.2 1.6-3 3.5-3s3.5.8 3.5 3-1.6 3-3.5 3m0 1.5c2 0 3.5 1 3.5 2.8s-1.5 2.7-3.5 2.7-3.5-1.2-3.5-2.7 1.5-2.8 3.5-2.8z"/>
    </svg>`,
  };

  const VALID = new Set(Object.keys(SVG));

  function escapeAttr(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;");
  }

  function render(badgeId, opts) {
    const id = resolveBadgeId(badgeId);
    if (!VALID.has(id)) return "";
    const title = (opts && opts.title) || LABELS[id] || id;
    const extraClass = (opts && opts.className) || "";
    const animClass =
      id === "imperial" ? " nfg-badge--imperial" : id === "chip" ? " nfg-badge--chip" : "";
    return `<span class="nfg-badge nfg-badge--${id}${animClass}${extraClass ? ` ${extraClass}` : ""}" data-badge="${id}" title="${escapeAttr(title)}" aria-hidden="true">${SVG[id]}</span>`;
  }

  global.NFG_BADGE_ICONS = {
    render,
    resolveBadgeId,
    labels: () => ({ ...LABELS }),
    LABELS,
    VALID,
    SVG,
  };
})(typeof window !== "undefined" ? window : globalThis);
