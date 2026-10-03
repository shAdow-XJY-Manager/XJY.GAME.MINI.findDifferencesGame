const prefix='manager-arcade-'+new URL(self.registration.scope).pathname;
const cacheName=prefix+'20261003-d';
self.addEventListener('install',event=>event.waitUntil((async()=>{
  const cache=await caches.open(cacheName);
  await cache.addAll(['./','game-platform.js','game-offline.js','flutter_bootstrap.js','main.dart.js'].map(path=>new Request(new URL(path,self.registration.scope),{cache:'reload'})));
  await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const name of await caches.keys())if(name.startsWith(prefix)&&name!==cacheName)await caches.delete(name);
  await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  event.respondWith((async()=>{
    const cache=await caches.open(cacheName);
    try {
      const response=await fetch(request,{cache:'no-cache'});
      if(response.ok||response.type==='opaque')await cache.put(request,response.clone()).catch(()=>{});
      return response;
    }catch(error) {
      const cached=await cache.match(request);
      if(cached)return cached;
      if(request.mode==='navigate') {
        const shell=await cache.match(new URL('./',self.registration.scope));if(shell)return shell;
      }
      throw error;
    }
  })());
});
