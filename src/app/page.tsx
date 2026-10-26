"use client";

import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { books } from "@/lib/books";
import {
  connectToNiv,
  countFreshCachedChapters,
  getFreshCachedChapter,
  loadChapter,
  saveWholeBibleOffline,
  type BibleChapter,
  type BibleMetadata,
} from "@/lib/scripture";
import { loadSvdChapter } from "@/lib/svd";

const FONT_SIZES = [18, 20, 22, 25, 29];
const FONT_LABELS = ["Small", "Comfortable", "Medium", "Large", "Extra large"];
const POSITION_KEY = "still-reading-position";
const API_KEY_KEY = "still-api-key";

export default function Home() {
  const [currentBook, setCurrentBook] = useState(books[0]);
  const [chapter, setChapter] = useState(1);
  const [translation, setTranslation] = useState<"niv" | "svd">("niv");
  const [svdBookName, setSvdBookName] = useState("");
  const [query, setQuery] = useState("");
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [chapterPickerOpen, setChapterPickerOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const [fontLevel, setFontLevel] = useState(2);
  const [apiKey, setApiKey] = useState("");
  const [apiInput, setApiInput] = useState("");
  const [connected, setConnected] = useState(false);
  const [ready, setReady] = useState(false);
  const [chapterData, setChapterData] = useState<BibleChapter | null>(null);
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState("");
  const [settingsStatus, setSettingsStatus] = useState("");
  const [metadata, setMetadata] = useState<BibleMetadata | null>(null);
  const [isOnline, setIsOnline] = useState(true);
  const [savedCount, setSavedCount] = useState(0);
  const [downloadProgress, setDownloadProgress] = useState<{ complete: number; total: number; book: string } | null>(null);
  const [refreshToken, setRefreshToken] = useState(0);
  const downloadController = useRef<AbortController | null>(null);

  useEffect(() => {
    const savedTranslation = localStorage.getItem("still-translation");
    setTranslation(savedTranslation === "svd" ? "svd" : "niv");
    const savedTheme = localStorage.getItem("still-theme");
    setTheme(savedTheme === "dark" ? "dark" : "light");
    const savedFont = Number(localStorage.getItem("still-font-level"));
    if (Number.isInteger(savedFont) && savedFont >= 0 && savedFont <= 4) setFontLevel(savedFont);
    const savedPosition = localStorage.getItem(POSITION_KEY);
    if (savedPosition) {
      try {
        const position = JSON.parse(savedPosition) as { bookId?: string; chapter?: number };
        const book = books.find((item) => item.id === position.bookId);
        if (book && position.chapter && position.chapter <= book.chapters) {
          setCurrentBook(book);
          setChapter(position.chapter);
        }
      } catch { localStorage.removeItem(POSITION_KEY); }
    }
    const savedKey = localStorage.getItem(API_KEY_KEY) ?? "";
    setApiKey(savedKey);
    setApiInput(savedKey);
    setConnected(Boolean(savedKey));
    setIsOnline(navigator.onLine);
    if (window.innerWidth < 760) setSidebarOpen(false);
    void countFreshCachedChapters().then(setSavedCount).catch(() => undefined);
    setReady(true);

    const updateOnline = () => setIsOnline(navigator.onLine);
    window.addEventListener("online", updateOnline);
    window.addEventListener("offline", updateOnline);
    if ("serviceWorker" in navigator) void navigator.serviceWorker.register("/sw.js").catch(() => undefined);
    return () => {
      window.removeEventListener("online", updateOnline);
      window.removeEventListener("offline", updateOnline);
    };
  }, []);

  useEffect(() => {
    if (ready) localStorage.setItem(POSITION_KEY, JSON.stringify({ bookId: currentBook.id, chapter }));
  }, [ready, currentBook.id, chapter]);

  useEffect(() => {
    if (ready) localStorage.setItem("still-translation", translation);
  }, [ready, translation]);

  useEffect(() => {
    if (connected && apiKey) void connectToNiv(apiKey).then(setMetadata).catch(() => undefined);
  }, [connected, apiKey]);

  useEffect(() => {
    if (!settingsOpen && !chapterPickerOpen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setSettingsOpen(false);
        setChapterPickerOpen(false);
      }
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [settingsOpen, chapterPickerOpen]);

  useEffect(() => {
    if (ready) localStorage.setItem("still-theme", theme);
  }, [ready, theme]);

  useEffect(() => {
    if (ready) localStorage.setItem("still-font-level", String(fontLevel));
  }, [ready, fontLevel]);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      if (!ready) return;
      setLoading(true);
      if (translation === "svd") setSvdBookName("");
      setLoadError("");
      setChapterData(null);
      try {
        if (translation === "svd") {
          const data = await loadSvdChapter(currentBook.id, chapter);
          if (!cancelled) {
            setChapterData({ id: `${data.bookId}.${data.chapter}`, bookId: data.bookId, chapter: data.chapter, content: data.content, fetchedAt: 0 });
            setSvdBookName(data.bookName);
          }
          return;
        }
        const data = apiKey
          ? await loadChapter(currentBook, chapter, apiKey)
          : await getFreshCachedChapter(currentBook.id, chapter);
        if (!cancelled) {
          setChapterData(data ?? null);
          setSvdBookName("");
          if (!data && apiKey) setLoadError("No chapter was returned. Check your connection and try again.");
          setSavedCount(await countFreshCachedChapters().catch(() => 0));
        }
      } catch (error) {
        if (!cancelled) setLoadError(error instanceof Error ? error.message : "Could not open this chapter.");
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [apiKey, chapter, currentBook, ready, refreshToken, translation]);

  const filteredBooks = useMemo(
    () => books.filter((book) => book.name.toLowerCase().includes(query.toLowerCase().trim())),
    [query],
  );
  const oldTestament = filteredBooks.filter((book) => book.testament === "Old Testament");
  const newTestament = filteredBooks.filter((book) => book.testament === "New Testament");

  function selectBook(book: (typeof books)[number]) {
    setCurrentBook(book);
    setChapter(1);
    setChapterPickerOpen(false);
    setQuery("");
    if (window.innerWidth < 760) setSidebarOpen(false);
  }

  function stepChapter(direction: -1 | 1) {
    const nextChapter = chapter + direction;
    if (nextChapter >= 1 && nextChapter <= currentBook.chapters) {
      setChapter(nextChapter);
      return;
    }
    const bookIndex = books.findIndex((book) => book.id === currentBook.id) + direction;
    const nextBook = books[bookIndex];
    if (!nextBook) return;
    setCurrentBook(nextBook);
    setChapter(direction > 0 ? 1 : nextBook.chapters);
  }

  async function connect() {
    setSettingsStatus("Checking your NIV access…");
    try {
      const result = await connectToNiv(apiInput);
      localStorage.setItem(API_KEY_KEY, apiInput.trim());
      setApiKey(apiInput.trim());
      setConnected(true);
      setMetadata(result);
      setSettingsStatus("Connected. Your NIV chapter will load automatically.");
    } catch (error) {
      setSettingsStatus(error instanceof Error ? error.message : "Could not connect to API.Bible.");
    }
  }

  function disconnect() {
    localStorage.removeItem(API_KEY_KEY);
    setApiKey("");
    setApiInput("");
    setConnected(false);
    setMetadata(null);
    setSettingsStatus("API key removed. Freshly cached chapters remain available on this device.");
  }

  async function saveOffline() {
    if (!apiKey) {
      setSettingsOpen(true);
      setSettingsStatus("Connect an API.Bible key with NIV access before saving chapters.");
      return;
    }
    const controller = new AbortController();
    downloadController.current = controller;
    setSettingsStatus("Saving the NIV chapter by chapter. You can pause at any time.");
    try {
      await saveWholeBibleOffline(apiKey, (complete, total, book) => {
        setDownloadProgress({ complete, total, book });
      }, controller.signal);
      if (!controller.signal.aborted) setSettingsStatus("Offline download complete.");
      else setSettingsStatus("Download paused. Completed chapters are saved and will be skipped next time.");
      setSavedCount(await countFreshCachedChapters().catch(() => savedCount));
    } catch (error) {
      setSettingsStatus(error instanceof Error ? error.message : "The download stopped. Try again when you are online.");
    } finally {
      downloadController.current = null;
      setDownloadProgress(null);
    }
  }

  function pauseDownload() {
    downloadController.current?.abort();
  }

  function renderBooks(list: typeof books) {
    return list.map((book) => (
      <li key={book.id}>
        <button
          className={`book-row${currentBook.id === book.id ? " selected" : ""}`}
          aria-current={currentBook.id === book.id ? "page" : undefined}
          onClick={() => selectBook(book)}
        >
          <span>{book.name}</span><span className="book-arrow" aria-hidden="true">›</span>
        </button>
      </li>
    ));
  }

  return (
    <div className={`app-shell ${theme}`} style={{ "--reading-size": `${FONT_SIZES[fontLevel]}px` } as CSSProperties}>
      <aside className={`sidebar${sidebarOpen ? " open" : " collapsed"}`} aria-label="Bible books">
        <div className="sidebar-top">
          <a className="brand" href="#" aria-label="Still Bible Reader home">
            <span className="brand-mark" aria-hidden="true"><BookMark /></span>
            <span><strong>still</strong><small>BIBLE READER</small></span>
          </a>
          <button className="icon-button sidebar-close" onClick={() => setSidebarOpen(false)} aria-label="Close book list">×</button>
        </div>
        <label className="search-wrap" htmlFor="bookSearch">
          <SearchIcon /><input id="bookSearch" type="search" placeholder="Find a book" value={query} onChange={(event) => setQuery(event.target.value)} />
          <kbd>/</kbd>
        </label>
        <nav className="book-nav" aria-label="Books of the Bible">
          {oldTestament.length > 0 && <section className="book-group"><h2>OLD TESTAMENT</h2><ul className="book-list">{renderBooks(oldTestament)}</ul></section>}
          {newTestament.length > 0 && <section className="book-group"><h2>NEW TESTAMENT</h2><ul className="book-list">{renderBooks(newTestament)}</ul></section>}
          {filteredBooks.length === 0 && <p className="no-books">No books found.</p>}
        </nav>
        <div className="sidebar-footer"><span className="version-dot" aria-hidden="true" />{translation === "svd" ? "SVD · Smith & Van Dyck" : "NIV · New International Version"}</div>
      </aside>
      {sidebarOpen && <button className="sidebar-scrim" aria-label="Close book list" onClick={() => setSidebarOpen(false)} />}

      <main className="main-area">
        <header className="toolbar">
          <div className="toolbar-leading">
            <button className="icon-button sidebar-toggle" onClick={() => setSidebarOpen(!sidebarOpen)} aria-label={sidebarOpen ? "Hide book list" : "Show book list"} aria-expanded={sidebarOpen}><MenuIcon /></button>
            <span className="toolbar-divider" aria-hidden="true" />
            <span className="toolbar-label">A place to read</span>
          </div>
          <div className="toolbar-actions">
            <span className={`offline-indicator${isOnline ? "" : " offline"}`}><span className="status-dot" />{isOnline ? "Online" : "Offline"}</span>
            <button className="translation-trigger" onClick={() => setTranslation(translation === "niv" ? "svd" : "niv")} aria-label={`Switch to ${translation === "niv" ? "Arabic SVD" : "NIV"}`} title="Switch translation">{translation === "niv" ? "SVD · العربية" : "NIV"}</button>
            <button className="icon-button" onClick={() => setTheme(theme === "light" ? "dark" : "light")} aria-label={`Switch to ${theme === "light" ? "dark" : "light"} theme`} title="Switch theme"><MoonIcon /></button>
            <button className="settings-trigger" onClick={() => setSettingsOpen(true)}><GearIcon /><span>Settings</span></button>
          </div>
        </header>

        <div className="reader-scroll">
          <section className="reader">
            <div className="reader-heading">
              <div><p className="eyebrow">{translation === "svd" ? "العهد القديم والجديد · SVD" : `${currentBook.testament.toUpperCase()} · NIV`}</p><h1 dir={translation === "svd" ? "rtl" : "ltr"}>{translation === "svd" ? (svdBookName || currentBook.name) : currentBook.name} <span>{chapter}</span></h1></div>
              <button className="chapter-picker" onClick={() => setChapterPickerOpen(true)} aria-haspopup="dialog" aria-expanded={chapterPickerOpen}><span>{translation === "svd" ? `الإصحاح ${chapter}` : `Chapter ${chapter}`}</span><ChevronDown /></button>
            </div>
            {chapterData ? (
              <article className={`scripture${translation === "svd" ? " arabic-scripture" : ""}`} dir={translation === "svd" ? "rtl" : "ltr"} lang={translation === "svd" ? "ar" : "en"} aria-label={`${currentBook.name} chapter ${chapter}`}>
                {scriptureParagraphs(chapterData.content).map((paragraph, index) => <p key={`${chapterData.id}-${index}`}>{paragraph}</p>)}
                {scriptureParagraphs(chapterData.content).length === 0 && <p>This chapter has no readable text.</p>}
                {translation === "niv" && metadata?.copyright && <p className="copyright">{metadata.copyright}</p>}
              </article>
            ) : loading ? (
              <section className="reader-message" role="status"><span className="loading-mark" /><p>{isOnline ? "Opening your chapter…" : "Looking for a saved chapter…"}</p></section>
            ) : loadError ? (
              <section className="reader-message" role="alert"><p>{loadError}</p><button className="secondary-button" onClick={() => setRefreshToken((value) => value + 1)}>Try again</button></section>
            ) : (
              <section className="welcome">
                <div className="welcome-art" aria-hidden="true"><BookIllustration /></div>
                <p className="eyebrow">MAKE ROOM FOR THE WORD</p>
                <h2>{isOnline ? <>Read without<br />the noise.</> : <>No saved chapter<br />yet.</>}</h2>
                <p className="welcome-copy">{isOnline ? "A simple, quiet place for the NIV. Pick up where you left off, or find a book and settle in." : "Connect and save chapters while online to read them here later."}</p>
                <button className="primary-button" onClick={() => setSettingsOpen(true)}>{connected ? "Open reading settings" : "Connect your NIV access"} <span aria-hidden="true">→</span></button>
                <p className="setup-note">Requires an API.Bible key with NIV access. Your key stays in this browser.</p>
              </section>
            )}
          </section>
        </div>
        <footer className="reader-footer">
          <button className="chapter-step" onClick={() => stepChapter(-1)} disabled={currentBook.id === "GEN" && chapter === 1} aria-label="Previous chapter"><ChevronLeft /><span>Previous</span></button>
          {translation === "svd" ? <span className="offline-ready" aria-label="SVD Bible stored on this device">SVD · On this device</span> : <button className="offline-button" onClick={() => apiKey ? void saveOffline() : setSettingsOpen(true)} disabled={Boolean(downloadProgress)}><DownloadIcon /><span>{downloadProgress ? `${downloadProgress.complete} / ${downloadProgress.total}` : savedCount ? `${savedCount} chapters saved` : "Save Bible offline"}</span></button>}
          <button className="chapter-step" onClick={() => stepChapter(1)} disabled={currentBook.id === "REV" && chapter === currentBook.chapters} aria-label="Next chapter"><span>Next</span><ChevronRight /></button>
        </footer>
      </main>

      {chapterPickerOpen && <div className="dialog-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setChapterPickerOpen(false); }}>
        <section className="app-dialog chapter-dialog" role="dialog" aria-modal="true" aria-labelledby="chapterDialogTitle" dir={translation === "svd" ? "rtl" : "ltr"}>
          <button className="dialog-close icon-button" onClick={() => setChapterPickerOpen(false)} aria-label="Close chapter list">×</button>
          <div className="dialog-content"><p className="eyebrow">JUMP TO</p><h2 id="chapterDialogTitle">{translation === "svd" ? svdBookName || currentBook.name : currentBook.name}</h2><div className="chapter-grid">{Array.from({ length: currentBook.chapters }, (_, index) => index + 1).map((item) => <button key={item} className={item === chapter ? "active" : ""} aria-current={item === chapter ? "page" : undefined} onClick={() => { setChapter(item); setChapterPickerOpen(false); }}>{item}</button>)}</div></div>
        </section>
      </div>}

      {settingsOpen && <div className="dialog-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setSettingsOpen(false); }}>
        <section className="app-dialog settings-dialog" role="dialog" aria-modal="true" aria-labelledby="settingsTitle">
          <button className="dialog-close icon-button" onClick={() => setSettingsOpen(false)} aria-label="Close settings">×</button>
          <div className="dialog-content">
            <p className="eyebrow">YOUR READING SPACE</p><h2 id="settingsTitle">Settings</h2>
            <section className="setting-block">            <div className="setting-heading"><div><h3>Reading size</h3><p>Choose what feels comfortable.</p></div><output>{FONT_LABELS[fontLevel]}</output></div>
              <div className="slider-row"><span className="slider-small" aria-hidden="true">A</span><input type="range" min="0" max="4" step="1" value={fontLevel} aria-label="Reading text size, five levels" onChange={(event) => setFontLevel(Number(event.target.value))} /><span className="slider-large" aria-hidden="true">A</span></div><div className="slider-levels"><span>Small</span><span>Large</span></div>
            </section>
            <section className="setting-block api-setting"><div className="setting-heading"><div><h3>NIV access</h3><p>Use an API.Bible key that includes NIV.</p></div></div><label className="field-label" htmlFor="apiKeyInput">API key</label><div className="key-field"><input id="apiKeyInput" type="password" autoComplete="off" placeholder="Paste your API.Bible key" value={apiInput} onChange={(event) => setApiInput(event.target.value)} /><button className="small-button" onClick={() => void connect()} disabled={!apiInput.trim()}>{connected ? "Check key" : "Connect"}</button></div>{connected && <button className="text-button" onClick={disconnect}>Remove saved key</button>}<p className="privacy-note">Stored only on this device. NIV chapters are cached in this browser for up to 29 days to respect API.Bible’s licensing terms.</p>{metadata?.copyright && <p className="privacy-note">{metadata.copyright}</p>}</section>
            <section className="setting-block offline-setting"><div className="setting-heading"><div><h3>Offline reading</h3><p>{savedCount} fresh chapters saved on this device.</p></div></div>{downloadProgress ? <><p className="download-status">Saving {downloadProgress.book} · {downloadProgress.complete} of {downloadProgress.total} chapters</p><progress max={downloadProgress.total} value={downloadProgress.complete} aria-label="Offline download progress" /><button className="secondary-button" onClick={pauseDownload}>Pause download</button></> : <button className="secondary-button" onClick={() => void saveOffline()} disabled={!apiKey}>Save the whole NIV offline</button>}</section>
            {settingsStatus && <p className="settings-status" role="status">{settingsStatus}</p>}
          </div>
        </section>
      </div>}
    </div>
  );
}

function scriptureParagraphs(content: string): string[] {
  if (typeof DOMParser === "undefined") return [];
  const document = new DOMParser().parseFromString(content, "text/html");
  document.querySelectorAll("script, style, iframe, object").forEach((node) => node.remove());
  const paragraphs = Array.from(document.body.querySelectorAll("p"))
    .map((paragraph) => paragraph.textContent?.replace(/\s+/g, " ").trim() ?? "")
    .filter(Boolean);
  if (paragraphs.length) return paragraphs;
  const text = document.body.textContent?.replace(/\s+/g, " ").trim() ?? "";
  return text ? [text] : [];
}

function BookMark() { return <svg viewBox="0 0 32 32"><path d="M16 5v22M5 9c5-2 8-1 11 2 3-3 6-4 11-2v16c-5-2-8-1-11 2-3-3-6-4-11-2z" /></svg>; }
function SearchIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="8.5" cy="8.5" r="5.5" /><path d="m13 13 4 4" /></svg>; }
function MenuIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M3 5h14M3 10h14M3 15h14" /></svg>; }
function MoonIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M16.7 12.2A7 7 0 0 1 7.8 3.3 7 7 0 1 0 16.7 12.2Z" /></svg>; }
function GearIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="10" cy="10" r="3" /><path d="M16.4 11.8a6.7 6.7 0 0 0 0-3.6l1.3-1-1.6-2.8-1.6.6a6.7 6.7 0 0 0-3.1-1.8L11.2 1H8l-.3 2.2a6.7 6.7 0 0 0-3.1 1.8L3 4.4 1.4 7.2l1.3 1a6.7 6.7 0 0 0 0 3.6l-1.3 1L3 15.6l1.6-.6a6.7 6.7 0 0 0 3.1 1.8L8 19h3.2l.3-2.2a6.7 6.7 0 0 0 3.1-1.8l1.6.6 1.6-2.8z" transform="translate(1 0) scale(.9)" /></svg>; }
function ChevronDown() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m5 7 5 5 5-5" /></svg>; }
function ChevronLeft() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m12 4-6 6 6 6" /></svg>; }
function ChevronRight() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m8 4 6 6-6 6" /></svg>; }
function DownloadIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M10 2v10m-4-4 4 4 4-4M3 14v3h14v-3" /></svg>; }
function BookIllustration() { return <svg viewBox="0 0 180 150"><path className="art-line" d="M90 27v94M90 39c-18-16-39-21-62-14v76c23-7 44-2 62 14 18-16 39-21 62-14V25c-23-7-44-2-62 14Z" /><path className="art-page" d="M90 39c-18-16-39-21-62-14v76c23-7 44-2 62 14zM90 39c18-16 39-21 62-14v76c-23-7-44-2-62 14z" /><path className="art-rule" d="M44 45c12-2 23 0 33 6M44 57c12-2 23 0 33 6M103 51c10-6 21-8 33-6M103 63c10-6 21-8 33-6" /></svg>; }
