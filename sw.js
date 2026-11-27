// Cache hors ligne : l'appli s'ouvre sans réseau. Changer VERSION à chaque mise à jour des fichiers.
const VERSION = 'planning-service-v8';
const FILES = ['./', './index.html', './manifest.webmanifest', './icon.svg', './icon-192.png', './icon-512.png', './apple-touch-icon.png',
  './supabase.js'];
const CDN = ['fonts.googleapis.com', 'fonts.gstatic.com'];
self.addEventListener('install', e => { e.waitUntil(caches.open(VERSION).then(c => c.addAll(FILES)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== VERSION).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET') return;
  const same = u.origin === location.origin;
  if (!same && !CDN.includes(u.hostname)) return; // API Supabase : jamais en cache
  if (same) {
    // Réseau d'abord pour l'appli (mises à jour immédiates), cache si hors ligne
    e.respondWith(fetch(e.request).then(res => { if (res.ok) { const cp = res.clone(); caches.open(VERSION).then(c => c.put(e.request, cp)); } return res; })
      .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html'))));
  } else {
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => { const cp = res.clone(); caches.open(VERSION).then(c => c.put(e.request, cp)); return res; })));
  }
});
