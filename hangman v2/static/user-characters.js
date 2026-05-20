/**
 * Deterministic "creature" icons: 500 virtual slots, stable hash per user_key.
 * Procedural SVG (no external assets). Used for session leaderboard + all-time top 5.
 * !buy glow uses the same 500 slots for procedural crown variants (colours, silhouette, jewels).
 */
(function (global) {
  var POOL = 500;

  function fnvSlot(s) {
    var h = 2166136261 >>> 0;
    var str = String(s == null ? "anon" : s);
    for (var i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i);
      h = Math.imul(h, 16777619) >>> 0;
    }
    return h % POOL;
  }

  /** Second hash for unique SVG gradient ids when two users share the same slot. */
  function fnvTag(s) {
    var h = 5381 >>> 0;
    var str = String(s == null ? "" : s);
    for (var i = 0; i < str.length; i++) {
      h = ((h << 5) + h + str.charCodeAt(i)) >>> 0;
    }
    return h >>> 0;
  }

  function hsl(h, s, l) {
    return "hsl(" + (h % 360) + " " + s + "% " + l + "%)";
  }

  /** Build one SVG from slot index 0..499 */
  function buildCreatureSvg(slot) {
    var h1 = (slot * 57) % 360;
    var h2 = (slot * 31 + 79) % 360;
    var h3 = (slot * 19 + 140) % 360;
    var body = slot % 7;
    var ears = (slot >> 3) % 6;
    var eyes = (slot >> 6) % 4;
    var mouth = (slot >> 8) % 3;
    var accent = (slot >> 4) % 2;

    var bodyFill = hsl(h1, 62, 52);
    var earFill = hsl(h2, 58, 46);
    var cheek = accent ? hsl(h3, 75, 72) : "transparent";

    var parts = [];

    // Ears / extras (behind body)
    if (ears === 1) {
      parts.push(
        '<ellipse cx="12" cy="18" rx="7" ry="11" fill="' +
          earFill +
          '" transform="rotate(-28 12 18)"/>'
      );
      parts.push(
        '<ellipse cx="36" cy="18" rx="7" ry="11" fill="' +
          earFill +
          '" transform="rotate(28 36 18)"/>'
      );
    } else if (ears === 2) {
      parts.push(
        '<path d="M8 22 Q6 8 14 10 L16 18 Z" fill="' + earFill + '"/><path d="M40 22 Q42 8 34 10 L32 18 Z" fill="' + earFill + '"/>'
      );
    } else if (ears === 3) {
      parts.push(
        '<line x1="24" y1="10" x2="24" y2="4" stroke="' +
          earFill +
          '" stroke-width="3" stroke-linecap="round"/><circle cx="24" cy="3" r="2.5" fill="' +
          hsl(h2 + 40, 70, 60) +
          '"/>'
      );
    } else if (ears === 4) {
      parts.push(
        '<ellipse cx="10" cy="24" rx="5" ry="13" fill="' + earFill + '" transform="rotate(-15 10 24)"/>'
      );
      parts.push(
        '<ellipse cx="38" cy="24" rx="5" ry="13" fill="' + earFill + '" transform="rotate(15 38 24)"/>'
      );
    } else if (ears === 5) {
      parts.push(
        '<circle cx="9" cy="14" r="5" fill="' + earFill + '"/><circle cx="39" cy="14" r="5" fill="' + earFill + '"/>'
      );
    }

    // Body shapes
    if (body === 0) {
      parts.push('<circle cx="24" cy="26" r="14" fill="' + bodyFill + '"/>');
    } else if (body === 1) {
      parts.push('<ellipse cx="24" cy="26" rx="16" ry="12" fill="' + bodyFill + '"/>');
    } else if (body === 2) {
      parts.push('<ellipse cx="24" cy="26" rx="11" ry="16" fill="' + bodyFill + '"/>');
    } else if (body === 3) {
      parts.push(
        '<rect x="12" y="14" width="24" height="22" rx="8" fill="' + bodyFill + '"/>'
      );
    } else if (body === 4) {
      parts.push(
        '<ellipse cx="24" cy="28" rx="15" ry="11" fill="' + bodyFill + '"/><ellipse cx="24" cy="18" rx="12" ry="10" fill="' + bodyFill + '"/>'
      );
    } else if (body === 5) {
      parts.push(
        '<path d="M24 12 Q38 18 36 28 Q34 38 24 40 Q14 38 12 28 Q10 18 24 12 Z" fill="' +
          bodyFill +
          '"/>'
      );
    } else {
      parts.push(
        '<ellipse cx="24" cy="26" rx="13" ry="13" fill="' + bodyFill + '"/><ellipse cx="18" cy="30" rx="6" ry="5" fill="' + hsl(h1, 50, 40) + '"/><ellipse cx="30" cy="30" rx="6" ry="5" fill="' + hsl(h1, 50, 40) + '"/>'
      );
    }

    // Cheeks
    if (cheek !== "transparent") {
      parts.push('<ellipse cx="16" cy="28" rx="3" ry="2" fill="' + cheek + '" opacity="0.65"/>');
      parts.push('<ellipse cx="32" cy="28" rx="3" ry="2" fill="' + cheek + '" opacity="0.65"/>');
    }

    // Eyes
    if (eyes === 0) {
      parts.push(
        '<ellipse cx="18" cy="24" rx="3.5" ry="4.5" fill="#0f172a"/><ellipse cx="30" cy="24" rx="3.5" ry="4.5" fill="#0f172a"/>'
      );
      parts.push('<circle cx="19" cy="23" r="1.2" fill="#e0f2fe"/><circle cx="31" cy="23" r="1.2" fill="#e0f2fe"/>');
    } else if (eyes === 1) {
      parts.push(
        '<circle cx="18" cy="24" r="4" fill="#0f172a"/><circle cx="30" cy="24" r="4" fill="#0f172a"/>'
      );
      parts.push('<circle cx="19" cy="23" r="1.5" fill="#fef9c3"/><circle cx="31" cy="23" r="1.5" fill="#fef9c3"/>');
    } else if (eyes === 2) {
      parts.push(
        '<ellipse cx="24" cy="24" rx="7" ry="5" fill="#0f172a"/><ellipse cx="25" cy="23" rx="2.5" ry="2" fill="#fef9c3"/>'
      );
    } else {
      parts.push(
        '<circle cx="18" cy="24" r="2.8" fill="#0f172a"/><circle cx="30" cy="24" r="2.8" fill="#0f172a"/><path d="M16 30 Q24 34 32 30" stroke="#0f172a" stroke-width="1.5" fill="none"/>'
      );
    }

    // Mouth
    if (mouth === 0) {
      parts.push(
        '<path d="M19 31 Q24 35 29 31" stroke="#1e293b" stroke-width="1.4" fill="none" stroke-linecap="round"/>'
      );
    } else if (mouth === 1) {
      parts.push('<ellipse cx="24" cy="32" rx="4" ry="2.5" fill="#1e293b"/>');
    } else {
      parts.push(
        '<path d="M20 32 L24 35 L28 32" stroke="#1e293b" stroke-width="1.3" fill="none" stroke-linecap="round"/>'
      );
    }

    return (
      '<svg class="user-creature-svg ohana-svg" viewBox="0 0 48 48" width="44" height="44" aria-hidden="true" data-slot="' +
      slot +
      '">' +
      parts.join("") +
      "</svg>"
    );
  }

  function creatureWrapHtml(userKey, sizeClass) {
    var key = userKey == null || userKey === "" ? "anon" : String(userKey);
    var slot = fnvSlot(key);
    var delay = -((slot % 120) * 0.045);
    var svg = buildCreatureSvg(slot);
    var size = sizeClass || "";
    return (
      '<div class="alltime-mascot-float user-creature ' +
      size +
      '" style="animation-delay:' +
      delay +
      's" data-slot="' +
      slot +
      '">' +
      '<div class="alltime-mascot-bounce">' +
      svg +
      "</div></div>"
    );
  }

  /**
   * 500 procedural crown variants for !buy glow (same slot hash as creatures).
   * Each slot gets distinct hues, stroke, jewels, and silhouette family.
   */
  function buildGlowCrownSvg(slot, userKey, sizeClass) {
    var hGold = 38 + (slot * 53) % 20;
    var sGold = 68 + (slot % 18);
    var lHi = 52 + (slot >> 2) % 14;
    var lMid = lHi - 10;
    var lLo = lHi - 22;
    var metalLight = hsl(hGold, sGold, lHi);
    var metalMid = hsl((hGold + 6) % 360, sGold - 4, lMid);
    var metalDark = hsl((hGold + 3) % 360, sGold - 2, lLo);
    var strokeCol = hsl((hGold + 15) % 360, 55 + (slot % 25), 28 + (slot % 8));

    var gemHue = (slot * 67 + 11) % 360;
    var gemA = hsl(gemHue, 80, 58 + (slot % 6));
    var gemB = hsl((gemHue + 35 + slot % 20) % 360, 76, 52);
    var gemC = hsl((gemHue + 110) % 360, 72, 48);

    var gid =
      "gc" +
      (fnvTag("crown|" + String(userKey) + "|" + slot + "|" + String(sizeClass || "")) >>> 0).toString(16);
    var sw = 0.65 + (slot % 6) * 0.12;
    var bandH = 5 + (slot % 5);
    var bandTop = 38 - bandH;

    var fam = slot % 12;
    var tilt = ((slot % 13) - 6) * 0.45;
    var sc = 0.93 + (slot % 15) * 0.007;

    var hulls = [
      "M6 38 L42 38 L40 28 L34 12 L28 22 L24 8 L20 22 L14 12 L8 28 Z",
      "M6 38 L42 38 L41 30 L36 18 L30 26 L24 10 L18 26 L12 18 L7 30 Z",
      "M5 38 L43 38 L42 32 L38 14 L32 24 L24 7 L16 24 L10 14 L6 32 Z",
      "M7 38 L41 38 L39 29 L35 16 L29 20 L24 9 L19 20 L13 16 L9 29 Z",
      "M6 38 L42 38 L40 26 L36 20 L32 11 L28 21 L24 6 L20 21 L16 11 L12 20 L8 26 Z",
      "M8 38 L40 38 L38 31 L33 15 L28 25 L24 11 L20 25 L15 15 L10 31 Z",
      "M6 38 L42 38 L41 27 L37 19 L31 14 L24 8 L17 14 L11 19 L7 27 Z",
      "M6 38 L42 38 L39 24 L35 10 L31 20 L24 5 L17 20 L13 10 L9 24 Z",
      "M5 38 L43 38 L42 28 L38 22 L33 12 L28 18 L24 7 L20 18 L15 12 L10 22 L6 28 Z",
      "M7 38 L41 38 L40 32 L36 16 L30 24 L24 9 L18 24 L12 16 L8 32 Z",
      "M6 38 L42 38 L41 25 L37 21 L32 13 L28 23 L24 6 L20 23 L16 13 L11 21 L7 25 Z",
      "M8 38 L40 38 L39 29 L34 17 L29 22 L24 8 L19 22 L14 17 L9 29 Z",
    ];
    var hull = hulls[fam];
    var bandPath =
      "M6 " +
      bandTop +
      " L42 " +
      bandTop +
      " L42 38 L6 38 Z";

    var jn = 2 + (slot % 4);
    var jewels = [];
    for (var j = 0; j < jn; j++) {
      var jx = 10 + ((j * 37 + slot * 7) % 29);
      var jy = 16 + ((slot >> (j + 1)) % 9);
      var jr = 1.8 + (slot >> (j * 2)) % 3;
      var jc = j % 3 === 0 ? gemA : j % 3 === 1 ? gemB : gemC;
      jewels.push(
        '<circle cx="' +
          jx +
          '" cy="' +
          jy +
          '" r="' +
          jr +
          '" fill="' +
          jc +
          '" stroke="rgba(0,0,0,0.2)" stroke-width="0.35"/>'
      );
    }

    var rim = (slot >> 5) % 2;
    var extra = [];
    if (rim === 1) {
      extra.push(
        '<path d="M8 36 Q24 33.5 40 36" fill="none" stroke="' +
          metalDark +
          '" stroke-width="1.1" opacity="0.55" stroke-linecap="round"/>'
      );
    }
    var nub = slot % 3;
    if (nub === 0) {
      extra.push(
        '<circle cx="24" cy="11" r="2.2" fill="' +
          gemA +
          '" opacity="0.9"/>'
      );
    } else if (nub === 2) {
      extra.push(
        '<circle cx="14" cy="30" r="1.4" fill="' +
          metalLight +
          '" opacity="0.5"/><circle cx="34" cy="30" r="1.4" fill="' +
          metalLight +
          '" opacity="0.5"/>'
      );
    }

    var innerGlow = (slot >> 7) % 2;
    if (innerGlow === 1) {
      extra.push(
        '<path d="M12 30 Q24 26 36 30" fill="none" stroke="' +
          hsl(hGold + 20, 60, 70) +
          '" stroke-width="0.9" opacity="0.4"/>'
      );
    }

    var inner = [
      "<defs>",
      '<linearGradient id="' +
        gid +
        '" x1="0" y1="0" x2="0" y2="1">',
      '<stop offset="0" stop-color="' + metalLight + '"/>',
      '<stop offset="0.5" stop-color="' + metalMid + '"/>',
      '<stop offset="1" stop-color="' + metalDark + '"/>',
      "</linearGradient>",
      "</defs>",
      '<g transform="translate(24 24) rotate(' +
        tilt +
        ") scale(" +
        sc +
        ') translate(-24 -24)">',
      '<path d="' +
        hull +
        '" fill="url(#' +
        gid +
        ')" stroke="' +
        strokeCol +
        '" stroke-width="' +
        sw +
        '"/>',
      '<path d="' +
        bandPath +
        '" fill="' +
        metalDark +
        '" stroke="' +
        strokeCol +
        '" stroke-width="' +
        (sw * 0.85) +
        '" opacity="0.92"/>',
      jewels.join(""),
      extra.join(""),
      "</g>",
    ].join("");

    return (
      '<svg class="user-crown-svg ohana-svg" viewBox="0 0 48 48" width="44" height="44" aria-hidden="true" data-crown-slot="' +
      slot +
      '">' +
      inner +
      "</svg>"
    );
  }

  function glowCrownWrapHtml(userKey, sizeClass) {
    var key = userKey == null || userKey === "" ? "anon" : String(userKey);
    var slot = fnvSlot(key);
    var delay = -((slot % 120) * 0.045);
    var svg = buildGlowCrownSvg(slot, key, size);
    var size = sizeClass || "";
    return (
      '<div class="alltime-mascot-float user-glow-crown ' +
      size +
      '" style="animation-delay:' +
      delay +
      's" data-crown-slot="' +
      slot +
      '">' +
      '<div class="alltime-mascot-bounce">' +
      svg +
      "</div></div>"
    );
  }

  global.USER_CREATURE_POOL_SIZE = POOL;
  global.USER_GLOW_CROWN_POOL_SIZE = POOL;
  global.userCreatureSlot = function (userKey) {
    return fnvSlot(userKey);
  };
  global.getUserCreatureIconHtml = creatureWrapHtml;
  global.getGlowCrownIconHtml = glowCrownWrapHtml;
})(typeof window !== "undefined" ? window : globalThis);
