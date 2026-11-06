import assert from "node:assert/strict";
import test from "node:test";
import {
  adjustFontLevel,
  isLineHeightValue,
  readerControlsVisibilityAfter,
  toggleFocusMode,
  toggleTranslation,
} from "../../src/lib/reader-controls.ts";

test("translation control switches between SVD and NIV", () => {
  assert.equal(toggleTranslation("svd"), "niv");
  assert.equal(toggleTranslation("niv"), "svd");
});

test("text size control changes one level and stays within the available range", () => {
  assert.equal(adjustFontLevel(2, -1), 1);
  assert.equal(adjustFontLevel(2, 1), 3);
  assert.equal(adjustFontLevel(0, -1), 0);
  assert.equal(adjustFontLevel(4, 1), 4);
});

test("line spacing control accepts only the existing preference values", () => {
  assert.equal(isLineHeightValue(0.55), true);
  assert.equal(isLineHeightValue(0.85), true);
  assert.equal(isLineHeightValue(1), true);
  assert.equal(isLineHeightValue(1.2), false);
});

test("focus control toggles the existing focus mode", () => {
  assert.equal(toggleFocusMode(false), true);
  assert.equal(toggleFocusMode(true), false);
});

test("reader controls hide on scroll and return after interaction", () => {
  assert.equal(readerControlsVisibilityAfter("scroll"), false);
  assert.equal(readerControlsVisibilityAfter("interaction"), true);
});
