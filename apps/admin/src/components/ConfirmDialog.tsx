import { useEffect, useRef, type ReactNode } from "react";

interface Props {
  open: boolean;
  title: string;
  children?: ReactNode;
  confirmLabel: string;
  danger?: boolean;
  busy?: boolean;
  confirmDisabled?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/** Modal built on the native <dialog>, which traps focus and closes on Escape. */
export function ConfirmDialog({ open, title, children, confirmLabel, danger, busy, confirmDisabled, onConfirm, onCancel }: Props) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);

  return (
    <dialog ref={ref} className="dialog" onCancel={(e) => { e.preventDefault(); if (!busy) onCancel(); }} aria-labelledby="dialog-title">
      <h2 id="dialog-title">{title}</h2>
      {children}
      <div className="review-actions dialog-actions">
        <button type="button" className="secondary" onClick={onCancel} disabled={busy}>
          Cancel
        </button>
        <button type="button" className={danger ? "danger" : undefined} onClick={onConfirm} disabled={busy || confirmDisabled}>
          {busy ? "Working…" : confirmLabel}
        </button>
      </div>
    </dialog>
  );
}
