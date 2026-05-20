import { formatMaskFromSlots, placeholderMask } from "../lib/hangmanState";

export default function WordDisplay({ slots, length, maskedWord }) {
  if (slots?.length) {
    const groups = [];
    let group = [];
    for (const ch of slots) {
      if (ch === " ") {
        if (group.length) {
          groups.push(group);
          group = [];
        }
      } else {
        group.push(ch ? String(ch).toUpperCase() : null);
      }
    }
    if (group.length) groups.push(group);

    return (
      <div className="word-box word-slots">
        {groups.map((letters, gi) => (
          <span key={`g-${gi}`} className="word-group">
            {letters.map((letter, si) => (
              <span key={`${gi}-${si}`} className={`slot${letter ? "" : " empty"}`}>
                {letter || "\u00A0"}
              </span>
            ))}
          </span>
        ))}
      </div>
    );
  }

  const display = maskedWord?.trim() || (length > 0 ? placeholderMask(length) : "");
  return <div className="word-box">{display || "Waiting for word…"}</div>;
}
