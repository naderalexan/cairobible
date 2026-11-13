import json
import os
import re
import threading
import time
from html.parser import HTMLParser
from pathlib import Path
from typing import Any
from urllib.parse import quote
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from litestar.exceptions import HTTPException, NotFoundException, ServiceUnavailableException

NIV_BIBLE_ID = "78a9f6124f344018-01"
API_ROOT = "https://rest.api.bible/v1"
CORPUS_TTL = 29 * 24 * 60 * 60
_sync_lock = threading.Lock()


class _ChapterHeadings(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.headings: list[dict[str, Any]] = []
        self.paragraph_class: str | None = None
        self.paragraph_text: list[str] = []
        self.last_verse: int | None = None
        self.verse_number: str | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if tag == "p":
            self.paragraph_class = attributes.get("class", "")
            self.paragraph_text = []
        elif tag == "span":
            number = attributes.get("data-number")
            if number and number.isdecimal():
                self.verse_number = number

    def handle_data(self, data: str) -> None:
        if self.paragraph_class is not None:
            self.paragraph_text.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == "span" and self.verse_number is not None:
            self.last_verse = int(self.verse_number)
            self.verse_number = None
        if tag != "p" or self.paragraph_class is None:
            return
        classes = self.paragraph_class.split()
        kind = next((
            name for name, pattern in (
                ("section", r"s\d*"),
                ("speaker", r"sp"),
                ("descriptive", r"d"),
            )
            if any(re.fullmatch(pattern, class_name) for class_name in classes)
        ), None)
        title = " ".join("".join(self.paragraph_text).split())
        if kind and title:
            self.headings.append({"type": kind, "text": title, "afterVerse": self.last_verse})
        self.paragraph_class = None


def chapter_headings(content: str) -> list[dict[str, Any]]:
    parser = _ChapterHeadings()
    parser.feed(content)
    return parser.headings


def corpus_path() -> Path:
    return Path(os.environ.get("NIV_CORPUS_PATH", Path(__file__).resolve().parents[2] / "var" / "niv-corpus.json"))


def fetch_api_bible(path: str) -> dict[str, Any]:
    api_key = os.environ.get("API_BIBLE_KEY", "").strip()
    if not api_key:
        raise ServiceUnavailableException("NIV is not configured on the server.")
    request = Request(f"{API_ROOT}{path}", headers={"api-key": api_key, "Content-Type": "application/json"})
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except (HTTPError, URLError, TimeoutError) as error:
        raise RuntimeError("API.Bible request failed.") from error


def _load_cached() -> dict[str, Any] | None:
    try:
        corpus = json.loads(corpus_path().read_text())
        if isinstance(corpus.get("books"), dict) and isinstance(corpus.get("fetchedAt"), (int, float)):
            return corpus
    except (OSError, ValueError, AttributeError):
        pass
    return None


def _chapter_number(book_id: str, chapter: dict[str, Any]) -> tuple[str, str] | None:
    chapter_id = chapter.get("id")
    number = chapter.get("number")
    if not isinstance(chapter_id, str):
        raise RuntimeError(f"API.Bible returned an invalid chapter ID for {book_id}: {chapter_id!r}.")
    if (
        isinstance(number, str)
        and number.casefold() == "intro"
        and chapter_id.casefold() == f"{book_id}.intro".casefold()
    ):
        return None
    if isinstance(number, int):
        number = str(number)
    if not isinstance(number, str) or not number.isdecimal():
        number = chapter_id.removeprefix(f"{book_id}.")
    if not number.isdecimal():
        raise RuntimeError(
            f"API.Bible returned an invalid chapter number for {book_id}/{chapter_id}: {number!r}."
        )
    return chapter_id, number


def _refresh_corpus() -> dict[str, Any]:
    bible = fetch_api_bible(f"/bibles/{NIV_BIBLE_ID}").get("data", {})
    copyright = bible.get("copyright")
    if not isinstance(copyright, str) or not copyright.strip():
        raise RuntimeError("API.Bible returned no NIV copyright information.")
    books = fetch_api_bible(f"/bibles/{NIV_BIBLE_ID}/books?include-chapters=true").get("data")
    if not isinstance(books, list) or not books:
        raise RuntimeError("API.Bible returned no NIV books.")

    corpus_books: dict[str, Any] = {}
    for book in books:
        book_id = book.get("id")
        if not isinstance(book_id, str) or not isinstance(book.get("chapters"), list):
            raise RuntimeError("API.Bible returned incomplete NIV book data.")
        chapters: dict[str, Any] = {}
        for chapter in book["chapters"]:
            chapter_data = _chapter_number(book_id, chapter)
            if chapter_data is None:
                continue
            chapter_id, number = chapter_data
            response = fetch_api_bible(
                f"/bibles/{NIV_BIBLE_ID}/chapters/{quote(chapter_id, safe='.')}"
                "?content-type=html&include-notes=false&include-titles=true"
                "&include-chapter-numbers=false&include-verse-numbers=true&include-verse-spans=false"
            )
            data = response.get("data", {})
            fums_token = response.get("meta", {}).get("fumsToken")
            if not isinstance(data.get("content"), str) or not data["content"].strip():
                raise RuntimeError("API.Bible returned an empty NIV chapter.")
            if not isinstance(fums_token, str) or not fums_token:
                raise RuntimeError("API.Bible returned no FUMS token for an NIV chapter.")
            chapters[str(int(number))] = {
                "content": data["content"],
                "copyright": data.get("copyright") or copyright,
                "fumsToken": fums_token,
            }
        if not chapters:
            raise RuntimeError("API.Bible returned an NIV book with no chapters.")
        corpus_books[book_id] = {
            "name": book.get("name") or book.get("nameLong") or book_id,
            "nameLong": book.get("nameLong") or book.get("name") or book_id,
            "chapters": chapters,
        }

    candidate = {"fetchedAt": time.time(), "copyright": copyright, "books": corpus_books}
    path = corpus_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{threading.get_ident()}.tmp")
    temporary.write_text(json.dumps(candidate, ensure_ascii=False))
    os.replace(temporary, path)
    return candidate


def get_corpus() -> dict[str, Any]:
    if os.environ.get("NIV_CORPUS_LICENSE_CONFIRMED", "").casefold() != "true":
        raise ServiceUnavailableException("NIV corpus access is disabled until its license is confirmed.")

    cached = _load_cached()
    if cached and time.time() - cached["fetchedAt"] < CORPUS_TTL:
        return cached

    with _sync_lock:
        cached = _load_cached()
        if cached and time.time() - cached["fetchedAt"] < CORPUS_TTL:
            return cached
        try:
            return _refresh_corpus()
        except Exception as error:
            if cached:
                return cached
            raise HTTPException(status_code=502, detail="Could not retrieve the NIV corpus from API.Bible.") from error


def find_niv_book(corpus: dict[str, Any], book_title: str) -> tuple[str, dict[str, Any]]:
    title = "".join(character for character in book_title.casefold() if character.isalnum())
    book_id = next(
        (
            candidate_id
            for candidate_id, book in corpus["books"].items()
            if book_title.casefold() == candidate_id.casefold()
            or title in {
                "".join(character for character in book[name].casefold() if character.isalnum())
                for name in ("name", "nameLong")
            }
        ),
        None,
    )
    if book_id is None:
        raise NotFoundException("Book not found.")
    return book_id, corpus["books"][book_id]


def get_book_response(book_title: str) -> dict[str, Any]:
    corpus = get_corpus()
    book_id, book = find_niv_book(corpus, book_title)
    return {
        "translation": "niv",
        "bookId": book_id,
        "bookName": book["name"],
        "copyright": corpus["copyright"],
        "chapters": {number: chapter["content"] for number, chapter in book["chapters"].items()},
        "fumsTokens": {number: chapter["fumsToken"] for number, chapter in book["chapters"].items()},
    }


def get_chapter_response(book_title: str, number: int) -> dict[str, Any]:
    corpus = get_corpus()
    book_id, book = find_niv_book(corpus, book_title)
    chapter = book["chapters"].get(str(number))
    if number < 1 or chapter is None:
        raise NotFoundException("Chapter not found.")
    return {
        "translation": "niv",
        "bookId": book_id,
        "bookName": book["name"],
        "chapter": number,
        "content": chapter["content"],
        "headings": chapter_headings(chapter["content"]),
        "copyright": chapter["copyright"] or corpus["copyright"],
        "fumsToken": chapter["fumsToken"],
    }
