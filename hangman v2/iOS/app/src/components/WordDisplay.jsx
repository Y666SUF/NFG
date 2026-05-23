import { formatMaskFromSlots, parseMaskToSlots, placeholderMask } from "../lib/hangmanState";

/** Render mask like Windows: "_ _ _ _ S _ _" with visible letters and underscores. */
function MaskText({ text }) {
  const chars = String(text || "").split("");
  return (
    <div className="word-box word-mask-chars">
      {chars.map((ch, i) => {
        if (/[A-Za-z]/.test(ch)) {
          return (
            <span key={i} className="mask-char revealed">
              {ch.toUpperCase()}
            </span>
          );
        }
        if (ch === " ") {
          return <span key={i} className="mask-char space" aria-hidden="true" />;
        }
        return (
          <span key={i} className="mask-char empty">
            {ch === "|" ? "|" : "_"}
          </span>
        );
      })}
    </div>
  );
}

export default function WordDisplay({ slots, length, maskedWord }) {
  let maskStr = String(maskedWord || "").trim();
  const slotMask = formatMaskFromSlots(
    Array.isArray(slots) && slots.length ? slots : null
  );
  if (slotMask && /[A-Za-z]/.test(slotMask)) {
    const maskLetters = (maskStr.match(/[A-Za-z]/g) || []).length;
    const slotLetters = (slotMask.match(/[A-Za-z]/g) || []).length;
    if (!maskStr || !maskStr.includes("_") || slotLetters > maskLetters) {
      maskStr = slotMask;
    }
  }
  const hasLettersInMask = /[A-Za-z]/.test(maskStr);

  if (maskStr && (hasLettersInMask || maskStr.includes("_"))) {
    return <MaskText text={maskStr} />;
  }

  const letterSlots =
    Array.isArray(slots) && slots.length > 0
      ? slots
      : length > 0
        ? Array(length).fill(null)
        : parseMaskToSlots(maskStr, length);

  if (letterSlots?.length) {
    const groups = [];
    let group = [];
    for (const ch of letterSlots) {
      if (ch === " ") {
        if (group.length) {
          groups.push(group);
          group = [];
        }
      } else {
        const letter =
          ch && String(ch).length === 1 && /^[a-zA-Z]$/.test(String(ch))
            ? String(ch).toUpperCase()
            : null;
        group.push(letter);
      }
    }
    if (group.length) groups.push(group);

    return (
      <div className="word-box word-slots">
        {groups.map((letters, gi) => (
          <span key={`g-${gi}`} className="word-group">
            {letters.map((letter, si) => (
              <span
                key={`${gi}-${si}`}
                className={`slot${letter ? " revealed" : " empty"}`}
              >
                {letter || "_"}
              </span>
            ))}
          </span>
        ))}
      </div>
    );
  }

  const display = length > 0 ? placeholderMask(length) : "";
  return <div className="word-box word-mask-text">{display || "Waiting for word…"}</div>;
}
