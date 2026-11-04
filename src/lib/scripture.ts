import type { BibleBook } from "@/lib/books";

export type BibleChapter = {
  id: string;
  bookId: string;
  chapter: number;
  content: string;
  fetchedAt: number;
  copyright: string;
  fumsToken?: string;
};

declare global {
  interface Window {
    fumsData: unknown[];
    fums?: (...args: unknown[]) => void;
  }
}

export async function loadChapter(book: BibleBook, chapter: number): Promise<BibleChapter> {
  const apiRoot = (process.env.NEXT_PUBLIC_BIBLE_API_URL ?? "").replace(/\/+$/, "");
  let response: Response;
  try {
    response = await fetch(`${apiRoot}/api/niv/books/${encodeURIComponent(book.id)}/chapters/${chapter}`);
  } catch {
    throw new Error("Could not reach the Bible server. Check your connection and try again.");
  }
  let result: Partial<BibleChapter> & { detail?: string };
  try {
    result = (await response.json()) as Partial<BibleChapter> & { detail?: string };
  } catch {
    throw new Error("The Bible server returned an unreadable response.");
  }
  if (!response.ok) throw new Error(result.detail ?? "Could not load this NIV chapter.");
  if (!result.content || !result.bookId || !result.chapter || !result.copyright || !result.fumsToken) {
    throw new Error("The Bible server returned incomplete NIV chapter data.");
  }
  return {
    id: `${result.bookId}.${result.chapter}`,
    bookId: result.bookId,
    chapter: result.chapter,
    content: result.content,
    fetchedAt: 0,
    copyright: result.copyright,
    fumsToken: result.fumsToken,
  };
}

export function trackFums(fumsToken: string): void {
  if (typeof window !== "undefined") window.fums?.("trackView", fumsToken);
}
