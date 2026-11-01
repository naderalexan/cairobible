"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
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
const PALETTES = [
  { id: "cairo", name: "Cairo" },
  { id: "olive", name: "Olive" },
  { id: "nile", name: "Nile" },
  { id: "amethyst", name: "Amethyst" },
  { id: "sandstone", name: "Sandstone" },
] as const;
type PaletteId = (typeof PALETTES)[number]["id"];
const LINE_HEIGHT_OPTIONS = [
  { label: "Small", value: 0.55, ratio: 1.5 },
  { label: "Medium", value: 0.85, ratio: 1.85 },
  { label: "Large", value: 1, ratio: 2 },
] as const;
type LineHeightValue = (typeof LINE_HEIGHT_OPTIONS)[number]["value"];
const POSITION_KEY = "still-reading-position";
const API_KEY_KEY = "still-api-key";

function isLineHeightValue(value: number): value is LineHeightValue {
  return LINE_HEIGHT_OPTIONS.some((option) => option.value === value);
}

function isPaletteId(value: string | null): value is PaletteId {
  return PALETTES.some((palette) => palette.id === value);
}

export default function Home() {
  const [currentBook, setCurrentBook] = useState(books[0]);
  const [chapter, setChapter] = useState(1);
  const [translation, setTranslation] = useState<"niv" | "svd">("niv");
  const [svdBookName, setSvdBookName] = useState("");
  const [query, setQuery] = useState("");
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [chapterPickerOpen, setChapterPickerOpen] = useState(false);
  const [focusMode, setFocusMode] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const [palette, setPalette] = useState<PaletteId>("cairo");
  const [fontLevel, setFontLevel] = useState(2);
  const [lineHeight, setLineHeight] = useState<LineHeightValue>(LINE_HEIGHT_OPTIONS[0].value);
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
  const [selectedVerse, setSelectedVerse] = useState<{ key: string; text: string; reference: string; top: number; left: number } | null>(null);
  const [copyStatus, setCopyStatus] = useState("");
  const selectedVerseKey = selectedVerse?.key;
  const downloadController = useRef<AbortController | null>(null);

  useEffect(() => {
    const savedTranslation = localStorage.getItem("still-translation");
    setTranslation(savedTranslation === "svd" ? "svd" : "niv");
    const savedTheme = localStorage.getItem("still-theme");
    setTheme(savedTheme === "dark" ? "dark" : "light");
    const savedPalette = localStorage.getItem("still-palette");
    if (isPaletteId(savedPalette)) setPalette(savedPalette);
    const savedFont = Number(localStorage.getItem("still-font-level"));
    if (Number.isInteger(savedFont) && savedFont >= 0 && savedFont <= 4) setFontLevel(savedFont);
    const savedLineHeight = Number(localStorage.getItem("still-line-height"));
    if (isLineHeightValue(savedLineHeight)) setLineHeight(savedLineHeight);
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
    if ("serviceWorker" in navigator) {
      if (process.env.NODE_ENV === "production") {
        void navigator.serviceWorker.register("/sw.js").catch(() => undefined);
      } else {
        void navigator.serviceWorker.getRegistrations().then(async (registrations) => {
          const workerUrl = new URL("/sw.js", window.location.origin).href;
          const appRegistrations = registrations.filter((registration) =>
            [registration.active, registration.waiting, registration.installing]
              .some((worker) => worker?.scriptURL === workerUrl),
          );
          await Promise.all(appRegistrations.map((registration) => registration.unregister()));
          const cacheNames = await caches.keys();
          await Promise.all(
            cacheNames
              .filter((name) => name.startsWith("cairo-bible-shell-") || name.startsWith("still-bible-shell-") || name.startsWith("still-niv-shell-"))
              .map((name) => caches.delete(name)),
          );
          if (appRegistrations.length && navigator.serviceWorker.controller) window.location.reload();
        }).catch((error: unknown) => {
          console.error("Could not clear the app service worker in development.", error);
        });
      }
    }
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
    if (!settingsOpen && !chapterPickerOpen && !focusMode) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setSettingsOpen(false);
        setChapterPickerOpen(false);
        setFocusMode(false);
      }
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [settingsOpen, chapterPickerOpen, focusMode]);

  useEffect(() => {
    if (ready) localStorage.setItem("still-theme", theme);
  }, [ready, theme]);

  useEffect(() => {
    if (ready) localStorage.setItem("still-palette", palette);
  }, [ready, palette]);

  useEffect(() => {
    if (ready) localStorage.setItem("still-font-level", String(fontLevel));
  }, [ready, fontLevel]);

  useEffect(() => {
    if (ready) localStorage.setItem("still-line-height", String(lineHeight));
  }, [ready, lineHeight]);

  useEffect(() => {
    setSelectedVerse(null);
    setCopyStatus("");
  }, [chapter, currentBook.id, translation]);

  useEffect(() => {
    if (!selectedVerseKey) return;
    const updatePosition = () => {
      const verse = document.querySelector<HTMLElement>(`[data-verse-key="${selectedVerseKey}"]`);
      if (!verse) {
        setSelectedVerse(null);
        return;
      }
      const rect = verse.getBoundingClientRect();
      setSelectedVerse((current) => current ? { ...current, top: rect.top, left: Math.max(8, rect.left - 44) } : null);
    };
    const scrollArea = document.querySelector(".reader-scroll");
    scrollArea?.addEventListener("scroll", updatePosition, { passive: true });
    window.addEventListener("resize", updatePosition);
    return () => {
      scrollArea?.removeEventListener("scroll", updatePosition);
      window.removeEventListener("resize", updatePosition);
    };
  }, [selectedVerseKey]);

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

  function handleVerseSelection() {
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed || !selection.toString().trim()) {
      setSelectedVerse(null);
      return;
    }
    const node = selection.getRangeAt(0).commonAncestorContainer;
    const element = node instanceof Element ? node : node.parentElement;
    const verse = element?.closest<HTMLElement>("p.verse[data-verse-number]");
    if (!verse) {
      setSelectedVerse(null);
      return;
    }
    const verseNumber = verse.dataset.verseNumber;
    if (!verseNumber) return;
    const verseText = verse.cloneNode(true) as HTMLElement;
    verseText.querySelectorAll(".verse-number").forEach((number) => number.remove());
    const text = verseText.textContent?.replace(/\s+/g, " ").trim();
    if (!text) return;
    const rect = verse.getBoundingClientRect();
    setSelectedVerse({
      key: verse.dataset.verseKey ?? "",
      text,
      reference: `${currentBook.name} ${chapter}:${verseNumber}`,
      top: rect.top,
      left: Math.max(8, rect.left - 44),
    });
  }

  async function copySelectedVerse() {
    if (!selectedVerse) return;
    const copyText = `"${selectedVerse.text}" - ${selectedVerse.reference}`;
    try {
      await navigator.clipboard.writeText(copyText);
    } catch {
      const textarea = document.createElement("textarea");
      textarea.value = copyText;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.append(textarea);
      textarea.select();
      const copied = document.execCommand("copy");
      textarea.remove();
      if (!copied) {
        setCopyStatus("Could not copy this verse.");
        return;
      }
    }
    setCopyStatus(`Copied ${selectedVerse.reference}`);
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

  const selectedLineHeight = LINE_HEIGHT_OPTIONS.find((option) => option.value === lineHeight) ?? LINE_HEIGHT_OPTIONS[0];
  const selectedPalette = PALETTES.find((option) => option.id === palette) ?? PALETTES[0];
  const paragraphs = chapterData ? scriptureParagraphs(chapterData.content) : [];

  const isFirstChapter = currentBook.id === "GEN" && chapter === 1;
  const isLastChapter = currentBook.id === "REV" && chapter === currentBook.chapters;

  return (
    <div className={`app-shell ${theme}${focusMode ? " focus-mode" : ""}`} data-palette={palette} style={{ "--reading-size": `${FONT_SIZES[fontLevel]}px`, "--reading-line-height": selectedLineHeight.ratio } as CSSProperties}>
      <aside className={`sidebar${sidebarOpen ? " open" : " collapsed"}`} aria-label="Bible books">
        <div className="sidebar-top">
          <Link className="brand" href="/" aria-label="Cairo Bible home">
            <span className="brand-mark" aria-hidden="true"><BookMark /></span>
            <span><strong>Cairo Bible</strong><small>READING, MADE QUIET</small></span>
          </Link>
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
            <button className="icon-button" onClick={() => setTheme(theme === "light" ? "dark" : "light")} aria-label={`Switch to ${theme === "light" ? "dark" : "light"} appearance`} title={`Switch to ${theme === "light" ? "dark" : "light"} appearance`}>{theme === "light" ? <MoonIcon /> : <SunIcon />}</button>
            <button className="focus-trigger" onClick={() => { setFocusMode(true); setSettingsOpen(false); setChapterPickerOpen(false); }}><FocusIcon /><span>Focus</span></button>
            <button className="settings-trigger" onClick={() => setSettingsOpen(!settingsOpen)} aria-expanded={settingsOpen} aria-controls="settingsDropdown"><GearIcon /><span>Settings</span></button>
          </div>
        </header>

        {settingsOpen && <section className="settings-dropdown" id="settingsDropdown" aria-labelledby="settingsTitle">
          <button className="dialog-close icon-button" onClick={() => setSettingsOpen(false)} aria-label="Close settings">×</button>
          <div className="dialog-content">
            <p className="eyebrow">YOUR READING SPACE</p><h2 id="settingsTitle">Settings</h2>
            <section className="setting-block appearance-setting">
              <div className="setting-heading"><div><h3 id="appearanceTitle">Appearance</h3><p>Choose light or dark mode.</p></div><output>{theme === "light" ? "Light" : "Dark"}</output></div>
              <div className="appearance-options" role="radiogroup" aria-labelledby="appearanceTitle">
                {(["light", "dark"] as const).map((option) => <label className="appearance-option" key={option}>
                  <input type="radio" name="appearance" value={option} checked={theme === option} onChange={() => setTheme(option)} />
                  <span>{option === "light" ? "Light" : "Dark"}</span>
                </label>)}
              </div>
            </section>
            <section className="setting-block palette-setting">
              <div className="setting-heading"><div><h3 id="paletteTitle">Color palette</h3><p>Choose the colors for your reading space.</p></div><output>{selectedPalette.name}</output></div>
              <div className="palette-options" role="radiogroup" aria-labelledby="paletteTitle">
                {PALETTES.map((option) => <label className="palette-option" key={option.id}>
                  <input type="radio" name="color-palette" value={option.id} checked={palette === option.id} onChange={() => setPalette(option.id)} />
                  <span className="palette-swatch" data-palette-swatch={option.id} aria-hidden="true" />
                  <span className="palette-name">{option.name}</span>
                </label>)}
              </div>
            </section>
            <section className="setting-block">            <div className="setting-heading"><div><h3>Reading size</h3><p>Choose what feels comfortable.</p></div><output>{FONT_LABELS[fontLevel]}</output></div>
              <div className="slider-row"><span className="slider-small" aria-hidden="true">A</span><input type="range" min="0" max="4" step="1" value={fontLevel} aria-label="Reading text size, five levels" onChange={(event) => setFontLevel(Number(event.target.value))} /><span className="slider-large" aria-hidden="true">A</span></div><div className="slider-levels"><span>Small</span><span>Large</span></div>
            </section>
            <section className="setting-block">
              <div className="setting-heading"><div><h3>Line spacing</h3><p>Adjust the space between lines.</p></div><output>{selectedLineHeight.label}</output></div>
              <div className="line-height-options" role="radiogroup" aria-label="Reader line spacing">
                {LINE_HEIGHT_OPTIONS.map((option) => <label className="line-height-option" key={option.value}>
                  <input type="radio" name="reading-line-height" value={option.value} checked={lineHeight === option.value} onChange={(event) => { const value = Number(event.target.value); if (isLineHeightValue(value)) setLineHeight(value); }} />
                  <span>{option.label}</span>
                </label>)}
              </div>
            </section>
            <section className="setting-block api-setting"><div className="setting-heading"><div><h3>NIV access</h3><p>Use an API.Bible key that includes NIV.</p></div></div><label className="field-label" htmlFor="apiKeyInput">API key</label><div className="key-field"><input id="apiKeyInput" type="password" autoComplete="off" placeholder="Paste your API.Bible key" value={apiInput} onChange={(event) => setApiInput(event.target.value)} /><button className="small-button" onClick={() => void connect()} disabled={!apiInput.trim()}>{connected ? "Check key" : "Connect"}</button></div>{connected && <button className="text-button" onClick={disconnect}>Remove saved key</button>}<p className="privacy-note">Stored only on this device. NIV chapters are cached in this browser for up to 29 days to respect API.Bible’s licensing terms.</p>{metadata?.copyright && <p className="privacy-note">{metadata.copyright}</p>}</section>
            <section className="setting-block offline-setting"><div className="setting-heading"><div><h3>Offline reading</h3><p>{savedCount} fresh chapters saved on this device.</p></div></div>{downloadProgress ? <><p className="download-status">Saving {downloadProgress.book} · {downloadProgress.complete} of {downloadProgress.total} chapters</p><progress max={downloadProgress.total} value={downloadProgress.complete} aria-label="Offline download progress" /><button className="secondary-button" onClick={pauseDownload}>Pause download</button></> : <button className="secondary-button" onClick={() => void saveOffline()} disabled={!apiKey}>Save the whole NIV offline</button>}</section>
            {settingsStatus && <p className="settings-status" role="status">{settingsStatus}</p>}
          </div>
        </section>}

        <div className="reader-scroll">
          <section className="reader">
            <div className="reader-heading">
              <div><p className="eyebrow">{translation === "svd" ? "العهد القديم والجديد · SVD" : `${currentBook.testament.toUpperCase()} · NIV`}</p><h1 dir={translation === "svd" ? "rtl" : "ltr"}>{translation === "svd" ? (svdBookName || currentBook.name) : currentBook.name} <span>{chapter}</span></h1></div>
              <button className="chapter-picker" onClick={() => setChapterPickerOpen(true)} aria-haspopup="dialog" aria-expanded={chapterPickerOpen}><span>{translation === "svd" ? `الإصحاح ${chapter}` : `Chapter ${chapter}`}</span><ChevronDown /></button>
            </div>
            {chapterData ? (
              <article className={`scripture${translation === "svd" ? " arabic-scripture" : ""}`} dir={translation === "svd" ? "rtl" : "ltr"} lang={translation === "svd" ? "ar" : "en"} aria-label={`${currentBook.name} chapter ${chapter}`} onMouseUp={handleVerseSelection} onKeyUp={handleVerseSelection} onTouchEnd={handleVerseSelection}>
                {paragraphs.map((paragraph, index) => <p key={`${chapterData.id}-${index}`} className={paragraph.isVerse ? "verse" : undefined} data-verse-number={paragraph.verseNumber} data-verse-key={paragraph.verseNumber ? `${chapterData.id}-${paragraph.verseNumber}` : undefined}>{paragraph.content}</p>)}
                {paragraphs.length === 0 && <p>This chapter has no readable text.</p>}
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
          <button className="chapter-step" onClick={() => stepChapter(-1)} disabled={isFirstChapter} aria-label="Previous chapter"><ChevronLeft /><span>Previous</span></button>
          {translation === "svd" ? <span className="offline-ready" aria-label="SVD Bible stored on this device">SVD · On this device</span> : <button className="offline-button" onClick={() => apiKey ? void saveOffline() : setSettingsOpen(true)} disabled={Boolean(downloadProgress)}><DownloadIcon /><span>{downloadProgress ? `${downloadProgress.complete} / ${downloadProgress.total}` : savedCount ? `${savedCount} chapters saved` : "Save Bible offline"}</span></button>}
          <button className="chapter-step" onClick={() => stepChapter(1)} disabled={isLastChapter} aria-label="Next chapter"><span>Next</span><ChevronRight /></button>
        </footer>
        {focusMode && <nav className="focus-actions" aria-label="Focus reading controls">
          <button className="focus-exit" onClick={() => setFocusMode(false)}>Exit focus</button>
          <button className="focus-arrow" onClick={() => setSettingsOpen(!settingsOpen)} aria-label={settingsOpen ? "Close settings" : "Open settings"} aria-expanded={settingsOpen} aria-controls="settingsDropdown" title="Settings"><GearIcon /></button>
          <button className="focus-arrow" onClick={() => stepChapter(-1)} disabled={isFirstChapter} aria-label="Previous chapter"><ChevronLeft /></button>
          <button className="focus-arrow" onClick={() => stepChapter(1)} disabled={isLastChapter} aria-label="Next chapter"><ChevronRight /></button>
        </nav>}
      </main>

      {chapterPickerOpen && <div className="dialog-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setChapterPickerOpen(false); }}>
        <section className="app-dialog chapter-dialog" role="dialog" aria-modal="true" aria-labelledby="chapterDialogTitle" dir={translation === "svd" ? "rtl" : "ltr"}>
          <button className="dialog-close icon-button" onClick={() => setChapterPickerOpen(false)} aria-label="Close chapter list">×</button>
          <div className="dialog-content"><p className="eyebrow">JUMP TO</p><h2 id="chapterDialogTitle">{translation === "svd" ? svdBookName || currentBook.name : currentBook.name}</h2><div className="chapter-grid">{Array.from({ length: currentBook.chapters }, (_, index) => index + 1).map((item) => <button key={item} className={item === chapter ? "active" : ""} aria-current={item === chapter ? "page" : undefined} onClick={() => { setChapter(item); setChapterPickerOpen(false); }}>{item}</button>)}</div></div>
        </section>
      </div>}
      {selectedVerse && <button className="verse-copy-popup" style={{ top: selectedVerse.top, left: selectedVerse.left }} onClick={() => void copySelectedVerse()} aria-label={`Copy ${selectedVerse.reference}`} title={`Copy ${selectedVerse.reference}`}><CopyIcon /></button>}
      <span className="visually-hidden" role="status" aria-live="polite">{copyStatus}</span>

    </div>
  );
}

type ScriptureParagraph = { content: ReactNode[]; isVerse: boolean; verseNumber?: string };
type ScriptureToken = { content: ReactNode; startsVerse: boolean; verseNumber?: string };

function scriptureParagraphs(content: string): ScriptureParagraph[] {
  if (typeof DOMParser === "undefined") return [];
  const document = new DOMParser().parseFromString(content, "text/html");
  document.querySelectorAll("script, style, iframe, object, svg, math, template").forEach((node) => node.remove());
  const paragraphs = Array.from(document.body.querySelectorAll("p"));
  const source = paragraphs.length ? paragraphs : [document.body];
  const blocks = source.flatMap((paragraph) => {
    if (!paragraph.textContent?.trim()) return [];

    const tokens = Array.from(paragraph.childNodes).flatMap((node, index) => renderScriptureTokens(node, String(index)));
    const result: ScriptureParagraph[] = [];
    let current: ReactNode[] = [];
    let isVerse = false;
    let verseNumber: string | undefined;
    const finish = () => {
      if (current.length) result.push({ content: current, isVerse, verseNumber });
      current = [];
    };

    tokens.forEach((token) => {
      if (token.startsVerse) {
        finish();
        isVerse = true;
        verseNumber = token.verseNumber;
      }
      current.push(token.content);
    });
    finish();
    return result;
  });

  return blocks.reduce<ScriptureParagraph[]>((result, paragraph, index) => {
    const previous = result[result.length - 1];
    if (!paragraph.isVerse && previous?.isVerse) {
      previous.content.push(<br key={`continuation-${index}`} />, ...paragraph.content);
    } else {
      result.push(paragraph);
    }
    return result;
  }, []);
}

function renderScriptureTokens(node: Node, key: string): ScriptureToken[] {
  if (node.nodeType === Node.TEXT_NODE) {
    return node.textContent ? [{ content: node.textContent, startsVerse: false }] : [];
  }
  if (!(node instanceof Element)) return [];
  if (node.matches("[data-number], .v, .verse-num, .verse-number")) {
    const verseNumber = node.getAttribute("data-number")?.trim() || node.textContent?.trim() || undefined;
    return [{ content: <span key={key} className="verse-number">{node.textContent}</span>, startsVerse: true, verseNumber }];
  }

  if (node.tagName.toLowerCase() === "br") return [{ content: <br key={key} />, startsVerse: false }];

  return Array.from(node.childNodes).flatMap((child, index) => renderScriptureTokens(child, `${key}-${index}`)).map((token, index) => ({
    ...token,
    content: wrapScriptureInline(node.tagName.toLowerCase(), token.content, `${key}-${index}`),
  }));
}

function wrapScriptureInline(tag: string, content: ReactNode, key: string): ReactNode {
  switch (tag) {
    case "b": return <b key={key}>{content}</b>;
    case "strong": return <strong key={key}>{content}</strong>;
    case "i": return <i key={key}>{content}</i>;
    case "em": return <em key={key}>{content}</em>;
    case "sup": return <sup key={key}>{content}</sup>;
    case "sub": return <sub key={key}>{content}</sub>;
    case "span": return <span key={key}>{content}</span>;
    default: return content;
  }
}

function BookMark() { return <svg viewBox="0 0 32 32"><path d="M16 3.5c-6.5 0-11 4.8-11 11.5v13h22V15c0-6.7-4.5-11.5-11-11.5Z" /><path d="M16 16v11M8 19c3.4-1.2 5.9-.4 8 1.7 2.1-2.1 4.6-2.9 8-1.7v8c-3.4-1.2-5.9-.4-8 1.7-2.1-2.1-4.6-2.9-8-1.7z" /></svg>; }
function SearchIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="8.5" cy="8.5" r="5.5" /><path d="m13 13 4 4" /></svg>; }
function MenuIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M3 5h14M3 10h14M3 15h14" /></svg>; }
function MoonIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M16.7 12.2A7 7 0 0 1 7.8 3.3 7 7 0 1 0 16.7 12.2Z" /></svg>; }
function SunIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="10" cy="10" r="3.5" /><path d="M10 1.5v2M10 16.5v2M18.5 10h-2M3.5 10h-2m14.51-6.01-1.42 1.42M5.41 14.59l-1.42 1.42m12.02 0-1.42-1.42M5.41 5.41 3.99 3.99" /></svg>; }
function GearIcon() { return <svg viewBox="0 0 20 20" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><circle cx="10" cy="10" r="3" /><path d="M16.4 11.8a6.7 6.7 0 0 0 0-3.6l1.3-1-1.6-2.8-1.6.6a6.7 6.7 0 0 0-3.1-1.8L11.2 1H8l-.3 2.2a6.7 6.7 0 0 0-3.1 1.8L3 4.4 1.4 7.2l1.3 1a6.7 6.7 0 0 0 0 3.6l-1.3 1L3 15.6l1.6-.6a6.7 6.7 0 0 0 3.1 1.8L8 19h3.2l.3-2.2a6.7 6.7 0 0 0 3.1-1.8l1.6.6 1.6-2.8z" /></svg>; }
function ChevronDown() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m5 7 5 5 5-5" /></svg>; }
function ChevronLeft() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m12 4-6 6 6 6" /></svg>; }
function ChevronRight() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m8 4 6 6-6 6" /></svg>; }
function DownloadIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M10 2v10m-4-4 4 4 4-4M3 14v3h14v-3" /></svg>; }
function CopyIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><rect x="7" y="6" width="10" height="12" rx="1.5" /><path d="M13 3H4.5A1.5 1.5 0 0 0 3 4.5V15" /></svg>; }
function FocusIcon() { return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M7 3H4a1 1 0 0 0-1 1v3m10-4h3a1 1 0 0 1 1 1v3M3 13v3a1 1 0 0 0 1 1h3m10-4v3a1 1 0 0 1-1 1h-3" /></svg>; }
function BookIllustration() { return <svg viewBox="0 0 180 150"><path className="art-line" d="M90 27v94M90 39c-18-16-39-21-62-14v76c23-7 44-2 62 14 18-16 39-21 62-14V25c-23-7-44-2-62 14Z" /><path className="art-page" d="M90 39c-18-16-39-21-62-14v76c23-7 44-2 62 14zM90 39c18-16 39-21 62-14v76c-23-7-44-2-62 14z" /><path className="art-rule" d="M44 45c12-2 23 0 33 6M44 57c12-2 23 0 33 6M103 51c10-6 21-8 33-6M103 63c10-6 21-8 33-6" /></svg>; }
