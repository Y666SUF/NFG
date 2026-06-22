import { api, isMobileGameDevice, getSession } from "./shared.js";
import { createJumpEngine } from "./jump-engine.js";

async function jumpApi(action, payload) {
  const { ok, data } = await api("/api/mobile/arcade/play", {
    method: "POST",
    body: { gameId: "nfg_snake_jump", action, payload },
  });
  const res = data || {};
  if (!ok && res.message) throw new Error(res.message);
  if (!ok && res.reason) throw new Error(String(res.reason).replace(/_/g, " "));
  return res;
}

function mountDesktopGate(container) {
  container.innerHTML = `
    <div class="jump-desktop-gate">
      <div class="jump-gate-icon">📱</div>
      <h3 class="jump-gate-title">NFG Jump is phone-only</h3>
      <p class="jump-gate-lede">
        This game works like TikTok DM emoji jump — your profile photo bounces up platforms.
        Use your iPhone in Safari at <strong>/play</strong>, or join the app beta below.
      </p>
      <p class="jump-gate-note muted">
        The iOS app cannot be submitted to the App Store yet due to gambling-simulation policy.
        We are collecting beta testers for TestFlight.
      </p>
      <form class="jump-beta-form" id="jumpBetaForm">
        <label class="field">
          <span>Email for beta access</span>
          <input type="email" id="jumpBetaEmail" required placeholder="you@example.com" autocomplete="email" />
        </label>
        <button type="submit" class="btn primary block vault-cta">Join beta waitlist</button>
      </form>
      <p class="jump-gate-status muted" id="jumpBetaStatus" hidden></p>
      <p class="jump-gate-fine fine">
        Already on iPhone? Open Vault → NFG Jump. Points sync with your TikTok-linked account.
      </p>
    </div>
  `;
  container.querySelector("#jumpBetaForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = container.querySelector("#jumpBetaEmail")?.value?.trim();
    const status = container.querySelector("#jumpBetaStatus");
    if (!email) return;
    try {
      const { ok, data } = await api("/api/mobile/beta-signup", {
        method: "POST",
        body: { email, source: "nfg_jump_web" },
        auth: false,
      });
      if (status) {
        status.hidden = false;
        status.textContent = ok
          ? data?.message || "Thanks — we will email you when a beta slot opens."
          : data?.message || "Could not save your email.";
        status.classList.toggle("jump-gate-err", !ok);
      }
    } catch (err) {
      if (status) {
        status.hidden = false;
        status.textContent = err.message || "Request failed.";
        status.classList.add("jump-gate-err");
      }
    }
  });
}

export function mountJumpGame(container, onWallet, session = null) {
  if (!isMobileGameDevice()) {
    mountDesktopGate(container);
    return;
  }

  const sess = session || getSession();
  const userId = sess.userId || "";
  const displayInitial = sess.displayName || userId || "?";
  const avatarUrl = userId
    ? `/api/mobile/player-avatar?user=${encodeURIComponent(userId)}`
    : null;

  container.innerHTML = `
    <div class="jump-fullscreen">
      <div class="jump-hud">
        <div class="jump-hud-left">
          <span class="jump-title">NFG Jump</span>
          <span class="jump-sub" id="jmpHud">Starting…</span>
        </div>
        <div class="jump-hud-right">
          <span class="jump-peak" id="jmpPeak">0 m</span>
        </div>
      </div>
      <div class="jump-stage" id="jmpStage">
        <canvas id="jmpCanvas" aria-label="NFG Jump"></canvas>
      </div>
      <div class="jump-touch-hint" id="jmpHint">Hold left or right side to steer · auto-bounce on platforms</div>
      <div class="jump-toast hidden" id="jmpToast"></div>
    </div>
  `;

  const stage = container.querySelector("#jmpStage");
  const canvas = container.querySelector("#jmpCanvas");
  const ctx = canvas.getContext("2d");
  const engine = createJumpEngine();
  const avatarImg = new Image();
  if (avatarUrl) avatarImg.src = avatarUrl;

  let raf = 0;
  let sessionActive = false;
  let syncing = false;
  let pointerId = null;

  function showToast(msg, kind = "info") {
    const el = container.querySelector("#jmpToast");
    if (!el) return;
    el.textContent = msg;
    el.className = `jump-toast jump-toast--${kind}`;
    el.classList.remove("hidden");
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => el.classList.add("hidden"), 2400);
  }

  function resize() {
    const w = stage?.clientWidth || window.innerWidth;
    const h = stage?.clientHeight || window.innerHeight - 80;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    engine.setSize(w, h);
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function updateHud(text, peak) {
    const hud = container.querySelector("#jmpHud");
    const peakEl = container.querySelector("#jmpPeak");
    if (hud && text) hud.textContent = text;
    if (peakEl != null && peak != null) peakEl.textContent = `${peak} m`;
  }

  async function startRun() {
    resize();
    const data = await jumpApi("start");
    sessionActive = true;
    engine.reset();
    updateHud(`Session ${(data.sessionPoints || 0).toLocaleString()} pts`, 0);
    if (onWallet) onWallet(data);
    loop();
  }

  async function syncMilestone(height) {
    if (syncing) return;
    syncing = true;
    try {
      const data = await jumpApi("milestone", { height });
      showToast(data.message || `+${data.gained || 0} pts!`, "win");
      updateHud(`Session ${(data.sessionPoints || 0).toLocaleString()} pts`, height);
      if (onWallet) onWallet(data);
    } catch (e) {
      showToast(e.message, "err");
    } finally {
      syncing = false;
    }
  }

  async function endRun(peak) {
    cancelAnimationFrame(raf);
    sessionActive = false;
    engine.setTouch(null, false);
    try {
      const data = await jumpApi("game_over", { height: peak });
      showToast(data.message || "Run over", peak > 0 ? "info" : "err");
      updateHud(`Best ${(data.score || peak || 0).toLocaleString()} m`, peak);
      if (onWallet) onWallet(data);
    } catch (e) {
      showToast(e.message, "err");
    }
    setTimeout(() => startRun().catch((e) => showToast(e.message, "err")), 1400);
  }

  function loop() {
    const frame = engine.step();
    engine.draw(ctx, frame, avatarImg, displayInitial);
    updateHud(null, frame.meters);
    if (frame.milestoneDue) syncMilestone(frame.milestoneDue);
    if (!frame.alive && sessionActive) {
      endRun(engine.getPeak());
      return;
    }
    if (sessionActive) raf = requestAnimationFrame(loop);
  }

  function touchX(clientX) {
    const rect = stage.getBoundingClientRect();
    return clientX - rect.left;
  }

  function onTouchStart(e) {
    if (!sessionActive) return;
    e.preventDefault();
    const t = e.touches?.[0];
    if (!t) return;
    pointerId = t.identifier;
    engine.setTouch(touchX(t.clientX), true);
    container.querySelector("#jmpHint")?.classList.add("hidden");
  }

  function onTouchMove(e) {
    if (!sessionActive) return;
    e.preventDefault();
    const t = [...(e.touches || [])].find((x) => x.identifier === pointerId) || e.touches?.[0];
    if (!t) return;
    engine.setTouch(touchX(t.clientX), true);
  }

  function onTouchEnd(e) {
    if (!sessionActive) return;
    const ended = [...(e.changedTouches || [])].some((t) => t.identifier === pointerId);
    if (!ended && e.touches?.length) return;
    pointerId = null;
    engine.setTouch(null, false);
  }

  stage.addEventListener("touchstart", onTouchStart, { passive: false });
  stage.addEventListener("touchmove", onTouchMove, { passive: false });
  stage.addEventListener("touchend", onTouchEnd);
  stage.addEventListener("touchcancel", onTouchEnd);

  stage.addEventListener("pointerdown", (e) => {
    if (!sessionActive || e.pointerType === "touch") return;
    pointerId = e.pointerId;
    try {
      stage.setPointerCapture(e.pointerId);
    } catch {
      /* ignore */
    }
    engine.setTouch(touchX(e.clientX), true);
    container.querySelector("#jmpHint")?.classList.add("hidden");
  });

  stage.addEventListener("pointermove", (e) => {
    if (!sessionActive || e.pointerType === "touch" || pointerId !== e.pointerId) return;
    engine.setTouch(touchX(e.clientX), true);
  });

  stage.addEventListener("pointerup", (e) => {
    if (e.pointerType === "touch") return;
    if (pointerId !== e.pointerId) return;
    pointerId = null;
    engine.setTouch(null, false);
  });

  window.addEventListener("resize", resize);
  resize();
  jumpApi("status")
    .then((data) => {
      resize();
      if (data.sessionActive) {
        sessionActive = true;
        engine.reset();
        updateHud(`Session ${(data.sessionPoints || 0).toLocaleString()} pts`, data.peakHeight || 0);
        loop();
        return;
      }
      return startRun();
    })
    .catch((e) => showToast(e.message || "Could not start", "err"));

  return { startRun };
}
