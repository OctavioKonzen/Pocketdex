// Service worker do PocketDex: deixa o site instalável e abrindo sem internet.
//
// Sempre tenta a rede primeiro (assim uma versão nova do site aparece na hora)
// e só usa a cópia guardada quando está sem conexão. Nada de outros domínios
// (Firebase, Google) passa por aqui.

const CACHE = 'pocketdex-v1'

self.addEventListener('install', () => self.skipWaiting())

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', (event) => {
  const request = event.request
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return

  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.status === 200 && response.type === 'basic') {
          const copy = response.clone()
          caches.open(CACHE).then((cache) => cache.put(request, copy))
        }
        return response
      })
      .catch(async () => {
        const cached = await caches.match(request)
        if (cached) return cached
        // Sem internet e página nunca aberta: mostra a página inicial guardada.
        if (request.mode === 'navigate') {
          const home = await caches.match(new URL('./', self.registration.scope).href)
          if (home) return home
        }
        return Response.error()
      }),
  )
})
