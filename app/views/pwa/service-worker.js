const CACHE = "fpt-shell-v2"
const SHELL = [
  "/", "/menu", "/exchanges", "/supplements", "/checklist", "/progress",
  "/manifest.json",
  "/icon.svg", "/icon.png", "/icon-192.png", "/icon-maskable.png", "/apple-touch-icon.png", "/favicon.ico"
]

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL).catch(() => null)))
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) => Promise.all(names.filter((n) => n !== CACHE).map((n) => caches.delete(n))))
  )
  self.clients.claim()
})

// Network-first for HTML; cache fallback for offline. Pass-through for everything else.
self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET") return
  const accept = request.headers.get("accept") || ""
  if (!accept.includes("text/html")) return

  event.respondWith(
    fetch(request)
      .then((response) => {
        const copy = response.clone()
        caches.open(CACHE).then((cache) => cache.put(request, copy).catch(() => null))
        return response
      })
      .catch(() => caches.match(request).then((hit) => hit || caches.match("/")))
  )
})

// Web Push: payload is JSON { title, body, url? } from PushNotifier.
self.addEventListener("push", (event) => {
  let data = {}
  try { data = event.data ? event.data.json() : {} } catch { data = {} }

  const title = data.title || "Food Plan Tracker"
  const options = {
    body: data.body || "",
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    data: { url: data.url || "/" }
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

// Tapping a notification opens (or focuses) the URL the server sent.
self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const target = event.notification.data?.url || "/"

  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: "window", includeUncontrolled: true })
    const same = all.find((c) => new URL(c.url).pathname === target)
    if (same) return same.focus()
    return self.clients.openWindow(target)
  })())
})
