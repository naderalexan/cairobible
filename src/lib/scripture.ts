import type { BibleBook } from "@/lib/books";

export const NIV_BIBLE_ID = "78a9f6124f344018-01";
const API_ROOT = "https://rest.api.bible/v1";
const STORE_NAME = "chapters";
const DATABASE_NAME = "still-niv";
const CACHE_LIFETIME = 29 * 24 * 60 * 60 * 1000;

export type BibleChapter = {
  id: string;
  bookId: string;
  chapter: number;
  content: string;
  fetchedAt: number;
};

export type BibleMetadata = { name?: string; copyright?: string };

type ApiResponse<T> = { data?: T; message?: string; error?: string };

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === "undefined") {
      reject(new Error("Offline storage is unavailable in this browser."));
      return;
    }
    const request = indexedDB.open(DATABASE_NAME, 1);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(STORE_NAME)) {
        database.createObjectStore(STORE_NAME, { keyPath: "id" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("Could not open offline storage."));
  });
}

async function readChapter(id: string): Promise<BibleChapter | undefined> {
  const database = await openDatabase();
  return new Promise((resolve, reject) => {
    const request = database.transaction(STORE_NAME, "readonly").objectStore(STORE_NAME).get(id);
    request.onsuccess = () => resolve(request.result as BibleChapter | undefined);
    request.onerror = () => reject(request.error ?? new Error("Could not read the saved chapter."));
    request.transaction?.addEventListener("complete", () => database.close(), { once: true });
  });
}

async function writeChapter(chapter: BibleChapter): Promise<void> {
  const database = await openDatabase();
  await new Promise<void>((resolve, reject) => {
    const transaction = database.transaction(STORE_NAME, "readwrite");
    transaction.objectStore(STORE_NAME).put(chapter);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error ?? new Error("Could not save this chapter offline."));
    transaction.onabort = () => reject(transaction.error ?? new Error("Saving this chapter was interrupted."));
  }).finally(() => database.close());
}

export async function getFreshCachedChapter(bookId: string, chapter: number): Promise<BibleChapter | undefined> {
  const saved = await readChapter(`${bookId}.${chapter}`);
  return saved && Date.now() - saved.fetchedAt < CACHE_LIFETIME ? saved : undefined;
}

async function apiRequest<T>(path: string, apiKey: string, params = ""): Promise<T> {
  const response = await fetch(`${API_ROOT}${path}${params}`, {
    headers: { "api-key": apiKey, "Content-Type": "application/json" },
  });
  let result: ApiResponse<T>;
  try {
    result = (await response.json()) as ApiResponse<T>;
  } catch {
    throw new Error("API.Bible returned an unreadable response. Check your connection and try again.");
  }
  if (!response.ok || !result.data) {
    if (response.status === 401 || response.status === 403) {
      throw new Error("That key could not access the NIV. Check the key and confirm NIV is enabled for your API.Bible account.");
    }
    if (response.status === 429) throw new Error("API.Bible is receiving requests too quickly. Wait a moment, then try again.");
    throw new Error(result.message ?? result.error ?? `API.Bible request failed (${response.status}).`);
  }
  return result.data;
}

export async function connectToNiv(apiKey: string): Promise<BibleMetadata> {
  if (!apiKey.trim()) throw new Error("Enter an API.Bible key to connect.");
  return apiRequest<BibleMetadata>(`/bibles/${NIV_BIBLE_ID}`, apiKey.trim());
}

export async function loadChapter(
  book: BibleBook,
  chapter: number,
  apiKey: string,
  options: { refresh?: boolean } = {},
): Promise<BibleChapter> {
  const chapterId = `${book.id}.${chapter}`;
  if (!options.refresh) {
    const cached = await getFreshCachedChapter(book.id, chapter);
    if (cached) return cached;
  }
  const response = await apiRequest<{ content?: string }>(
    `/bibles/${NIV_BIBLE_ID}/chapters/${chapterId}`,
    apiKey,
    "?content-type=html&include-notes=false&include-titles=true&include-chapter-numbers=false&include-verse-numbers=true&include-verse-spans=false",
  );
  if (!response.content) throw new Error("This chapter came back empty. Try again in a moment.");
  const result: BibleChapter = {
    id: chapterId,
    bookId: book.id,
    chapter,
    content: response.content,
    fetchedAt: Date.now(),
  };
  await writeChapter(result);
  return result;
}

export async function countFreshCachedChapters(): Promise<number> {
  const database = await openDatabase();
  return new Promise((resolve, reject) => {
    const request = database.transaction(STORE_NAME, "readonly").objectStore(STORE_NAME).getAll();
    request.onsuccess = () => {
      const now = Date.now();
      const freshCount = (request.result as BibleChapter[]).filter((chapter) => now - chapter.fetchedAt < CACHE_LIFETIME).length;
      resolve(freshCount);
    };
    request.onerror = () => reject(request.error ?? new Error("Could not count saved chapters."));
    request.transaction?.addEventListener("complete", () => database.close(), { once: true });
  });
}

export async function saveWholeBibleOffline(
  apiKey: string,
  onProgress: (complete: number, total: number, currentBook: string) => void,
  signal: AbortSignal,
): Promise<void> {
  const { books } = await import("@/lib/books");
  const total = books.reduce((count, book) => count + book.chapters, 0);
  let complete = 0;
  for (const book of books) {
    for (let chapter = 1; chapter <= book.chapters; chapter += 1) {
      if (signal.aborted) return;
      await loadChapter(book, chapter, apiKey);
      complete += 1;
      onProgress(complete, total, book.name);
      if (complete < total) await new Promise((resolve) => window.setTimeout(resolve, 180));
    }
  }
}
