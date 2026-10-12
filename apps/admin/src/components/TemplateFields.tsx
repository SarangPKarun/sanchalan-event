import { OWNER_TYPES } from "../lib/event-types.ts";

export interface TemplateDraft {
  taskKey: string;
  defaultNameEn: string;
  defaultLeadTimeDays: string;
  typicalOwnerType: (typeof OWNER_TYPES)[number];
  dependencies: string; // comma separated task keys
}

export const blankTemplate = (key: string): TemplateDraft => ({
  taskKey: `book_${key}`,
  defaultNameEn: "",
  defaultLeadTimeDays: "60",
  typicalOwnerType: "organizer",
  dependencies: "",
});

export const parseDeps = (s: string) => s.split(",").map((d) => d.trim()).filter(Boolean);

export const templateValid = (t: TemplateDraft) =>
  /^[a-z0-9_]+$/.test(t.taskKey) &&
  t.defaultNameEn.trim().length > 0 &&
  Number.isInteger(Number(t.defaultLeadTimeDays)) &&
  Number(t.defaultLeadTimeDays) >= 0 &&
  parseDeps(t.dependencies).every((d) => /^[a-z0-9_]+$/.test(d));

export const templatePayload = (t: TemplateDraft) => ({
  taskKey: t.taskKey,
  defaultNameEn: t.defaultNameEn.trim(),
  defaultLeadTimeDays: Number(t.defaultLeadTimeDays),
  typicalOwnerType: t.typicalOwnerType,
  defaultDependencyKeys: parseDeps(t.dependencies),
});

/** One template's inputs; used by proposal approval and the category template editor. */
export function TemplateFields({ value, onChange, lockKey }: { value: TemplateDraft; onChange: (patch: Partial<TemplateDraft>) => void; lockKey?: boolean }) {
  return (
    <div className="template-fields">
      <label>
        Task key
        <input value={value.taskKey} disabled={lockKey} onChange={(e) => onChange({ taskKey: e.target.value })} />
      </label>
      <label>
        Task name
        <input value={value.defaultNameEn} onChange={(e) => onChange({ defaultNameEn: e.target.value })} />
      </label>
      <label>
        Lead time (days before event)
        <input type="number" min={0} value={value.defaultLeadTimeDays} onChange={(e) => onChange({ defaultLeadTimeDays: e.target.value })} />
      </label>
      <label>
        Owner
        <select value={value.typicalOwnerType} onChange={(e) => onChange({ typicalOwnerType: e.target.value as TemplateDraft["typicalOwnerType"] })}>
          {OWNER_TYPES.map((o) => (
            <option key={o} value={o}>
              {o[0]!.toUpperCase() + o.slice(1)}
            </option>
          ))}
        </select>
      </label>
      <label>
        Depends on (task keys, comma separated)
        <input value={value.dependencies} placeholder="book_venue" onChange={(e) => onChange({ dependencies: e.target.value })} />
      </label>
    </div>
  );
}
