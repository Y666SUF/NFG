/** Full-size vault icon preview — uses NFG_BADGE_ICONS SVGs from the live game. */

const NAME_FX_META = {
  neon: { icon: "✨", label: "Neon", sampleCls: "namefx-neon" },
  royal: { icon: "👑", label: "Royal", sampleCls: "namefx-royal" },
  fire: { icon: "🔥", label: "Fire", sampleCls: "namefx-fire" },
  ice: { icon: "❄️", label: "Ice", sampleCls: "namefx-ice" },
  shadow: { icon: "🌑", label: "Shadow", sampleCls: "namefx-shadow" },
  rainbow: { icon: "🌈", label: "Rainbow", sampleCls: "namefx-rainbow" },
  pulse: { icon: "💫", label: "Pulse", sampleCls: "namefx-pulse" },
  glitch: { icon: "⚡", label: "Glitch", sampleCls: "namefx-glitch" },
};

let lightboxEl = null;

function ensureLightbox() {
  if (lightboxEl) return lightboxEl;
  const root = document.createElement("div");
  root.id = "iconLightbox";
  root.className = "icon-lightbox";
  root.hidden = true;
  root.innerHTML = `
    <div class="icon-lightbox-backdrop" data-close-lightbox></div>
    <div class="icon-lightbox-card" role="dialog" aria-modal="true" aria-labelledby="iconLightboxTitle">
      <button type="button" class="icon-lightbox-close" data-close-lightbox aria-label="Close">×</button>
      <div class="icon-lightbox-art" id="iconLightboxArt"></div>
      <h3 class="icon-lightbox-title" id="iconLightboxTitle"></h3>
      <p class="icon-lightbox-sub" id="iconLightboxSub"></p>
      <p class="icon-lightbox-hint muted">Tap outside or × to close</p>
    </div>
  `;
  document.body.appendChild(root);
  root.querySelectorAll("[data-close-lightbox]").forEach((el) => {
    el.addEventListener("click", closeIconPreview);
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && lightboxEl && !lightboxEl.hidden) closeIconPreview();
  });
  lightboxEl = root;
  return root;
}

export function closeIconPreview() {
  if (!lightboxEl) return;
  lightboxEl.hidden = true;
  document.body.classList.remove("icon-lightbox-open");
}

export function openBadgePreview(badgeId, meta = {}) {
  const icons = window.NFG_BADGE_ICONS;
  if (!icons?.SVG) return;
  const id = icons.resolveBadgeId(badgeId);
  const svg = icons.SVG[id];
  if (!svg) return;

  const lb = ensureLightbox();
  const title = meta.label || icons.LABELS?.[id] || id;
  const tier = meta.tier ? `Tier ${meta.tier}` : "";
  const cost = meta.cost != null ? `${Number(meta.cost).toLocaleString()} pts` : "";
  const sub = [tier, cost, meta.sub].filter(Boolean).join(" · ");

  lb.querySelector("#iconLightboxArt").innerHTML = `
    <div class="icon-lightbox-badge nfg-badge nfg-badge--${id}${id === "imperial" ? " nfg-badge--imperial" : id === "chip" ? " nfg-badge--chip" : ""}">
      ${svg}
    </div>`;
  lb.querySelector("#iconLightboxTitle").textContent = title;
  lb.querySelector("#iconLightboxSub").textContent = sub || `Vault status icon · !buy ${id}`;
  lb.hidden = false;
  document.body.classList.add("icon-lightbox-open");
}

export function openNameFxPreview(styleId, meta = {}) {
  const id = String(styleId || "").toLowerCase();
  const fx = NAME_FX_META[id];
  if (!fx) return;
  const lb = ensureLightbox();
  const cost = meta.cost != null ? `${Number(meta.cost).toLocaleString()} pts` : "";
  lb.querySelector("#iconLightboxArt").innerHTML = `
    <div class="icon-lightbox-namefx">
      <span class="icon-lightbox-fx-emoji">${fx.icon}</span>
      <span class="namefx ${fx.sampleCls} icon-lightbox-fx-sample">
        <span class="namefx-text">Your Name</span>
      </span>
    </div>`;
  lb.querySelector("#iconLightboxTitle").textContent = `${fx.label} Name FX`;
  lb.querySelector("#iconLightboxSub").textContent =
    [cost, `!namefx ${id}`].filter(Boolean).join(" · ") || `!namefx ${id}`;
  lb.hidden = false;
  document.body.classList.add("icon-lightbox-open");
}

export function bindIconPreviews(root = document) {
  if (!root?.querySelectorAll) return;
  root.querySelectorAll("[data-icon-preview]").forEach((el) => {
    if (el.dataset.previewBound) return;
    el.dataset.previewBound = "1";
    el.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const badgeId = el.dataset.iconPreview;
      const styleId = el.dataset.namefxPreview;
      if (badgeId) {
        openBadgePreview(badgeId, {
          label: el.dataset.previewLabel,
          tier: el.dataset.previewTier,
          cost: el.dataset.previewCost,
          sub: el.dataset.previewSub,
        });
      } else if (styleId) {
        openNameFxPreview(styleId, { cost: el.dataset.previewCost });
      }
    });
  });
}

export function renderBadgeLarge(badgeId, className = "shop-badge-lg") {
  const icons = window.NFG_BADGE_ICONS;
  if (!icons?.render) return "";
  return icons.render(badgeId, { className });
}
