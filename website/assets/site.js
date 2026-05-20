(function () {
  var root = document.documentElement;
  root.classList.add("fade-enter");
  var ua = String(navigator.userAgent || "");
  var isEmbeddedBrowser = /TikTok|musical_ly|Bytedance|FBAN|FBAV|Instagram/i.test(ua);
  var prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var isCoarsePointer = window.matchMedia("(pointer: coarse)").matches;

  if (!isEmbeddedBrowser) {
    document.addEventListener("click", function (event) {
      var link = event.target.closest("a[data-nav]");
      if (!link) return;
      var href = link.getAttribute("href");
      if (!href || href.startsWith("#")) return;
      if (link.target && link.target !== "_self") return;
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      root.classList.add("fade-leave");
      setTimeout(function () {
        window.location.href = href;
      }, 180);
    });
  }

  var revealEls = document.querySelectorAll("[data-reveal]");
  if (revealEls.length) {
    if (prefersReducedMotion || typeof IntersectionObserver === "undefined") {
      revealEls.forEach(function (el) {
        el.classList.add("is-visible");
      });
    } else {
      var revealObserver = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              entry.target.classList.add("is-visible");
              revealObserver.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.18, rootMargin: "0px 0px -8% 0px" }
      );
      revealEls.forEach(function (el) {
        revealObserver.observe(el);
      });
    }
  }

  var tabButtons = document.querySelectorAll("[data-tab-target]");
  var tabPanes = document.querySelectorAll("[data-tab-pane]");
  var tabProgressBar = document.getElementById("tabProgressBar");
  if (tabButtons.length && tabPanes.length) {
    var activeTabIdx = 0;
    var autoRotateMs = 5200;
    var progressTimer = null;
    var rotateTimer = null;

    function setActiveTabByIndex(idx) {
      activeTabIdx = idx;
      var btn = tabButtons[idx];
      var target = btn.getAttribute("data-tab-target");
      tabButtons.forEach(function (b) {
        var active = b === btn;
        b.classList.toggle("active", active);
        b.setAttribute("aria-selected", active ? "true" : "false");
      });
      tabPanes.forEach(function (pane) {
        var active = pane.getAttribute("data-tab-pane") === target;
        pane.classList.toggle("active", active);
        pane.hidden = !active;
      });
      if (tabProgressBar) {
        tabProgressBar.style.width = "0%";
      }
    }

    function startProgress() {
      if (!tabProgressBar) return;
      var started = Date.now();
      if (progressTimer) window.clearInterval(progressTimer);
      progressTimer = window.setInterval(function () {
        var elapsed = Date.now() - started;
        var percent = Math.max(0, Math.min(100, Math.round((elapsed / autoRotateMs) * 100)));
        tabProgressBar.style.width = percent + "%";
      }, 70);
    }

    function stopAutoRotate() {
      if (rotateTimer) window.clearInterval(rotateTimer);
      if (progressTimer) window.clearInterval(progressTimer);
      rotateTimer = null;
      progressTimer = null;
    }

    function startAutoRotate() {
      if (prefersReducedMotion) return;
      stopAutoRotate();
      startProgress();
      rotateTimer = window.setInterval(function () {
        var next = (activeTabIdx + 1) % tabButtons.length;
        setActiveTabByIndex(next);
        startProgress();
      }, autoRotateMs);
    }

    tabButtons.forEach(function (btn) {
      btn.addEventListener("click", function () {
        var idx = Array.prototype.indexOf.call(tabButtons, btn);
        setActiveTabByIndex(Math.max(0, idx));
        startAutoRotate();
      });
    });

    setActiveTabByIndex(0);
    startAutoRotate();

    var tabStage = document.querySelector(".tab-stage");
    if (tabStage) {
      tabStage.addEventListener("mouseenter", stopAutoRotate);
      tabStage.addEventListener("mouseleave", startAutoRotate);
      tabStage.addEventListener("focusin", stopAutoRotate);
      tabStage.addEventListener("focusout", startAutoRotate);
    }
  }

  if (prefersReducedMotion) return;

  var parallaxNodes = document.querySelectorAll("[data-parallax]");
  if (parallaxNodes.length && !isCoarsePointer) {
    document.addEventListener(
      "mousemove",
      function (event) {
        var vw = Math.max(1, window.innerWidth);
        var vh = Math.max(1, window.innerHeight);
        var nx = event.clientX / vw - 0.5;
        var ny = event.clientY / vh - 0.5;
        parallaxNodes.forEach(function (node) {
          var depth = Number(node.getAttribute("data-parallax") || 10);
          var tx = nx * depth;
          var ty = ny * depth;
          node.style.transform = "translate3d(" + tx.toFixed(2) + "px, " + ty.toFixed(2) + "px, 0)";
        });
      },
      { passive: true }
    );
  }

  var allowTilt = !isCoarsePointer;
  if (!allowTilt) return;

  var cards = document.querySelectorAll(".game-card, .panel-3d");
  cards.forEach(function (card) {
    card.addEventListener("mousemove", function (event) {
      var rect = card.getBoundingClientRect();
      var px = (event.clientX - rect.left) / rect.width;
      var py = (event.clientY - rect.top) / rect.height;
      var rx = (0.5 - py) * 4.2;
      var ry = (px - 0.5) * 5.8;
      card.style.transform = "rotateX(" + rx.toFixed(2) + "deg) rotateY(" + ry.toFixed(2) + "deg) translateZ(6px)";
    });
    card.addEventListener("mouseleave", function () {
      card.style.transform = "";
    });
  });

})();
