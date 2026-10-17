// Service worker khusus notifikasi pengingat harian (Web Push).
//
// Didaftarkan dengan scope sendiri ("pawai-push/") oleh pawai_push.js agar
// tidak bentrok dengan service worker bawaan Flutter (scope "/"). Tidak
// meng-cache apa pun; hanya menampilkan notifikasi dan membuka aplikasi
// saat notifikasi diketuk.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }
  event.waitUntil(
    self.registration.showNotification(data.title || 'Pawai', {
      body: data.body || '',
      tag: data.tag || 'pawai',
      icon: 'icons/Icon-192.png',
      data: { url: data.url || '/' },
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL((event.notification.data && event.notification.data.url) || '/', self.location.origin).href;
  event.waitUntil(
    (async () => {
      // Aplikasi sudah terbuka: cukup tampilkan ke depan.
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of windows) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow(url);
    })()
  );
});
