#!/usr/bin/env python3
"""Populate var/niv-corpus.json through the backend's normal refresh path."""

import os
import sys
from getpass import getpass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from bible.niv import corpus_path, get_corpus  # noqa: E402


if not os.environ.get("API_BIBLE_KEY", "").strip():
    api_key = getpass("API.Bible API key: ").strip()
    if not api_key:
        raise SystemExit("An API.Bible API key is required.")
    os.environ["API_BIBLE_KEY"] = api_key

# This enables only this one local import process; it does not change the server.
os.environ["NIV_CORPUS_LICENSE_CONFIRMED"] = "true"
corpus = get_corpus()
chapter_count = sum(len(book["chapters"]) for book in corpus["books"].values())
print(f"Cached {len(corpus['books'])} books and {chapter_count} chapters in {corpus_path()}.")
