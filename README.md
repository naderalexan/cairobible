# Cairo Bible

A warm, installable Bible reader with Arabic Smith & Van Dyck (SVD), NIV support gated on API.Bible licensing, quick book/chapter navigation, five color palettes, saved reading preferences, and offline SVD reading. The Cairo Bible wordmark uses locally bundled Montserrat and Yellowtail fonts; their licenses are included in `public/fonts/`. The logo mark and installable app icons are in `public/icons/`.

## Arabic Smith & Van Dyck (SVD)

The Litestar API serves the Arabic Van Dyck Bible from `public/data/arb-vd.json` and preserves verse markers from `public/data/arb-vd-verses.json`. The app fetches chapters from that API and uses its locally cached corpus when the browser is offline.

Source: [eBible.org Arabic Van Dyck Bible](https://ebible.org/Scriptures/details.php?id=arb-vd), downloaded from the [read-aloud text archive](https://ebible.org/Scriptures/arb-vd_readaloud.zip). eBible.org lists this translation as public domain; the source credits the Syrian Mission and American Bible Society.

## NIV content

The app does not bundle NIV text. The Litestar backend reads `API_BIBLE_KEY`; the key is never sent to the browser. Full-corpus caching and NIV reader responses stay disabled unless `NIV_CORPUS_LICENSE_CONFIRMED=true` is set on the backend. Set that variable only after written permission confirms full-corpus storage, a 29-day refresh interval, reader distribution, and API.Bible's required web view tracking. The backend stores the corpus in `var/niv-corpus.json` by default; set `NIV_CORPUS_PATH` to choose another persistent location.

API.Bible's current FAQ asks that cached content stay below 500 consecutive verses and recommends clearing caches within 14 days. Those general terms do not confirm the full-corpus, 29-day use in this feature. Until the needed permission is confirmed, leave the license variable unset; the NIV API returns `503` and makes no upstream requests. NIV is served only from the backend cache after the gate is enabled, and responses include API.Bible copyright information.

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

Open <http://localhost:3000> and choose **Settings** to select one of five color palettes. The app is configured for static export (`npm run build` creates `out/`); set `NEXT_PUBLIC_BIBLE_API_URL` at build time to the deployed Litestar API URL, or route `/api` to the backend on the reader's origin. A service worker caches the app shell, SVD corpus, verse boundaries, and Next.js static assets. NIV is not cached in the browser.

## Native iOS reader

Open `ios/CairoBible/CairoBible.xcodeproj` in Xcode and run the shared **CairoBible** scheme on an iOS simulator. The app supports iOS 17 and later and reads NIV chapters from the Litestar backend; the `BIBLE_API_BASE_URL` build setting defaults to `https://api.bible.cairolove.site` and can point to a local backend during development. API.Bible credentials and requests stay on the backend. The server's NIV license gate still controls chapter availability.

The **iOS** GitHub Actions workflow builds the app and runs its controlled-response reader tests on an iOS simulator whenever the native app changes.

## Production deployment

The frontend deploys to Cloudflare Workers on pushes to `main` and uses `https://api.bible.cairolove.site` for Bible API requests. The backend deploys to a DigitalOcean Droplet from `.github/workflows/deploy-backend.yml`; that workflow maintains the Cloudflare DNS A record and the route in the Droplet's existing Caddy service.

Before the first backend deployment, the Droplet needs Docker Engine with the Compose plugin, `rsync`, an active Caddy service, a Linux user allowed to run Docker and reload Caddy, and inbound TCP ports 22, 80, and 443. Add these GitHub repository secrets:

- `DIGITALOCEAN_API_TOKEN`: read access to the Droplet.
- `DIGITALOCEAN_DROPLET_ID`: the Droplet ID.
- `DROPLET_SSH_PRIVATE_KEY`: private key whose public key is authorized for the deployment user.
- `DROPLET_SSH_KNOWN_HOSTS`: the verified SSH host key line for the Droplet IPv4 address.
- `CLOUDFLARE_DNS_API_TOKEN`: `Zone:Read`, `DNS:Read`, and `DNS:Write` access for `cairolove.site`.

The optional repository variable `DROPLET_SSH_USER` selects the SSH user; it defaults to `root`. The DNS record is DNS-only so Caddy can obtain and renew the HTTPS certificate. The deployment keeps the backend's `var/` directory on the Droplet between releases. NIV stays disabled unless its license gate is deliberately configured on the Droplet.

## Offline use

SVD chapters remain available offline after the app shell and corpus have been cached. NIV requires an online backend and remains unavailable while its full-corpus license gate is off. Open the app online at least once after a deployment so the service worker can cache the shell.
