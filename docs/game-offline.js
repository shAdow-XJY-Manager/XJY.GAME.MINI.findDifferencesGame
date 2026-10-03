(() => {
  const status=document.createElement('div');
  status.textContent='正在接通信号…';
  status.setAttribute('role','status');
  status.style.cssText='position:fixed;inset:0;display:grid;place-items:center;background:#111315;color:#f4f2e9;font:16px sans-serif;';
  document.body.append(status);
  addEventListener('flutter-first-frame',()=>status.remove(),{once:true});
  function start() {
    const script=document.createElement('script');
    script.src=new URL('flutter_bootstrap.js',document.baseURI).href;
    script.onerror=()=>{
      status.textContent='游戏暂时无法载入。请联网后重试。';
      const button=document.createElement('button');button.textContent='重试加载';button.onclick=()=>location.reload();
      button.style.cssText='min-height:48px;padding:12px 24px;background:#d6ef36;color:#111315;border:0;border-radius:8px;';
      status.append(button);
    };
    document.body.append(script);
  }
  (async()=>{
    if('serviceWorker' in navigator) {
      try {
        await navigator.serviceWorker.register(new URL('game-sw.js',document.baseURI),{scope:new URL('./',document.baseURI).pathname,updateViaCache:'none'});
        await Promise.race([navigator.serviceWorker.ready,new Promise(r=>setTimeout(r,1800))]);
        if(!navigator.serviceWorker.controller) await new Promise(r=>{
          navigator.serviceWorker.addEventListener('controllerchange',r,{once:true});setTimeout(r,1200);
        });
      }catch(_){}
    }
    start();
  })();
})();
