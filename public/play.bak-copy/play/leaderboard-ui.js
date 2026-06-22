import { esc, fmtPts } from "./shared.js";

const NAME_STYLE_META = {
  none: { icon: "", cls: "namefx-none" },
  neon: { icon: "✨", cls: "namefx-neon" },
  royal: { icon: "👑", cls: "namefx-royal" },
  fire: { icon: "🔥", cls: "namefx-fire" },
  ice: { icon: "❄️", cls: "namefx-ice" },
  shadow: { icon: "🌑", cls: "namefx-shadow" },
  rainbow: { icon: "🌈", cls: "namefx-rainbow" },
  pulse: { icon: "💫", cls: "namefx-pulse" },
  glitch: { icon: "⚡", cls: "namefx-glitch" },
};

function badgeHtml(badgeId) {
  const id = String(badgeId || "none").trim().toLowerCase();
  if (!id || id === "none") return "";
  const label = window.NFG_BADGE_ICONS?.LABELS?.[id] || id;
  if (typeof window !== "undefined" && window.NFG_BADGE_ICONS?.render) {
    const inner = window.NFG_BADGE_ICONS.render(id, { className: "lb-badge-icon" });
    return `<button type="button" class="icon-preview-btn" data-icon-preview="${esc(id)}" data-preview-label="${esc(label)}" aria-label="View ${esc(label)} icon">${inner}</button>`;
  }
  return `<span class="lb-badge-fallback" title="${esc(id)}">◆</span>`;
}

export function formatShieldLeft(ms) {
  const left = Math.max(0, Math.floor(Number(ms) || 0));
  if (!left) return "";
  const h = Math.floor(left / 3600000);
  const m = Math.floor((left % 3600000) / 60000);
  if (h >= 48) return `${Math.floor(h / 24)}d left`;
  if (h > 0) return `${h}h ${m}m`;
  return `${Math.max(1, m)}m`;
}

function displayName(row) {
  return String(row?.displayName || row?.user || row?.name || "?").trim();
}

function userId(row) {
  return String(row?.user || row?.name || "").trim();
}

export function renderPlayerName(row, { compact = false } = {}) {
  const style = String(row?.nameStyle || "none").toLowerCase();
  const meta = NAME_STYLE_META[style] || NAME_STYLE_META.none;
  const name = esc(displayName(row));
  const icon = meta.icon ? `<span class="namefx-icon">${meta.icon}</span>` : "";
  const superFan =
    row?.superFan === true
      ? `<span class="sf-pill" title="Super Fan">★${row.superFanLevel > 1 ? row.superFanLevel : ""}</span>`
      : "";
  const badge = badgeHtml(row?.nameBadge);
  const lvl = compact
    ? ""
    : `<span class="lb-rank-meta">${esc(row?.rank || "Rookie")} · Lv ${Math.max(1, Number(row?.level) || 1)}</span>`;
  return `<span class="namefx ${meta.cls} lb-namefx">
    ${badge}${superFan}${icon}<span class="namefx-text">${name}</span>${lvl}
  </span>`;
}

export function renderTopCard(row, position) {
  if (!row) {
    return `<div class="top-card top-card--empty"><span class="muted">—</span></div>`;
  }
  const bal = Number(row.balance ?? row.points ?? 0);
  const balCls = bal >= 1_000_000 ? "gold" : bal >= 100_000 ? "hi" : "";
  return `<button type="button" class="top-card top-card--pos-${position}" data-open-board title="${esc(userId(row))}">
    <span class="top-card-rank">#${position}</span>
    <span class="top-card-name">${renderPlayerName(row, { compact: true })}</span>
    <span class="top-card-bal ${balCls}">${fmtPts(bal)}</span>
    ${row.superFan ? '<span class="sf-pill">★</span>' : ""}
  </button>`;
}

export function renderBoardRow(row, position, currentUser = "") {
  const you =
    currentUser && userId(row).toLowerCase() === currentUser.toLowerCase() ? ' board-row--you' : "";
  const shield =
    row.shieldActive === true
      ? `<span class="board-shield" title="Shield active">🛡 ${formatShieldLeft(row.shieldMsLeft) || "active"}</span>`
      : "";
  const bal = Number(row.balance ?? row.points ?? 0);
  return `<li class="board-row${you}">
    <span class="board-pos">${position}</span>
    <div class="board-main">
      <div class="board-name-line">${renderPlayerName(row)}${shield}</div>
      <div class="board-user muted">@${esc(userId(row))}</div>
    </div>
    <span class="board-bal">${fmtPts(bal)}</span>
  </li>`;
}

export function renderTopStrip(rows, total = 0) {
  const cards = [1, 2, 3, 4, 5].map((i) => renderTopCard(rows[i - 1], i)).join("");
  const count =
    total > 0
      ? `${rows.length} of ${total} shown · tap for full board`
      : "Tap for full leaderboard";
  return `<div class="top-profiles">
    <div class="top-profiles-head">
      <span class="top-profiles-title">Top 5</span>
      <button type="button" class="top-profiles-link" data-open-board>${esc(count)} →</button>
    </div>
    <div class="top-profiles-grid">${cards}</div>
  </div>`;
}
