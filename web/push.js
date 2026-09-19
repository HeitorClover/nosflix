// Ponte entre o app Flutter e o Web Push do navegador.
(function () {
  function urlBase64ToUint8Array(base64) {
    const padding = '='.repeat((4 - (base64.length % 4)) % 4);
    const raw = atob((base64 + padding).replace(/-/g, '+').replace(/_/g, '/'));
    const out = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out;
  }

  function whenActive(reg) {
    if (reg.active) return Promise.resolve(reg);
    const worker = reg.installing || reg.waiting;
    return new Promise((resolve) => {
      worker.addEventListener('statechange', () => {
        if (worker.state === 'activated') resolve(reg);
      });
    });
  }

  window.nosflixPush = {
    supported: function () {
      return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
    },

    // iPhone/iPad no Safari comum: o push só existe se o site for instalado
    // na Tela de Início e aberto por esse ícone.
    needsInstall: function () {
      const ua = navigator.userAgent || '';
      const isIos = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
      return isIos && !navigator.standalone && !this.supported();
    },

    permission: function () {
      return 'Notification' in window ? Notification.permission : 'denied';
    },

    // Devolve o JSON da inscrição (string) ou null se não houver permissão.
    // Com prompt=true pede permissão (precisa vir de um toque do usuário).
    subscribe: async function (vapidKey, prompt) {
      if (!this.supported()) return null;

      // O pedido de permissão vem primeiro, sem nenhum await antes, para
      // continuar valendo como resposta a um toque do usuário.
      let permission = Notification.permission;
      if (permission === 'default' && prompt) {
        permission = await Notification.requestPermission();
      }
      if (permission !== 'granted') return null;

      const reg = await whenActive(
        await navigator.serviceWorker.register('/push_sw.js', { scope: '/push-scope/' })
      );
      let sub = await reg.pushManager.getSubscription();
      if (!sub) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(vapidKey),
        });
      }
      return JSON.stringify(sub.toJSON());
    },
  };
})();
