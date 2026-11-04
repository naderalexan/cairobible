import json
import os
import threading
import time
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
            chapter_id = chapter.get("id")
            number = chapter.get("number")
            if not isinstance(chapter_id, str) or not isinstance(number, str) or not number.isdecimal():
                raise RuntimeError("API.Bible returned incomplete NIV chapter data.")
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
        "copyright": chapter["copyright"] or corpus["copyright"],
        "fumsToken": chapter["fumsToken"],
    }
