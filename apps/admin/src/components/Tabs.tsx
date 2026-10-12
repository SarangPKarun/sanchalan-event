import type { KeyboardEvent } from "react";

export interface TabItem<T extends string> {
  value: T;
  label: string;
  count?: number | undefined;
}

export function Tabs<T extends string>({ tabs, value, onChange, label }: { tabs: TabItem<T>[]; value: T; onChange: (v: T) => void; label: string }) {
  function onKeyDown(e: KeyboardEvent, index: number) {
    const step = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
    if (!step) return;
    e.preventDefault();
    const next = tabs[(index + step + tabs.length) % tabs.length]!;
    onChange(next.value);
    document.getElementById(`tab-${next.value}`)?.focus();
  }

  return (
    <div className="tabs" role="tablist" aria-label={label}>
      {tabs.map((t, i) => (
        <button
          key={t.value}
          id={`tab-${t.value}`}
          type="button"
          role="tab"
          aria-selected={t.value === value}
          tabIndex={t.value === value ? 0 : -1}
          className={t.value === value ? "tab tab-active" : "tab"}
          onClick={() => onChange(t.value)}
          onKeyDown={(e) => onKeyDown(e, i)}
        >
          {t.label}
          {t.count !== undefined && <span className="tab-count">{t.count}</span>}
        </button>
      ))}
    </div>
  );
}
