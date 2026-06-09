import { SnakeJumpEngine } from "./jump-engine.js";
import { loadTikTokJumpAvatar, revokeAvatarObjectUrl } from "./avatar-cache.js";
import { drawJumpSky } from "./jump-sky.js";
import { mergeJumpShop } from "./jump-shop-catalog.js";

export function mountJumpGame(container, hooks) {
  const engine = new SnakeJumpEngine();
  let raf = 0;
  let last = performance.now();
  let moveLeft = false;
  let moveRight = false;
  let steer = 0;
  let milestoneSync = 0;
  let running = false;
  let sessionActive = false;
  let vsMode = false;
  let vsProgressTick = 0;
  let ghostOpponents = [];

  const wrap = document.createElement("div");
  wrap.className = "skill-game jump-game";
  wrap.innerHTML = `
    <div class="skill-hud" id="jumpHud"></div>
    <div class="jump-stage">
      <button type="button" class="jump-shop-btn" id="jumpShopBtn" title="Circle shop">🛍 Shop</button>
      <canvas class="jump-canvas" id="jumpCanvas"></canvas>
    </div>
    <div class="jump-shop-panel hidden" id="jumpShopPanel">
      <div class="jump-shop-head">
        <strong>Circle Shop</strong>
        <button type="button" class="btn ghost sm" id="jumpShopClose">Close</button>
      </div>
      <p class="fine" id="jumpShopBalance"></p>
      <p class="fine jump-shop-msg" id="jumpShopMsg"></p>
      <div class="jump-shop-list" id="jumpShopList"></div>
    </div>
    <p class="arcade-msg" id="jumpMsg"></p>
    <div class="jump-vs-panel hidden" id="jumpVsPanel">
      <div class="jump-vs-head">
        <strong>Jump VS</strong>
        <span class="jump-vs-phase" id="jumpVsPhase">Lobby</span>
      </div>
      <p class="fine" id="jumpVsMsg">2+ players start a 15s countdown. Winner takes the combined pot.</p>
      <ul class="jump-vs-players" id="jumpVsPlayers"></ul>
      <div class="btn-row">
        <button type="button" class="btn primary sm" id="jumpVsJoin">Join VS lobby</button>
        <button type="button" class="btn ghost sm" id="jumpVsLeave" hidden>Leave lobby</button>
      </div>
    </div>
    <div class="jump-controls">
      <button type="button" class="jump-btn" id="jumpLeft">◀</button>
      <button type="button" class="btn primary" id="jumpStart">New run</button>
      <button type="button" class="jump-btn" id="jumpRight">▶</button>
    </div>
  `;
  container.appendChild(wrap);

  const canvas = wrap.querySelector("#jumpCanvas");
  const ctx = canvas.getContext("2d");
  const hud = wrap.querySelector("#jumpHud");
  const msgEl = wrap.querySelector("#jumpMsg");
  const shopPanel = wrap.querySelector("#jumpShopPanel");
  const shopList = wrap.querySelector("#jumpShopList");
  const shopBalance = wrap.querySelector("#jumpShopBalance");
  const shopMsg = wrap.querySelector("#jumpShopMsg");
  const vsPanel = wrap.querySelector("#jumpVsPanel");
  const vsPhase = wrap.querySelector("#jumpVsPhase");
  const vsMsg = wrap.querySelector("#jumpVsMsg");
  const vsPlayers = wrap.querySelector("#jumpVsPlayers");
  const vsJoinBtn = wrap.querySelector("#jumpVsJoin");
  const vsLeaveBtn = wrap.querySelector("#jumpVsLeave");

  let skinFill = hooks.skinFill || "#596ff2";
  let skinRing = hooks.skinRing || "#f2c733";
  let profileImage = null;
  let profileObjectUrl = null;

  function setMsg(t) {
    msgEl.textContent = t || "";
  }

  function renderVsLobby(state) {
    if (!state) return;
    vsPhase.textContent =
      state.phase === "countdown"
        ? `Starting in ${state.countdownSeconds}s`
        : state.phase === "match"
          ? "Match live"
          : state.phase === "results"
            ? "Results"
            : "Lobby";
    const rows = (state.players || [])
      .map((p) => {
        const tag = p.eliminated ? " (out)" : "";
        return `<li>${p.displayName || p.id} — ${p.height || 0}m${tag}</li>`;
      })
      .join("");
    vsPlayers.innerHTML = rows || "<li>Waiting for players…</li>";
    if (state.phase === "countdown") {
      vsMsg.textContent = `${state.players?.length || 0} players — match starts in ${state.countdownSeconds}s`;
    } else if (state.phase === "match") {
      vsMsg.textContent = "Stay within one milestone of the leader or you're eliminated!";
    } else if (state.phase === "results") {
      vsMsg.textContent = state.winnerId
        ? `Winner takes ${(state.pot || 0).toLocaleString()} pts`
        : "Match ended.";
    } else {
      vsMsg.textContent = "2+ players start a 15s countdown. Winner takes the combined pot.";
    }
  }

  function drawGhostSnake(x, y, fill, ring) {
    const pr = SnakeJumpEngine.playerRadius * 0.45;
    ctx.globalAlpha = 0.72;
    ctx.fillStyle = fill || "#94a3b8";
    ctx.beginPath();
    ctx.arc(x, y, pr, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = ring || "#cbd5e1";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(x, y, pr, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
  }

  function drawDeadlySpikes(px, py, pw) {
    const spikeW = Math.max(7, pw / 11);
    const spikeH = 11;
    const count = Math.max(2, Math.floor(pw / spikeW));
    const step = pw / count;
    ctx.fillStyle = "#730f0f";
    for (let i = 0; i < count; i += 1) {
      const x = px - pw * 0.5 + i * step + (step - spikeW) * 0.5;
      const top = py - 6 - spikeH;
      ctx.beginPath();
      ctx.moveTo(x, py - 6);
      ctx.lineTo(x + spikeW * 0.5, top);
      ctx.lineTo(x + spikeW, py - 6);
      ctx.closePath();
      ctx.fill();
    }
  }

  function drawPowerUpBolt(x, y, size, rotation) {
    const s = size * 0.38;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(rotation * 0.08);
    ctx.fillStyle = "rgba(255, 255, 255, 0.95)";
    ctx.beginPath();
    ctx.moveTo(s * 0.15, -s * 1.05);
    ctx.lineTo(-s * 0.35, s * 0.05);
    ctx.lineTo(-s * 0.05, s * 0.05);
    ctx.lineTo(-s * 0.25, s * 1.05);
    ctx.lineTo(s * 0.45, -s * 0.15);
    ctx.lineTo(s * 0.12, -s * 0.15);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawGlowingPowerUp(x, y, elapsed, seed) {
    const pulse = 0.86 + 0.14 * Math.sin(elapsed * 5.2 + seed);
    const spin = elapsed * 2.4 + seed;
    const r = 12 * pulse;

    const outer = ctx.createRadialGradient(x, y, 0, x, y, r * 2.1);
    outer.addColorStop(0, `rgba(255, 220, 80, ${0.55 * pulse})`);
    outer.addColorStop(0.45, "rgba(251, 191, 36, 0.18)");
    outer.addColorStop(1, "rgba(251, 191, 36, 0)");
    ctx.fillStyle = outer;
    ctx.beginPath();
    ctx.arc(x, y, r * 2.1, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = "rgba(251, 191, 36, 0.75)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(x, y, r * 0.72, 0, Math.PI * 2);
    ctx.stroke();

    const core = ctx.createRadialGradient(x, y - r * 0.08, 0, x, y, r * 0.55);
    core.addColorStop(0, "#ffffff");
    core.addColorStop(0.55, "#fff7bf");
    core.addColorStop(1, "#fbbf24");
    ctx.fillStyle = core;
    ctx.beginPath();
    ctx.arc(x, y, r * 0.42, 0, Math.PI * 2);
    ctx.fill();

    drawPowerUpBolt(x, y, r * 0.95, spin);
  }

  function drawActiveBoostAura(x, y, elapsed) {
    const pulse = 0.9 + 0.1 * Math.sin(elapsed * 8);
    const auraY = y - 8;
    const aura = ctx.createRadialGradient(x, auraY, 4, x, auraY, 34 * pulse);
    aura.addColorStop(0, `rgba(251, 191, 36, ${0.38 * pulse})`);
    aura.addColorStop(0.5, "rgba(251, 191, 36, 0.12)");
    aura.addColorStop(1, "rgba(251, 191, 36, 0)");
    ctx.fillStyle = aura;
    ctx.beginPath();
    ctx.arc(x, auraY, 34 * pulse, 0, Math.PI * 2);
    ctx.fill();
  }

  function renderShop() {
    const items = mergeJumpShop(hooks.jumpShop, hooks.equippedSkin, hooks.ownedSkins);
    const balance = hooks.balance ?? 0;
    shopBalance.textContent = `Balance: ${balance.toLocaleString()} pts`;
    shopList.innerHTML = items
      .map((item) => {
        const owned = !!item.owned;
        const equipped = !!item.equipped;
        const action = equipped
          ? `<span class="jump-shop-equipped">Equipped</span>`
          : owned
            ? `<button type="button" class="btn primary sm" data-equip="${item.id}">Equip</button>`
            : `<button type="button" class="btn primary sm" data-buy="${item.id}" ${balance < item.cost ? "disabled" : ""}>Buy ${item.cost === 0 ? "Free" : item.cost.toLocaleString()}</button>`;
        return `
          <div class="jump-shop-item">
            <span class="jump-shop-preview" style="--fill:${item.fill};--ring:${item.ring}"></span>
            <div class="jump-shop-meta">
              <strong>${item.name}</strong>
              <span class="fine">${item.desc || ""}</span>
            </div>
            ${action}
          </div>
        `;
      })
      .join("");
    shopList.querySelectorAll("[data-buy]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          const res = await hooks.onBuySkin(btn.dataset.buy);
          if (res?.skinFill) skinFill = res.skinFill;
          if (res?.skinRing) skinRing = res.skinRing;
          shopMsg.textContent = res?.message || "Purchased!";
          shopMsg.style.color = "var(--accent2)";
          renderShop();
        } catch (e) {
          shopMsg.textContent = e.message || "Purchase failed.";
          shopMsg.style.color = "var(--danger)";
        }
      });
    });
    shopList.querySelectorAll("[data-equip]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          const res = await hooks.onEquipSkin(btn.dataset.equip);
          if (res?.skinFill) skinFill = res.skinFill;
          if (res?.skinRing) skinRing = res.skinRing;
          shopMsg.textContent = res?.message || "Equipped!";
          shopMsg.style.color = "var(--accent2)";
          renderShop();
        } catch (e) {
          shopMsg.textContent = e.message || "Equip failed.";
          shopMsg.style.color = "var(--danger)";
        }
      });
    });
  }

  function resize() {
    const rect = canvas.parentElement.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.floor(rect.width * dpr);
    canvas.height = Math.floor(Math.min(420, rect.width * 1.1) * dpr);
    canvas.style.height = `${Math.min(420, rect.width * 1.1)}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function draw() {
    const w = canvas.width / (window.devicePixelRatio || 1);
    const h = canvas.height / (window.devicePixelRatio || 1);
    ctx.clearRect(0, 0, w, h);
    drawJumpSky(ctx, w, h, engine.currentHeight, engine.cameraAnchorY, engine.elapsed);

    const cam = engine.cameraAnchorY;
    const scaleX = w / (engine.lastViewWidth * 1.1);

    for (const plat of engine.platforms) {
      const px = plat.centerX(engine.elapsed) * scaleX + w * 0.5;
      const py = h - (plat.y - cam) - 40;
      if (py < -30 || py > h + 30) continue;
      ctx.fillStyle = engine.platformColor(plat.kind);
      const pw = plat.width * scaleX;
      ctx.fillRect(px - pw * 0.5, py - 6, pw, 12);
      if (plat.kind === "deadly") {
        drawDeadlySpikes(px, py, pw);
      }
    }

    for (const pu of engine.powerUps) {
      if (pu.collected) continue;
      const px = pu.x * scaleX + w * 0.5;
      const py = h - (pu.y - cam) - 40;
      if (py < -20 || py > h + 20) continue;
      drawGlowingPowerUp(px, py, engine.elapsed, pu.x * 0.017);
    }

    const playerScreenX = engine.playerX * scaleX + w * 0.5;
    const playerScreenY = h - (engine.playerY - cam) - 40;
    const pr = SnakeJumpEngine.playerRadius * 0.55;
    if (engine.boostLiftRemaining > 0) {
      drawActiveBoostAura(playerScreenX, playerScreenY, engine.elapsed);
    }
    ctx.fillStyle = skinFill;
    ctx.beginPath();
    ctx.arc(playerScreenX, playerScreenY, pr, 0, Math.PI * 2);
    ctx.fill();
    if (profileImage && profileImage.complete && profileImage.naturalWidth > 0) {
      ctx.save();
      ctx.beginPath();
      ctx.arc(playerScreenX, playerScreenY, pr, 0, Math.PI * 2);
      ctx.clip();
      ctx.drawImage(profileImage, playerScreenX - pr, playerScreenY - pr, pr * 2, pr * 2);
      ctx.restore();
    }
    ctx.strokeStyle = skinRing;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(playerScreenX, playerScreenY, pr, 0, Math.PI * 2);
    ctx.stroke();

    for (const opp of ghostOpponents) {
      const ox = (opp.x ?? 0) * scaleX + w * 0.5;
      const oy = h - ((opp.worldY ?? 0) - cam) - 40;
      if (oy < -30 || oy > h + 30) continue;
      drawGhostSnake(ox, oy, opp.fill, opp.ring);
    }

    hud.innerHTML = `
      <span><strong>${engine.currentHeight}m</strong></span>
      <span>Best ${hooks.bestHeight || 0}m</span>
      <span>Session ${(hooks.sessionPoints || 0).toLocaleString()} pts</span>
      <span>Next +${hooks.rewardPreview || 3000} @ ${engine.nextMilestoneHeight}m</span>
      ${vsMode ? `<span class="jump-vs-tag">VS ${ghostOpponents.length} ghosts</span>` : ""}
    `;
  }

  async function syncMilestone() {
    if (!sessionActive || milestoneSync > 0) return;
    while (engine.reachedNewMilestone && sessionActive) {
      milestoneSync += 1;
      const height = engine.currentHeight;
      try {
        const res = await hooks.onMilestone(height);
        engine.milestonesClaimed = res?.sessionMilestones ?? engine.milestonesClaimed + 1;
        hooks.sessionPoints = res?.sessionPoints ?? hooks.sessionPoints;
        setMsg(res?.message || `Milestone at ${height}m!`);
      } catch (e) {
        setMsg(e.message);
        break;
      } finally {
        milestoneSync -= 1;
      }
    }
  }

  function loop(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    if (sessionActive && running) {
      const w = canvas.width / (window.devicePixelRatio || 1);
      const h = canvas.height / (window.devicePixelRatio || 1);
      engine.tick(dt, { steer, moveLeft, moveRight, viewWidth: engine.lastViewWidth, viewHeight: h });
      if (engine.reachedNewMilestone) syncMilestone();
      if (vsMode && hooks.vsClient && vsProgressTick++ % 8 === 0) {
        hooks.vsClient.reportProgress(engine.currentHeight, hooks.sessionPoints || 0);
      }
      if (engine.gameOver) {
        running = false;
        sessionActive = false;
        endRun(engine.currentHeight);
      }
    }
    draw();
    raf = requestAnimationFrame(loop);
  }

  async function endRun(height) {
    try {
      if (vsMode && hooks.vsClient) {
        hooks.vsClient.send({ type: "forfeit" });
      }
      const res = await hooks.onGameOver(height);
      hooks.bestHeight = res?.bestLevel ?? hooks.bestHeight;
      hooks.sessionPoints = res?.sessionPoints ?? hooks.sessionPoints;
      setMsg(res?.message || `Run over at ${height}m`);
    } catch (e) {
      setMsg(e.message);
    }
  }

  function bindHold(btn, on) {
    const down = () => {
      on(true);
    };
    const up = () => {
      on(false);
    };
    btn.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      down();
    });
    btn.addEventListener("pointerup", up);
    btn.addEventListener("pointerleave", up);
    btn.addEventListener("pointercancel", up);
  }

  bindHold(wrap.querySelector("#jumpLeft"), (v) => {
    moveLeft = v;
  });
  bindHold(wrap.querySelector("#jumpRight"), (v) => {
    moveRight = v;
  });

  wrap.querySelector("#jumpShopBtn").addEventListener("click", () => {
    renderShop();
    shopPanel.classList.remove("hidden");
  });
  wrap.querySelector("#jumpShopClose").addEventListener("click", () => {
    shopPanel.classList.add("hidden");
  });

  vsJoinBtn.addEventListener("click", () => {
    hooks.onVsJoin?.();
  });
  vsLeaveBtn.addEventListener("click", () => {
    hooks.onVsLeave?.();
  });

  wrap.querySelector("#jumpStart").addEventListener("click", async () => {
    try {
      const startPayload = vsMode && hooks.vsMatchId ? { vsMatchId: hooks.vsMatchId } : {};
      const res = await hooks.onStart(startPayload);
      if (vsMode && hooks.vsMatchSeed != null) {
        engine.setMatchSeed(hooks.vsMatchSeed);
      } else {
        engine.reset(canvas.clientWidth || 320);
      }
      engine.milestonesClaimed = res?.sessionMilestones || 0;
      hooks.sessionPoints = res?.sessionPoints ?? 0;
      sessionActive = true;
      running = true;
      setMsg(res?.message || "Climb!");
    } catch (e) {
      setMsg(e.message);
    }
  });

  canvas.addEventListener(
    "pointermove",
    (e) => {
      const rect = canvas.getBoundingClientRect();
      steer = ((e.clientX - rect.left) / rect.width - 0.5) * 2;
    },
    { passive: true }
  );

  async function loadProfileAvatar(force = false) {
    const objectUrl = await loadTikTokJumpAvatar({ force });
    if (!objectUrl) return;
    if (profileObjectUrl && profileObjectUrl !== objectUrl) {
      revokeAvatarObjectUrl(profileObjectUrl);
    }
    profileObjectUrl = objectUrl;
    const img = new Image();
    img.onload = () => {
      profileImage = img;
    };
    img.onerror = () => {
      profileImage = null;
    };
    img.src = objectUrl;
  }

  vsPanel.classList.remove("hidden");

  loadProfileAvatar(false);

  resize();
  window.addEventListener("resize", resize);
  raf = requestAnimationFrame(loop);

  return {
    destroy() {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
      revokeAvatarObjectUrl(profileObjectUrl);
      wrap.remove();
    },
    refresh(h) {
      Object.assign(hooks, h);
      if (h.sessionMilestones != null) engine.milestonesClaimed = h.sessionMilestones;
      if (h.skinFill) skinFill = h.skinFill;
      if (h.skinRing) skinRing = h.skinRing;
      vsMode = !!h.vsMode;
      if (h.ghostOpponents) ghostOpponents = h.ghostOpponents;
      if (h.vsLobbyState) renderVsLobby(h.vsLobbyState);
      vsJoinBtn.hidden = vsMode;
      vsLeaveBtn.hidden = !vsMode;
      if (!shopPanel.classList.contains("hidden")) renderShop();
    },
  };
}
