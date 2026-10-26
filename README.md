# Still — NIV Bible

A focused, installable Next.js Bible reader with quick book/chapter navigation, saved reading preferences, and IndexedDB chapter storage for offline use.

## NIV content

The app does not bundle NIV text. Connect an API.Bible key for an account that includes NIV access. The browser sends that key directly to API.Bible and stores it only in this browser's local storage; do not use this setup for shared or public devices. The app displays the copyright statement returned with the NIV metadata when available.

API.Bible requires licensed translations and appropriate attribution. Its caching guidance requires Scripture content to be refreshed at least every 30 days. This app refreshes saved chapters after 29 days; it does not provide permanent offline NIV storage. For a deployment or use case requiring a different caching term, obtain the relevant rights and follow the publisher's license.

## Run locally

```sh
npm install
npm run dev
```

Open <http://localhost:3000>, choose **Settings**, and connect an API.Bible key with NIV enabled. The app is configured for static export (`npm run build` creates `out/`) and can be hosted on any static HTTPS host. A service worker caches the app shell and Next.js static assets; Scripture chapters are cached separately in IndexedDB for up to 29 days.

## Offline use

Open a chapter online to save it automatically. **Save the whole NIV offline** in Settings can fill the cache chapter by chapter; it resumes by skipping chapters already fresh in the cache. The download can be paused. A full download makes many API requests and is subject to your API.Bible account's rate limits and license. Open the app online at least once after a deployment so the service worker can cache the shell.
