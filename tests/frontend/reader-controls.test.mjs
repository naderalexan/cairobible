import assert from "node:assert/strict";
import test from "node:test";
import {
  adjustFontLevel,
  FONT_LABELS,
  FONT_SHORT_LABELS,
  isLineHeightValue,
  isScriptureWidthLevel,
  SCRIPTURE_WIDTH_OPTIONS,
  getLineSpacingPopupPosition,
  readerControlsVisibilityAfter,
  toggleFocusMode,
} from "../../src/lib/reader-controls.ts";

test("font size choices have compact labels and accessible names", () => {
  assert.deepEqual(FONT_SHORT_LABELS, ["XS", "S", "M", "L", "XL"]);
  assert.equal(FONT_LABELS.length, FONT_SHORT_LABELS.length);
});

test("text size control changes one level and stays within the available range", () => {
  assert.equal(adjustFontLevel(2, -1), 1);
  assert.equal(adjustFontLevel(2, 1), 3);
  assert.equal(adjustFontLevel(0, -1), 0);
  assert.equal(adjustFontLevel(4, 1), 4);
});

test("scripture width offers five validated sizes and keeps medium at the current width", () => {
  assert.deepEqual(SCRIPTURE_WIDTH_OPTIONS.map((option) => option.label), ["XS", "S", "M", "L", "XL"]);
  assert.equal(SCRIPTURE_WIDTH_OPTIONS[2].width, 680);
  assert.equal(isScriptureWidthLevel(0), true);
  assert.equal(isScriptureWidthLevel(4), true);
  assert.equal(isScriptureWidthLevel(-1), false);
  assert.equal(isScriptureWidthLevel(5), false);
  assert.equal(isScriptureWidthLevel(1.5), false);
});

test("line spacing control accepts only the existing preference values", () => {
  assert.equal(isLineHeightValue(0.55), true);
  assert.equal(isLineHeightValue(0.85), true);
  assert.equal(isLineHeightValue(1), true);
  assert.equal(isLineHeightValue(1.2), false);
});

test("line spacing popup remains within the viewport around its trigger", () => {
  assert.deepEqual(
    getLineSpacingPopupPosition(
      { top: 590, bottom: 630, left: 651, width: 120 },
      { width: 248, height: 150 },
      { width: 1280, height: 720 },
    ),
    { top: 432, left: 587 },
  );
  assert.deepEqual(
    getLineSpacingPopupPosition(
      { top: 30, bottom: 70, left: 200, width: 100 },
      { width: 248, height: 120 },
      { width: 320, height: 600 },
    ),
    { top: 78, left: 64 },
  );
});

test("focus control toggles the existing focus mode", () => {
  assert.equal(toggleFocusMode(false), true);
  assert.equal(toggleFocusMode(true), false);
});

test("reader controls hide on scroll and return after interaction", () => {
  assert.equal(readerControlsVisibilityAfter("scroll"), false);
  assert.equal(readerControlsVisibilityAfter("interaction"), true);
});
