import assert from "node:assert/strict";
import test from "node:test";
import { loadChapter } from "../../src/lib/scripture.ts";
import { translate } from "../../src/lib/translations.ts";

test("NIV chapter loads from the configured backend with its copyright attribution", async () => {
  const originalFetch = globalThis.fetch;
  const originalApiRoot = process.env.NEXT_PUBLIC_BIBLE_API_URL;
  let request;
  let options;
  process.env.NEXT_PUBLIC_BIBLE_API_URL = "https://bible.example/";
  globalThis.fetch = async (url, init) => {
    request = url;
    options = init;
    return Response.json({
      bookId: "GEN",
      chapter: 1,
      content: "<p>In the beginning</p>",
      copyright: "NIV copyright",
      fumsToken: "view-token",
    });
  };

  try {
    const chapter = await loadChapter({ id: "GEN" }, 1);

    assert.equal(request, "https://bible.example/api/niv/books/GEN/chapters/1");
    assert.equal(options, undefined);
    assert.equal(chapter.content, "<p>In the beginning</p>");
    assert.equal(chapter.copyright, "NIV copyright");
    assert.equal(chapter.fumsToken, "view-token");
  } finally {
    globalThis.fetch = originalFetch;
    if (originalApiRoot === undefined) delete process.env.NEXT_PUBLIC_BIBLE_API_URL;
    else process.env.NEXT_PUBLIC_BIBLE_API_URL = originalApiRoot;
  }
});

test("NIV chapter shows the backend error detail", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => Response.json(
    { detail: "NIV corpus access is disabled until its license is confirmed." },
    { status: 503 },
  );

  try {
    await assert.rejects(
      loadChapter({ id: "GEN" }, 1),
      { message: "NIV corpus access is disabled until its license is confirmed." },
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("NIV license error is clear in Arabic", () => {
  assert.equal(
    translate("ar", "NIV corpus access is disabled until its license is confirmed."),
    "يظل الوصول إلى نص NIV معطلاً حتى تأكيد الترخيص المطلوب.",
  );
});

test("NIV request reports a clear error when the Bible server cannot be reached", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new TypeError("Failed to fetch"); };

  try {
    await assert.rejects(
      loadChapter({ id: "GEN" }, 1),
      { message: "Could not reach the Bible server. Check your connection and try again." },
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});
