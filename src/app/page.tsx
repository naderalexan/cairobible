"use client";

import { useMemo, useState } from "react";
import { books } from "@/lib/books";

export default function Home() {
  const [currentBook, setCurrentBook] = useState(books[0]);
  const [chapter, setChapter] = useState(1);
  const [query, setQuery] = useState("");
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [chapterPickerOpen, setChapterPickerOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const [fontLevel, setFontLevel] = useState(2);

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
    <div className={`app-shell ${theme}`}>
      <aside className={`sidebar${sidebarOpen ? " open" : " collapsed"}`} aria-label="Bible books">
        <div className="sidebar-top">
          <a className="brand" href="#" aria-label="Still NIV Bible home">
            <span className="brand-mark" aria-hidden="true"><BookMark /></span>
            <span><strong>still</strong><small>THE NIV BIBLE</small></span>
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
        <div className="sidebar-footer"><span className="version-dot" aria-hidden="true" />NIV · New International Version</div>
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
            <span className="offline-indicator"><span className="status-dot" />Online</span>
            <button className="icon-button" onClick={() => setTheme(theme === "light" ? "dark" : "light")} aria-label={`Switch to ${theme === "light" ? "dark" : "light"} theme`} title="Switch theme"><MoonIcon /></button>
            <button className="settings-trigger" onClick={() => setSettingsOpen(true)}><GearIcon /><span>Settings</span></button>
          </div>
        </header>

        <div className="reader-scroll">
          <section className="reader">
            <div className="reader-heading">
              <div><p className="eyebrow">{currentBook.testament.toUpperCase()} <span>·</span> NIV</p><h1>{currentBook.name} <span>{chapter}</span></h1></div>
              <button className="chapter-picker" onClick={() => setChapterPickerOpen(true)} aria-haspopup="dialog" aria-expanded={chapterPickerOpen}><span>Chapter {chapter}</span><ChevronDown /></button>
            </div>
            <section className="welcome">
              <div className="welcome-art" aria-hidden="true"><BookIllustration /></div>
              <p className="eyebrow">MAKE ROOM FOR THE WORD</p>
              <h2>Read without<br />the noise.</h2>
              <p className="welcome-copy">A simple, quiet place for the NIV. Pick up where you left off, or find a book and settle in.</p>
              <button className="primary-button" onClick={() => setSettingsOpen(true)}>Connect your NIV access <span aria-hidden="true">→</span></button>
              <p className="setup-note">Requires an API.Bible key with NIV access. Your key stays in this browser.</p>
            </section>
          </section>
        </div>
        <footer className="reader-footer">
          <button className="chapter-step" onClick={() => stepChapter(-1)} disabled={currentBook.id === "GEN" && chapter === 1} aria-label="Previous chapter"><ChevronLeft /><span>Previous</span></button>
          <button className="offline-button" onClick={() => setSettingsOpen(true)}><DownloadIcon /><span>Save Bible offline</span></button>
          <button className="chapter-step" onClick={() => stepChapter(1)} disabled={currentBook.id === "REV" && chapter === currentBook.chapters} aria-label="Next chapter"><span>Next</span><ChevronRight /></button>
        </footer>
      </main>

      {chapterPickerOpen && <div className="dialog-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setChapterPickerOpen(false); }}>
        <section className="app-dialog chapter-dialog" role="dialog" aria-modal="true" aria-labelledby="chapterDialogTitle">
          <button className="dialog-close icon-button" onClick={() => setChapterPickerOpen(false)} aria-label="Close chapter list">×</button>
          <div className="dialog-content"><p className="eyebrow">JUMP TO</p><h2 id="chapterDialogTitle">{currentBook.name}</h2><div className="chapter-grid">{Array.from({ length: currentBook.chapters }, (_, index) => index + 1).map((item) => <button key={item} className={item === chapter ? "active" : ""} aria-current={item === chapter ? "page" : undefined} onClick={() => { setChapter(item); setChapterPickerOpen(false); }}>{item}</button>)}</div></div>
        </section>
      </div>}

      {settingsOpen && <div className="dialog-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setSettingsOpen(false); }}>
        <section className="app-dialog settings-dialog" role="dialog" aria-modal="true" aria-labelledby="settingsTitle">
          <button className="dialog-close icon-button" onClick={() => setSettingsOpen(false)} aria-label="Close settings">×</button>
          <div className="dialog-content">
            <p className="eyebrow">YOUR READING SPACE</p><h2 id="settingsTitle">Settings</h2>
            <section className="setting-block"><div className="setting-heading"><div><h3>Reading size</h3><p>Choose what feels comfortable.</p></div><output>{["Small", "Comfortable", "Medium", "Large", "Extra large"][fontLevel]}</output></div>
              <div className="slider-row"><span className="slider-small" aria-hidden="true">A</span><input type="range" min="0" max="4" step="1" value={fontLevel} aria-label="Reading text size, five levels" onChange={(event) => setFontLevel(Number(event.target.value))} /><span className="slider-large" aria-hidden="true">A</span></div><div className="slider-levels"><span>Small</span><span>Large</span></div>
            </section>
            <section className="setting-block api-setting"><div className="setting-heading"><div><h3>NIV access</h3><p>Use an API.Bible key that includes NIV.</p></div></div><label className="field-label" htmlFor="apiKeyInput">API key</label><div className="key-field"><input id="apiKeyInput" type="password" autoComplete="off" placeholder="Paste your API.Bible key" /><button className="small-button">Connect</button></div><p className="privacy-note">Stored only on this device. Scripture is fetched directly from API.Bible and cached for up to 30 days.</p></section>
            <section className="setting-block offline-setting"><div className="setting-heading"><div><h3>Offline reading</h3><p>Save chapters for your next offline moment.</p></div></div><button className="secondary-button">Save the whole NIV offline</button></section>
          </div>
        </section>
      </div>}
    </div>
  );
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
