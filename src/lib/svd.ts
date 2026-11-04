export type SvdChapter = { bookId: string; chapter: number; bookName: string; content: string };
type SvdCorpus = {
  books: Record<string, { name: string; chapters: Record<string, string> }>;
};
type SvdVerseMap = { books: Record<string, Record<string, number[]>> };

const CHAPTER_CACHE = "cairo-bible-svd-chapters-v1";
let corpusPromise: Promise<SvdCorpus> | undefined;
let verseMapPromise: Promise<SvdVerseMap> | undefined;

async function loadCorpus(): Promise<SvdCorpus> {
  if (!corpusPromise) {
    corpusPromise = fetch("/data/arb-vd.json")
      .then(async (response) => {
        if (!response.ok) throw new Error("Could not load the locally stored SVD Bible.");
        return response.json() as Promise<SvdCorpus>;
      })
      .catch((error: unknown) => {
        corpusPromise = undefined;
        throw error;
      });
  }
  return corpusPromise;
}

async function loadVerseMap(): Promise<SvdVerseMap> {
  if (!verseMapPromise) {
    verseMapPromise = fetch("/data/arb-vd-verses.json")
      .then(async (response) => {
        if (!response.ok) throw new Error("Could not load SVD verse boundaries.");
        return response.json() as Promise<SvdVerseMap>;
      })
      .catch((error: unknown) => {
        verseMapPromise = undefined;
        throw error;
      });
  }
  return verseMapPromise;
}

function addVerseMarkers(content: string, offsets: number[]): string {
  const parts: string[] = [];
  let cursor = 0;

  for (const [index, offset] of offsets.entries()) {
    if (!Number.isInteger(offset) || (index > 0 && offset <= cursor) || offset > content.length) return content;
    parts.push(escapeHtml(content.slice(cursor, offset)), `<span data-number="${index + 1}">${index + 1}</span>`);
    cursor = offset;
  }

  parts.push(escapeHtml(content.slice(cursor)));
  return parts.join("");
}

function escapeHtml(text: string): string {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

async function loadLocalSvdChapter(bookId: string, chapter: number): Promise<SvdChapter> {
  const [corpus, verseMap] = await Promise.all([loadCorpus(), loadVerseMap().catch(() => undefined)]);
  const book = corpus.books[bookId];
  const chapterKey = [String(chapter), String(chapter).padStart(2, "0"), String(chapter).padStart(3, "0")]
    .find((key) => book?.chapters[key] !== undefined);
  const content = chapterKey ? book?.chapters[chapterKey] : undefined;
  if (!book || !chapterKey || !content) throw new Error("That SVD chapter is not available in the local Bible data.");

  const offsets = verseMap?.books[bookId]?.[chapterKey];
  return { bookId, chapter, bookName: book.name, content: offsets ? addVerseMarkers(content, offsets) : content };
}

export async function loadSvdChapter(bookId: string, chapter: number): Promise<SvdChapter> {
  const apiRoot = (process.env.NEXT_PUBLIC_BIBLE_API_URL ?? "").replace(/\/+$/, "");
  const url = `${apiRoot}/api/svd/books/${encodeURIComponent(bookId)}/chapters/${chapter}`;
  let cache: Cache | undefined;
  try {
    if (typeof caches !== "undefined") cache = await caches.open(CHAPTER_CACHE);
  } catch { /* Continue online if browser caching is unavailable. */ }

  if (cache) {
    try {
      const cached = await cache.match(url);
      if (cached) return (await cached.json()) as SvdChapter;
    } catch { /* Ignore an unreadable cached response and fetch a fresh copy. */ }
  }

  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error("Could not load the Arabic SVD chapter.");
    await cache?.put(url, response.clone()).catch(() => undefined);
    return (await response.json()) as SvdChapter;
  } catch (error) {
    if (typeof navigator === "undefined" || navigator.onLine) throw error;
    return loadLocalSvdChapter(bookId, chapter);
  }
}
