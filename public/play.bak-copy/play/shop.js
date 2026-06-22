import { api, esc, fmtPts, showToast } from "./shared.js";
import { bindIconPreviews, renderBadgeLarge } from "./icon-preview.js";

export function initShop({ mountEl, onWallet }) {
  if (!mountEl) return { load: () => {} };

  async function load() {
    mountEl.innerHTML = `<p class="muted">Loading shop…</p>`;
    try {
      const { ok, data } = await api("/api/mobile/shop/catalog");
      if (!ok) throw new Error(data?.message || "Could not load shop");
      render(data);
    } catch (e) {
      mountEl.innerHTML = `<p class="shop-err">${esc(e.message || "Shop unavailable")}</p>`;
    }
  }

  function render(catalog) {
    const balance = Number(catalog.balance || 0);
    const activeStyle = String(catalog.nameStyle || "none");
    const activeBadge = String(catalog.nameBadge || "none");
    const owned = new Set((catalog.ownedBadges || []).map((b) => String(b).toLowerCase()));

    const styles = (catalog.nameStyles || []).filter((s) => s.id && s.id !== "none");
    const badges = catalog.nameBadges || [];

    mountEl.innerHTML = `
      <div class="shop-panel">
        <div class="shop-head">
          <h3>Display Shop</h3>
          <p class="muted">Name FX &amp; vault status icons — tap any icon to blow it up full size · <a href="/badge-preview.html" class="shop-gallery-link">full gallery</a></p>
          <p class="shop-bal">Balance: <strong>${fmtPts(balance)}</strong></p>
          <p class="shop-active muted">Active: ${esc(activeStyle)} FX · ${esc(activeBadge)} icon</p>
        </div>
        <h4 class="shop-section-title">Name FX</h4>
        <div class="shop-grid" id="shopStyles">
          ${styles
            .map(
              (s) => `
            <div class="shop-item shop-item--fx${activeStyle === s.id ? " shop-item--active" : ""}">
              <button type="button" class="shop-preview-btn" data-namefx-preview="${esc(s.id)}" data-preview-cost="${s.cost}" aria-label="Preview ${esc(s.id)} FX">
                <span class="shop-fx-emoji">${esc(s.icon || "✦")}</span>
                <span class="shop-preview-lbl">Tap to preview</span>
              </button>
              <div class="shop-item-body">
                <span class="shop-item-label">${esc(s.id)}</span>
                <span class="shop-item-cost">${fmtPts(s.cost)}</span>
                <button type="button" class="btn secondary sm shop-buy-btn" data-style="${esc(s.id)}">${activeStyle === s.id ? "Equipped" : "Buy / Equip"}</button>
              </div>
            </div>`
            )
            .join("")}
        </div>
        <h4 class="shop-section-title">Status icons <span class="muted">(same SVGs as TikTok LIVE)</span></h4>
        <div class="shop-badge-list" id="shopBadges">
          ${badges
            .map((b) => {
              const ownedBadge = owned.has(String(b.id).toLowerCase());
              const equipped = activeBadge === b.id;
              const icon = renderBadgeLarge(b.id, "shop-badge-lg");
              return `
            <div class="shop-badge-card${equipped ? " shop-item--active" : ""}">
              <button type="button" class="shop-badge-preview" data-icon-preview="${esc(b.id)}"
                data-preview-label="${esc(b.label || b.id)}"
                data-preview-tier="${b.tier || ""}"
                data-preview-cost="${b.cost || ""}"
                aria-label="Preview ${esc(b.label || b.id)}">
                ${icon || `<span class="shop-item-icon">${esc(b.short || "◆")}</span>`}
                <span class="shop-preview-lbl">Tap to enlarge</span>
              </button>
              <div class="shop-badge-meta">
                <span class="shop-item-label">${esc(b.label || b.id)}</span>
                <span class="shop-item-tier muted">Tier ${b.tier || "—"}</span>
                <span class="shop-item-cost">${ownedBadge ? "Owned · switch free" : fmtPts(b.cost)}</span>
                ${equipped ? '<span class="shop-tag">Equipped</span>' : ownedBadge ? '<span class="shop-tag">Owned</span>' : ""}
                <button type="button" class="btn secondary sm shop-buy-btn" data-badge="${esc(b.id)}">${equipped ? "Equipped" : ownedBadge ? "Equip" : "Buy"}</button>
              </div>
            </div>`;
            })
            .join("")}
        </div>
        <p class="shop-note fine">Purchases debit your live balance instantly. Owned icons switch for free — same as the iPhone app.</p>
      </div>
    `;

    bindIconPreviews(mountEl);

    mountEl.querySelectorAll("[data-style].shop-buy-btn").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const styleId = btn.dataset.style;
        btn.disabled = true;
        try {
          const { ok, data } = await api("/api/mobile/shop/namefx", {
            method: "POST",
            body: { styleId },
          });
          if (!ok) throw new Error(data?.message || data?.error || "Purchase failed");
          showToast(`${styleId} equipped!`);
          if (onWallet) onWallet(data);
          await load();
        } catch (e) {
          showToast(e.message || "Could not buy Name FX");
        } finally {
          btn.disabled = false;
        }
      });
    });

    mountEl.querySelectorAll("[data-badge].shop-buy-btn").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const badgeId = btn.dataset.badge;
        btn.disabled = true;
        try {
          const { ok, data } = await api("/api/mobile/shop/badge", {
            method: "POST",
            body: { badgeId },
          });
          if (!ok) throw new Error(data?.message || data?.error || "Purchase failed");
          showToast(
            data?.switched
              ? `${data.badgeLabel || badgeId} equipped`
              : `${data.badgeLabel || badgeId} purchased!`
          );
          if (onWallet) onWallet(data);
          await load();
        } catch (e) {
          showToast(e.message || "Could not buy icon");
        } finally {
          btn.disabled = false;
        }
      });
    });
  }

  return { load };
}
