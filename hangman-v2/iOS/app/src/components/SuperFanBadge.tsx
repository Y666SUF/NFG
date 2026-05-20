interface Props {
  superFan?: boolean;
  level?: number;
}

export function SuperFanBadge({ superFan, level }: Props) {
  if (!superFan) return null;
  return (
    <span className="super-fan" title="Super Fan">
      ★ {level && level > 1 ? level : "SUPER FAN"}
    </span>
  );
}
