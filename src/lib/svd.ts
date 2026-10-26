export type SvdChapter = { bookId: string; chapter: number; bookName: string; content: string };
type SvdCorpus = {
  books: Record<string, { name: string; chapters: Record<string, string> }>;
};

let corpusPromise: Promise<SvdCorpus> | undefined;

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

export async function loadSvdChapter(bookId: string, chapter: number): Promise<SvdChapter> {
  const corpus = await loadCorpus();
  const book = corpus.books[bookId];
  const content = book?.chapters[String(chapter)]
    ?? book?.chapters[String(chapter).padStart(2, "0")]
    ?? book?.chapters[String(chapter).padStart(3, "0")];
  if (!book || !content) throw new Error("That SVD chapter is not available in the local Bible data.");
  return { bookId, chapter, bookName: book.name, content };
}
