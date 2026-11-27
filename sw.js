// Cache hors ligne : l'appli s'ouvre sans réseau. Changer VERSION à chaque mise à jour des fichiers.
const VERSION = 'planning-service-v26';
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
    e.respondWith(fetch(u.href, { cache: 'no-cache', credentials: 'same-origin' }).then(res => { if (res.ok) { const cp = res.clone(); caches.open(VERSION).then(c => c.put(e.request, cp)); } return res; })
      .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html'))));
  } else {
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => { const cp = res.clone(); caches.open(VERSION).then(c => c.put(e.request, cp)); return res; })));
  }
});

// Notifications de rappel (envoyées par la fonction Supabase « rappels »)
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { body: e.data ? e.data.text() : '' }; }
  e.waitUntil(self.registration.showNotification(d.title || 'Planning de service', {
    body: d.body || 'Pensez à compléter votre planning.', icon: './icon-192.png', badge: './icon-192.png', tag: /echange/.test(d.url || '') ? 'echange' : 'rappel-planning', renotify: true, data: { url: d.url || './' }
  }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(l => {
    const u = e.notification.data && e.notification.data.url || './';
    for (const c of l) if ('focus' in c) { if (/echanges/.test(u)) c.postMessage('echanges'); return c.focus(); }
    return clients.openWindow(e.notification.data && e.notification.data.url || './');
  }));
});
