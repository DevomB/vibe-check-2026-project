/** Inputs that take no typing, so the table's keys still work while one of them has focus. */
const NO_TYPING_INPUTS = new Set(["checkbox", "radio", "range", "button", "submit", "reset"]);

/**
 * True when a key press is for the table's shortcuts (F, C, R, Space, Enter). It is not while
 * the player types in a field, such as the raise amount, or holds Ctrl, Alt or Cmd: Ctrl+R
 * still reloads the page and Ctrl+C still copies. A button or checkbox that kept focus after a
 * click does not block the shortcuts.
 */
export function isTableShortcut(e: KeyboardEvent): boolean {
  if (e.repeat || e.ctrlKey || e.altKey || e.metaKey) return false;
  const target = e.target;
  if (!(target instanceof HTMLElement)) return true;
  if (target.isContentEditable || target instanceof HTMLTextAreaElement || target instanceof HTMLSelectElement) return false;
  if (target instanceof HTMLInputElement) return NO_TYPING_INPUTS.has(target.type);
  return true;
}

/** Take focus off a button or checkbox, so a later Space or Enter does not press it again. */
export function dropControlFocus(): void {
  const active = document.activeElement;
  if (active instanceof HTMLButtonElement || (active instanceof HTMLInputElement && NO_TYPING_INPUTS.has(active.type))) active.blur();
}
