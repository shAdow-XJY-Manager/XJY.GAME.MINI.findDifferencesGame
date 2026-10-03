(() => {
  let suspend = null, audio = null;
  const stop = () => { if (suspend) suspend(); if (audio) audio.suspend().catch(() => {}); };
  addEventListener('blur', stop);
  document.addEventListener('visibilitychange', () => { if (document.hidden) stop(); });
  window.managerArcade = {
    read(key) { try { return localStorage.getItem(key); } catch (_) { return null; } },
    write(key, value) { try { localStorage.setItem(key, value); return true; } catch (_) { return false; } },
    reduced() { return matchMedia('(prefers-reduced-motion: reduce)').matches; },
    watch(callback) { suspend = callback; }, unwatch() { suspend = null; },
    asset(path) { return new URL(path, document.baseURI).href; },
    tone(kind) {
      if (document.hidden) return;
      const Audio = window.AudioContext || window.webkitAudioContext;
      if (!Audio) return;
      audio ||= new Audio();
      audio.resume().catch(() => {});
      const notes = {collect:[660,880],jump:[330,520],fail:[180,90],win:[440,660,880],tap:[440]};
      (notes[kind] || notes.tap).forEach((f,i) => {
        const o=audio.createOscillator(), g=audio.createGain(), t=audio.currentTime+i*.075;
        o.type='sine'; o.frequency.setValueAtTime(f,t); g.gain.setValueAtTime(.0001,t);
        g.gain.exponentialRampToValueAtTime(.075,t+.01);
        g.gain.exponentialRampToValueAtTime(.0001,t+.14);
        o.connect(g);g.connect(audio.destination);o.start(t);o.stop(t+.15);
        o.onended=()=>{o.disconnect();g.disconnect();};
      });
    }
  };
})();
