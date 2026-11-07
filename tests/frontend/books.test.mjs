import assert from "node:assert/strict";
import test from "node:test";
import { books, POETIC_BOOK_IDS } from "../../src/lib/books.ts";

test("poetic NIV layout is limited to the poetry and wisdom books", () => {
  assert.deepEqual(Array.from(POETIC_BOOK_IDS), ["JOB", "PSA", "PRO", "ECC", "SNG", "LAM"]);
  assert.ok(Array.from(POETIC_BOOK_IDS).every((id) => books.some((book) => book.id === id)));
  assert.equal(POETIC_BOOK_IDS.has("GEN"), false);
  assert.equal(POETIC_BOOK_IDS.has("ISA"), false);
});
