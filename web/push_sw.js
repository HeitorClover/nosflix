// Service worker só para notificações push (o Flutter usa o dele, em outro escopo).

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {}

  const options = {
    body: data.body || '',
    icon: data.icon || '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { url: data.url || '/' },
    tag: data.tag,
  };
  if (data.image) options.image = data.image;

  event.waitUntil(self.registration.showNotification(data.title || 'Nosflix', options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const w of windows) {
        if ('focus' in w) return w.focus();
      }
      return self.clients.openWindow(url);
    })
  );
});
