import { useEffect, useState } from "react";

/** Text search that reports changes after a short pause, so each keystroke is not a request. */
export function SearchBox({ value, onSearch, label, placeholder }: { value: string; onSearch: (v: string) => void; label: string; placeholder?: string }) {
  const [text, setText] = useState(value);

  useEffect(() => {
    if (text === value) return;
    const id = setTimeout(() => onSearch(text.trim()), 350);
    return () => clearTimeout(id);
  }, [text, value, onSearch]);

  return (
    <label className="search-box">
      <span className="sr-only">{label}</span>
      <input type="search" value={text} placeholder={placeholder ?? "Search"} onChange={(e) => setText(e.target.value)} />
    </label>
  );
}
