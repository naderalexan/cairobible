import json
import unicodedata
from functools import lru_cache
from html import escape
from pathlib import Path
from typing import Any

from litestar import Litestar, get
from litestar.config.cors import CORSConfig
from litestar.exceptions import NotFoundException

DATA_DIR = Path(__file__).resolve().parents[2] / "public" / "data"


@lru_cache(maxsize=1)
def load_corpus() -> tuple[dict[str, Any], dict[str, Any]]:
    corpus = json.loads((DATA_DIR / "arb-vd.json").read_text())
    verse_map = json.loads((DATA_DIR / "arb-vd-verses.json").read_text())
    return corpus, verse_map


def normalize_title(title: str) -> str:
    normalized = unicodedata.normalize("NFKD", title).replace("ٱ", "ا").casefold()
    return "".join(char for char in normalized if not unicodedata.category(char).startswith("M") and char.isalnum())


def find_book(translation: str, book_title: str) -> tuple[str, dict[str, Any], dict[str, Any]]:
    if translation.casefold() not in {"svd", "arb-vd"}:
        raise NotFoundException("Translation not found.")

    corpus, verse_map = load_corpus()
    books = corpus["books"]
    book_id = book_title.upper()
    if book_id not in books:
        title = normalize_title(book_title)
        matches = [
            candidate_id
            for candidate_id, candidate in books.items()
            if title == normalize_title(candidate["name"])
            or title in normalize_title(candidate["name"])
        ]
        if len(matches) != 1:
            raise NotFoundException("Book not found.")
        book_id = matches[0]

    return book_id, books[book_id], verse_map["books"].get(book_id, {})


def marked_content(content: str, offsets: list[int]) -> str:
    parts: list[str] = []
    cursor = 0
    for index, offset in enumerate(offsets):
        if not isinstance(offset, int) or offset < 0 or (index > 0 and offset <= cursor) or offset > len(content):
            return escape(content, quote=False)
        parts.append(escape(content[cursor:offset], quote=False))
        parts.append(f'<span data-number="{index + 1}">{index + 1}</span>')
        cursor = offset
    parts.append(escape(content[cursor:], quote=False))
    return "".join(parts)


def chapter_content(chapter_key: str, content: str, verse_map: dict[str, Any]) -> str:
    offsets = verse_map.get(chapter_key)
    return marked_content(content, offsets) if offsets is not None else escape(content, quote=False)


def find_chapter(chapters: dict[str, str], number: int) -> tuple[str, str] | None:
    return next(((key, value) for key, value in chapters.items() if key.isdecimal() and int(key) == number), None)


@get("/api/{translation:str}/books/{book_title:str}", sync_to_thread=True)
def get_book(translation: str, book_title: str) -> dict[str, Any]:
    book_id, book, verse_map = find_book(translation, book_title)
    chapters = {
        str(int(number)): chapter_content(number, content, verse_map)
        for number, content in book["chapters"].items()
        if number.isdecimal()
    }
    return {"translation": "svd", "bookId": book_id, "bookName": book["name"], "chapters": chapters}


@get("/api/{translation:str}/books/{book_title:str}/chapters/{chapter:int}", sync_to_thread=True)
def get_chapter(translation: str, book_title: str, chapter: int) -> dict[str, Any]:
    book_id, book, verse_map = find_book(translation, book_title)
    found = find_chapter(book["chapters"], chapter)
    if chapter < 1 or found is None:
        raise NotFoundException("Chapter not found.")

    chapter_key, content = found
    return {
        "translation": "svd",
        "bookId": book_id,
        "bookName": book["name"],
        "chapter": chapter,
        "content": chapter_content(chapter_key, content, verse_map),
    }


app = Litestar(
    route_handlers=[get_book, get_chapter],
    cors_config=CORSConfig(allow_origins=["*"], allow_methods=["GET"]),
)
