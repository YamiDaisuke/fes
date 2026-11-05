const version = "56bc3ff4c3df6eb5";
const files = ["./", "boot.js", "App.wasm", "manifest.webmanifest", "icons/icon-180.png", "icons/icon-512.png"];
const cachePrefix = `fes ${self.registration.scope} `;
const cacheName = cachePrefix + version;
const precachedURLs = new Set(files.map((file) => new URL(file, self.registration.scope).href));

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(cacheName);
      // GitHub Pages sends max-age=600, so the HTTP cache could hand a new worker an old App.wasm next to a new boot.js.
      await cache.addAll(files.map((file) => new Request(file, { cache: "reload" })));
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key.startsWith(cachePrefix) && key !== cacheName) await caches.delete(key);
      }
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  url.search = "";
  url.hash = "";
  if (request.method !== "GET" || !precachedURLs.has(url.href)) return;
  if (request.mode === "navigate") event.waitUntil(forgetIfUnpublished());
  event.respondWith(caches.match(request, { cacheName, ignoreSearch: true }).then((cached) => cached ?? fetch(request)));
});

async function forgetIfUnpublished() {
  let response;
  try {
    response = await fetch("sw.js", { cache: "no-store" });
  } catch {
    return;
  }
  if (response.status !== 404) return;
  for (const key of await caches.keys()) {
    if (key.startsWith(cachePrefix)) await caches.delete(key);
  }
  await self.registration.unregister();
}
