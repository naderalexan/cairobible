# Cairo Bible

A warm, installable Next.js Bible reader with NIV and Arabic Smith & Van Dyck (SVD), quick book/chapter navigation, five color palettes, saved reading preferences, and offline reading. The Cairo Bible wordmark uses locally bundled Montserrat and Yellowtail fonts; their licenses are included in `public/fonts/`.

## Arabic Smith & Van Dyck (SVD)

The Litestar API serves the Arabic Van Dyck Bible from `public/data/arb-vd.json` and preserves verse markers from `public/data/arb-vd-verses.json`. The app fetches chapters from that API and uses its locally cached corpus when the browser is offline.

Source: [eBible.org Arabic Van Dyck Bible](https://ebible.org/Scriptures/details.php?id=arb-vd), downloaded from the [read-aloud text archive](https://ebible.org/Scriptures/arb-vd_readaloud.zip). eBible.org lists this translation as public domain; the source credits the Syrian Mission and American Bible Society.

## NIV content

The app does not bundle NIV text. Connect an API.Bible key for an account that includes NIV access. The browser sends that key directly to API.Bible and stores it only in this browser's local storage; do not use this setup for shared or public devices. The app displays the copyright statement returned with the NIV metadata when available.

API.Bible requires licensed translations and appropriate attribution. Its caching guidance requires Scripture content to be refreshed at least every 30 days. This app refreshes saved chapters after 29 days; it does not provide permanent offline NIV storage. For a deployment or use case requiring a different caching term, obtain the relevant rights and follow the publisher's license.

## Run locally

```sh
npm install
```

Start the Litestar API in one terminal:

```sh
uv run litestar --app-dir src --app bible:app run --host 127.0.0.1 --port 8000
```

Start the reader in another terminal:

```sh
NEXT_PUBLIC_BIBLE_API_URL=http://localhost:8000 npm run dev
```

Open <http://localhost:3000>, choose **Settings** to select one of five color palettes or connect an API.Bible key with NIV enabled. The app is configured for static export (`npm run build` creates `out/`); set `NEXT_PUBLIC_BIBLE_API_URL` at build time to the deployed Litestar API URL, or route `/api` to the backend on the reader's origin. A service worker caches the app shell, SVD corpus, verse boundaries, and Next.js static assets; NIV chapters are cached separately in IndexedDB for up to 29 days.

## Offline use

Open a chapter online to save it automatically. **Save the whole NIV offline** in Settings can fill the cache chapter by chapter; it resumes by skipping chapters already fresh in the cache. The download can be paused. A full download makes many API requests and is subject to your API.Bible account's rate limits and license. Open the app online at least once after a deployment so the service worker can cache the shell.
