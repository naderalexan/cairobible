import json
import re
import unittest
from html import unescape
from pathlib import Path
from urllib.parse import quote

from litestar.testing import TestClient

from bible import app


CORPUS = json.loads((Path(__file__).parents[1] / "public/data/arb-vd.json").read_text())
VERSE_MAP = json.loads((Path(__file__).parents[1] / "public/data/arb-vd-verses.json").read_text())


class SvdApiTests(unittest.TestCase):
    def test_get_book_returns_every_chapter_with_verse_markers(self) -> None:
        with TestClient(app=app) as client:
            response = client.get(f"/api/svd/books/{quote('التكوين')}")

        self.assertEqual(response.status_code, 200)
        book = response.json()
        self.assertEqual(book["bookId"], "GEN")
        self.assertEqual(len(book["chapters"]), 50)
        self.assertIn("<span data-number=\"1\">1</span>", book["chapters"]["1"])
        self.assertEqual(
            unescape(re.sub(r'<span data-number="\d+">\d+</span>', "", book["chapters"]["1"])),
            CORPUS["books"]["GEN"]["chapters"]["01"],
        )

    def test_get_chapter_returns_source_text_and_verse_markers(self) -> None:
        with TestClient(app=app) as client:
            response = client.get("/api/svd/books/GEN/chapters/1")

        self.assertEqual(response.status_code, 200)
        chapter = response.json()
        source = CORPUS["books"]["GEN"]["chapters"]["01"]
        self.assertEqual(chapter["bookId"], "GEN")
        self.assertEqual(chapter["chapter"], 1)
        self.assertIn("فِي ٱلْبَدْءِ", chapter["content"])
        self.assertIn("<span data-number=\"1\">1</span>", chapter["content"])
        self.assertEqual(
            len(re.findall(r'<span data-number="\d+">\d+</span>', chapter["content"])),
            len(VERSE_MAP["books"]["GEN"]["01"]),
        )
        self.assertEqual(
            unescape(re.sub(r'<span data-number="\d+">\d+</span>', "", chapter["content"])),
            source,
        )

    def test_invalid_book_and_chapter_return_not_found(self) -> None:
        with TestClient(app=app) as client:
            invalid_book = client.get("/api/svd/books/Not%20a%20book")
            invalid_chapter = client.get(f"/api/svd/books/{quote('التكوين')}/chapters/51")
            zero_chapter = client.get(f"/api/svd/books/{quote('التكوين')}/chapters/0")

        self.assertEqual(invalid_book.status_code, 404)
        self.assertEqual(invalid_chapter.status_code, 404)
        self.assertEqual(zero_chapter.status_code, 404)

    def test_unsupported_translation_returns_not_found(self) -> None:
        with TestClient(app=app) as client:
            response = client.get(f"/api/kjv/books/{quote('التكوين')}")

        self.assertEqual(response.status_code, 404)


if __name__ == "__main__":
    unittest.main()
