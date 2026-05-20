export type TabId = "play" | "board" | "chat" | "account";

interface Props {
  active: TabId;
  onChange: (tab: TabId) => void;
}

const tabs: { id: TabId; label: string; icon: string }[] = [
  { id: "play", label: "Play", icon: "🎯" },
  { id: "board", label: "Board", icon: "🏆" },
  { id: "chat", label: "Chat", icon: "💬" },
  { id: "account", label: "Account", icon: "👤" },
];

export function TabBar({ active, onChange }: Props) {
  return (
    <nav className="tab-bar">
      {tabs.map((t) => (
        <button
          key={t.id}
          type="button"
          className={`tab-btn ${active === t.id ? "active" : ""}`}
          onClick={() => onChange(t.id)}
        >
          <span>{t.icon}</span>
          <span>{t.label}</span>
        </button>
      ))}
    </nav>
  );
}
