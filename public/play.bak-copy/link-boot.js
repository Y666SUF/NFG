/** Link screen — classic script (CSP allows 'self'; inline onclick does NOT work). */
(function () {
  const DEVICE_KEY = "nfg_web_device";
  const TOKEN_KEY = "nfg_web_token";
  const USER_KEY = "nfg_web_user";
  const NAME_KEY = "nfg_web_name";

  function deviceId() {
    let id = localStorage.getItem(DEVICE_KEY);
    if (!id) {
      id = "web-" + (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()));
      localStorage.setItem(DEVICE_KEY, id);
    }
    return id;
  }

  function $(id) {
    return document.getElementById(id);
  }

  function showErr(msg) {
    const el = $("linkError");
    if (!el) return;
    el.hidden = !msg;
    el.textContent = msg || "";
  }

  async function api(path, opts) {
    const res = await fetch(path, {
      method: opts.method || "GET",
      headers: {
        "Content-Type": "application/json",
        "X-Client-App": "nfg-crash-web",
        "X-Device-Id": deviceId(),
      },
      body: opts.body != null ? JSON.stringify(opts.body) : undefined,
    });
    const data = await res.json().catch(function () {
      return {};
    });
    if (!res.ok) throw new Error(data.message || data.error || "Request failed");
    return data;
  }

  var pollTimer = null;
  var linkCode = "";

  async function startLink(ev) {
    if (ev) {
      ev.preventDefault();
      ev.stopPropagation();
    }
    showErr("");
    var btn = $("btnLinkStart");
    if (btn) btn.disabled = true;
    var review = $("reviewBox");
    if (review) review.hidden = true;
    try {
      var data = await api("/api/mobile/link/start", {
        method: "POST",
        body: { deviceId: deviceId() },
      });
      if (!data.code) throw new Error("Could not start link.");
      linkCode = String(data.code).toUpperCase();
      var status = $("linkStatus");
      var codeEl = $("linkCode");
      var wait = $("linkWait");
      if (status) status.hidden = false;
      if (codeEl) codeEl.textContent = data.tiktokCommand || "!link " + linkCode;
      if (wait) wait.textContent = "Waiting for your TikTok comment on LIVE…";
      clearInterval(pollTimer);
      pollTimer = setInterval(pollLink, 2000);
      pollLink();
    } catch (e) {
      showErr(e.message || "Link failed.");
      if (btn) btn.disabled = false;
    }
  }

  async function pollLink() {
    if (!linkCode) return;
    try {
      var data = await api("/api/mobile/link/status/" + encodeURIComponent(linkCode));
      if (data.status === "linked" && data.token && data.userId) {
        clearInterval(pollTimer);
        pollTimer = null;
        localStorage.setItem(TOKEN_KEY, data.token);
        localStorage.setItem(USER_KEY, data.userId);
        if (data.displayName) localStorage.setItem(NAME_KEY, data.displayName);
        location.reload();
      } else if (data.status === "expired_or_unknown") {
        clearInterval(pollTimer);
        pollTimer = null;
        showErr("Link code expired — tap Link TikTok to try again.");
        var status = $("linkStatus");
        if (status) status.hidden = true;
        var btn = $("btnLinkStart");
        if (btn) btn.disabled = false;
      } else if (data.expiresInSeconds != null) {
        var wait = $("linkWait");
        if (wait) wait.textContent = "Waiting… " + data.expiresInSeconds + "s left";
      }
    } catch (_e) {
      /* keep polling */
    }
  }

  function reviewToggle(ev) {
    if (ev) {
      ev.preventDefault();
      ev.stopPropagation();
    }
    var box = $("reviewBox");
    if (!box) return;
    box.hidden = !box.hidden;
    if (!box.hidden) {
      var input = $("reviewCode");
      if (input) input.focus();
    }
  }

  async function reviewSignIn(ev) {
    if (ev) {
      ev.preventDefault();
      ev.stopPropagation();
    }
    var input = $("reviewCode");
    var code = String((input && input.value) || "").trim();
    if (!code) {
      showErr("Enter the review password.");
      return;
    }
    showErr("");
    var btn = $("btnAppReview");
    if (btn) btn.disabled = true;
    try {
      var data = await api("/api/mobile/auth/app-review", {
        method: "POST",
        body: { deviceId: deviceId(), code: code },
      });
      if (!data.token) throw new Error(data.message || "Sign-in failed.");
      localStorage.setItem(TOKEN_KEY, data.token);
      localStorage.setItem(USER_KEY, data.userId);
      localStorage.setItem(NAME_KEY, data.displayName || data.userId);
      location.reload();
    } catch (e) {
      showErr(e.message || "Review sign-in failed.");
      if (btn) btn.disabled = false;
    }
  }

  function cancelLink(ev) {
    if (ev) {
      ev.preventDefault();
      ev.stopPropagation();
    }
    clearInterval(pollTimer);
    pollTimer = null;
    linkCode = "";
    var status = $("linkStatus");
    if (status) status.hidden = true;
    var btn = $("btnLinkStart");
    if (btn) btn.disabled = false;
  }

  var lastTapAt = 0;

  function onTap(ev) {
    var now = Date.now();
    if (now - lastTapAt < 400) return;
    lastTapAt = now;
    var target = ev.target;
    if (!target || !target.closest) return;
    var btn = target.closest("#btnLinkStart,#btnAppReviewToggle,#btnAppReview,#btnLinkCancel");
    if (!btn) return;
    if (btn.id === "btnLinkStart") startLink(ev);
    else if (btn.id === "btnAppReviewToggle") reviewToggle(ev);
    else if (btn.id === "btnAppReview") reviewSignIn(ev);
    else if (btn.id === "btnLinkCancel") cancelLink(ev);
  }

  function boot() {
    document.addEventListener("click", onTap, true);
    document.addEventListener(
      "touchend",
      function (ev) {
        var target = ev.target;
        if (!target || !target.closest) return;
        if (!target.closest("#btnLinkStart,#btnAppReviewToggle,#btnAppReview,#btnLinkCancel")) return;
        onTap(ev);
      },
      true
    );
    document.body.classList.add("link-boot-ready");
  }

  window.__nfgLinkBoot = {
    startLink: startLink,
    reviewToggle: reviewToggle,
    reviewSignIn: reviewSignIn,
    cancelLink: cancelLink,
  };

  if (document.body) boot();
  else document.addEventListener("DOMContentLoaded", boot);
})();
