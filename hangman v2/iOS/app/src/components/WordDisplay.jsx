import { formatMaskFromSlots, parseMaskToSlots, placeholderMask } from "../lib/hangmanState";

export default function WordDisplay({ slots, length, maskedWord }) {
  const maskStr = String(maskedWord || "").trim();
  const letterSlots =
    Array.isArray(slots) && slots.length > 0
      ? slots
      : maskStr
        ? parseMaskToSlots(maskStr, length)
        : length > 0
          ? Array(length).fill(null)
          : null;

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
                aria-label={letter || "hidden letter"}
              >
                {letter || "_"}
              </span>
            ))}
          </span>
        ))}
      </div>
    );
  }

  const display = maskStr || (length > 0 ? placeholderMask(length) : "");
  return <div className="word-box word-mask-text">{display || "Waiting for word…"}</div>;
}
