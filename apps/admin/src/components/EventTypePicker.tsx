import { EVENT_TYPES, eventTypeLabel } from "../lib/event-types.ts";

export function EventTypePicker({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  return (
    <fieldset className="chips">
      <legend>Applies to event types</legend>
      {EVENT_TYPES.map((t) => (
        <label key={t} className="check">
          <input
            type="checkbox"
            checked={value.includes(t)}
            onChange={() => onChange(value.includes(t) ? value.filter((x) => x !== t) : [...value, t])}
          />
          {eventTypeLabel(t)}
        </label>
      ))}
    </fieldset>
  );
}
