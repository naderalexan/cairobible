export const FONT_SIZES = [18, 20, 22, 25, 29];
export const FONT_LABELS = ["Extra small", "Small", "Medium", "Large", "Extra large"];
export const FONT_SHORT_LABELS = ["XS", "S", "M", "L", "XL"];
export const LINE_HEIGHT_OPTIONS = [
  { label: "Small", value: 0.55, ratio: 1.5 },
  { label: "Medium", value: 0.85, ratio: 1.85 },
  { label: "Large", value: 1, ratio: 2 },
] as const;

export type LineHeightValue = (typeof LINE_HEIGHT_OPTIONS)[number]["value"];
export function isLineHeightValue(value: number): value is LineHeightValue {
  return LINE_HEIGHT_OPTIONS.some((option) => option.value === value);
}

export function adjustFontLevel(level: number, delta: -1 | 1): number {
  return Math.max(0, Math.min(FONT_SIZES.length - 1, level + delta));
}

export function toggleFocusMode(focusMode: boolean): boolean {
  return !focusMode;
}

export function getLineSpacingPopupPosition(
  button: { top: number; bottom: number; left: number; width: number },
  popup: { width: number; height: number },
  viewport: { width: number; height: number },
): { top: number; left: number } {
  const top = button.top - popup.height - 8 >= 8
    ? button.top - popup.height - 8
    : Math.max(8, Math.min(button.bottom + 8, viewport.height - popup.height - 8));
  return {
    top,
    left: Math.max(8, Math.min(button.left + button.width / 2 - popup.width / 2, viewport.width - popup.width - 8)),
  };
}

export function readerControlsVisibilityAfter(action: "scroll" | "interaction"): boolean {
  return action === "interaction";
}
