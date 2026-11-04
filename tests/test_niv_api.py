import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from litestar.testing import TestClient

from bible import app
from bible.niv import NIV_BIBLE_ID


class NivApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.cache_path = Path(self.temp_dir.name) / "niv.json"
        self.env = patch.dict(
            os.environ,
            {
                "API_BIBLE_KEY": "test-key",
                "NIV_CORPUS_PATH": str(self.cache_path),
                "NIV_CORPUS_LICENSE_CONFIRMED": "true",
            },
        )
        self.env.start()
        self.addCleanup(self.env.stop)
        self.addCleanup(self.temp_dir.cleanup)

    @staticmethod
    def upstream(path: str) -> dict:
        if path == f"/bibles/{NIV_BIBLE_ID}":
            return {"data": {"name": "New International Version", "copyright": "NIV copyright"}}
        if path == f"/bibles/{NIV_BIBLE_ID}/books?include-chapters=true":
            return {
                "data": [
                    {
                        "id": "GEN",
                        "name": "Genesis",
                        "chapters": [{"id": "GEN.1", "number": "1"}],
                    }
                ]
            }
        if path.startswith(f"/bibles/{NIV_BIBLE_ID}/chapters/GEN.1?"):
            return {
                "data": {"content": "<p>In the beginning</p>", "copyright": "Chapter copyright"},
                "meta": {"fumsToken": "chapter-token"},
            }
        raise AssertionError(f"Unexpected API.Bible path: {path}")

    def test_initial_request_syncs_and_returns_niv_copyright(self) -> None:
        with patch("bible.niv.fetch_api_bible", side_effect=self.upstream) as upstream:
            with TestClient(app=app) as client:
                book = client.get("/api/niv/books/Genesis")
                chapter = client.get("/api/niv/books/GEN/chapters/1")

        self.assertEqual(book.status_code, 200)
        self.assertEqual(book.json()["copyright"], "NIV copyright")
        self.assertEqual(book.json()["fumsTokens"], {"1": "chapter-token"})
        self.assertIn("In the beginning", book.json()["chapters"]["1"])
        self.assertEqual(chapter.status_code, 200)
        self.assertEqual(chapter.json()["copyright"], "Chapter copyright")
        self.assertEqual(chapter.json()["fumsToken"], "chapter-token")
        self.assertEqual(chapter.json()["content"], "<p>In the beginning</p>")
        self.assertEqual(upstream.call_count, 3)
        self.assertTrue(self.cache_path.exists())

    def test_stale_corpus_refresh_replaces_the_complete_copy(self) -> None:
        with patch("bible.niv.fetch_api_bible", side_effect=self.upstream):
            with TestClient(app=app) as client:
                self.assertEqual(client.get("/api/niv/books/GEN/chapters/1").json()["content"], "<p>In the beginning</p>")

        corpus = json.loads(self.cache_path.read_text())
        corpus["fetchedAt"] = 0
        self.cache_path.write_text(json.dumps(corpus))

        def refreshed(path: str) -> dict:
            result = self.upstream(path)
            if path.startswith("/bibles/") and "/chapters/GEN.1?" in path:
                result["data"]["content"] = "<p>In the beginning again</p>"
            return result

        with patch("bible.niv.fetch_api_bible", side_effect=refreshed) as upstream:
            with TestClient(app=app) as client:
                response = client.get("/api/niv/books/GEN/chapters/1")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["content"], "<p>In the beginning again</p>")
        self.assertEqual(upstream.call_count, 3)
        self.assertIn("In the beginning again", self.cache_path.read_text())

    def test_unknown_book_and_chapter_return_not_found(self) -> None:
        with patch("bible.niv.fetch_api_bible", side_effect=self.upstream):
            with TestClient(app=app) as client:
                unknown_book = client.get("/api/niv/books/Not%20a%20book")
                unknown_chapter = client.get("/api/niv/books/Genesis/chapters/2")

        self.assertEqual(unknown_book.status_code, 404)
        self.assertEqual(unknown_chapter.status_code, 404)

    def test_failed_refresh_keeps_and_serves_the_last_complete_copy(self) -> None:
        with patch("bible.niv.fetch_api_bible", side_effect=self.upstream):
            with TestClient(app=app) as client:
                client.get("/api/niv/books/GEN/chapters/1")

        corpus = json.loads(self.cache_path.read_text())
        corpus["fetchedAt"] = 0
        self.cache_path.write_text(json.dumps(corpus))
        previous_copy = self.cache_path.read_bytes()

        def fail_during_chapters(path: str) -> dict:
            if "/chapters/GEN.1?" in path:
                raise RuntimeError("upstream unavailable")
            return self.upstream(path)

        with patch("bible.niv.fetch_api_bible", side_effect=fail_during_chapters):
            with TestClient(app=app) as client:
                response = client.get("/api/niv/books/GEN/chapters/1")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["content"], "<p>In the beginning</p>")
        self.assertEqual(self.cache_path.read_bytes(), previous_copy)

    def test_corpus_is_unavailable_without_license_confirmation(self) -> None:
        self.cache_path.write_text(
            json.dumps({
                "fetchedAt": 1_800_000_000,
                "copyright": "NIV copyright",
                "books": {"GEN": {"name": "Genesis", "chapters": {"1": {"content": "cached NIV", "copyright": "NIV copyright"}}}},
            })
        )
        os.environ.pop("NIV_CORPUS_LICENSE_CONFIRMED")
        with patch("bible.niv.fetch_api_bible") as upstream:
            with TestClient(app=app) as client:
                response = client.get("/api/niv/books/GEN/chapters/1")

        self.assertEqual(response.status_code, 503)
        upstream.assert_not_called()


if __name__ == "__main__":
    unittest.main()
