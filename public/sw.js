/* Performance — service worker.
   Opens INSTANTLY: the app is always served from the copy saved on the device,
   and a fresh copy is fetched in the background for the next opening.
   Bump CACHE when files are added to SHELL. */
const CACHE = 'perf-v2';
const SHELL = [
  './', './index.html', './styles.css', './app.js', './logic.js', './quotes.js', './holidays.js', './cloud.js', './config.js',
  './manifest.json', './icons/icon.svg', './icons/icon-192.png', './icons/icon-512.png', './icons/apple-touch-icon.png',
];
// Libraries and fonts never change at a given address, so a saved copy is always right.
const FOREVER = ['https://esm.sh', 'https://fonts.googleapis.com', 'https://fonts.gstatic.com'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (FOREVER.some((o) => req.url.startsWith(o))) {
    e.respondWith(caches.match(req).then((hit) => hit || fetch(req).then((res) => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
      return res;
    })));
    return;
  }
  // Supabase and the calendar function are live data: never cached here.
  if (url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;

  // The app itself: answer from the saved copy right away, refresh it in the background.
  const key = req.mode === 'navigate' ? './index.html' : req;
  e.respondWith(caches.open(CACHE).then(async (c) => {
    const hit = await c.match(key, { ignoreSearch: true });
    const fresh = fetch(req).then((res) => { if (res.ok) c.put(key, res.clone()); return res; }).catch(() => hit);
    if (hit) { e.waitUntil(fresh); return hit; }
    return fresh;
  }));
});
