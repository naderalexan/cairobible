const CACHE_NAME = "cairo-bible-shell-v4";
const APP_SHELL = ["/", "/manifest.webmanifest", "/icons/cairo-bible.svg", "/fonts/montserrat-latin.woff2", "/fonts/yellowtail-latin.woff2"];

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(APP_SHELL.slice(1));
    const response = await fetch("/");
    if (!response.ok) throw new Error("Could not cache the reader shell.");
    await cache.put("/", response.clone());
    try {
      const dataResponse = await fetch("/data/arb-vd.json");
      if (dataResponse.ok) await cache.put("/data/arb-vd.json", dataResponse);
    } catch { /* The data will be cached on its first successful request. */ }
    const html = await response.text();
    const assets = [...html.matchAll(/(?:src|href)=["']([^"']*\/_next\/static\/[^"']+)["']/g)]
      .map((match) => new URL(match[1], self.location.origin).href);
    await Promise.all(assets.map(async (asset) => {
      try {
        const assetResponse = await fetch(asset);
        if (assetResponse.ok) await cache.put(asset, assetResponse);
      } catch { /* The asset will be cached on its first successful request. */ }
    }));
  })());
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) => Promise.all(names.filter((name) => (name.startsWith("cairo-bible-shell-") || name.startsWith("still-niv-shell-") || name.startsWith("still-bible-shell-")) && name !== CACHE_NAME).map((name) => caches.delete(name)))),
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;

  if (url.pathname === "/data/arb-vd.json") {
    event.respondWith(
      caches.open(CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(request);
        if (cached) return cached;
        const response = await fetch(request);
        if (response.ok) await cache.put(request, response.clone());
        return response;
      }),
    );
    return;
  }

  if (url.pathname.startsWith("/_next/static/")) {
    event.respondWith(
      caches.open(CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(request);
        if (cached) return cached;
        const response = await fetch(request);
        if (response.ok) await cache.put(request, response.clone());
        return response;
      }),
    );
    return;
  }

  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then(async (response) => {
          if (response.ok) await (await caches.open(CACHE_NAME)).put("/", response.clone());
          return response;
        })
        .catch(async () => (await (await caches.open(CACHE_NAME)).match("/")) ?? Response.error()),
    );
  }
});
