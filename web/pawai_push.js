// Notifikasi pengingat harian (Web Push) untuk Pawai.
//
// Dipanggil dari Flutter (lib/core/services/push/web_push_service.dart).
// Semua fungsi mengembalikan Promise berisi string JSON dan tidak pernah
// reject; kegagalan dikirim sebagai { "error": "..." }.
(function () {
  'use strict';

  var SW_URL = 'pawai-push-sw.js';
  // Scope sendiri agar tidak bentrok dengan service worker bawaan Flutter (scope "/").
  var SW_SCOPE = 'pawai-push/';

  function scopeUrl() {
    return new URL(SW_SCOPE, document.baseURI).href;
  }

  function supported() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }

  function isIos() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  }

  function isStandalone() {
    return window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  }

  function toBase64Url(buffer) {
    var bytes = new Uint8Array(buffer);
    var binary = '';
    for (var i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function fromBase64Url(value) {
    var base64 = (value + '='.repeat((4 - (value.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/');
    var binary = atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  }

  /** Kunci server (VAPID) yang dipakai langganan ini, atau null bila tidak diketahui. */
  function serverKeyOf(subscription) {
    var key = subscription.options && subscription.options.applicationServerKey;
    return key ? toBase64Url(key) : null;
  }

  function errorJson(e) {
    return JSON.stringify({ error: String((e && e.message) || e) });
  }

  async function currentSubscription() {
    var registration = await navigator.serviceWorker.getRegistration(scopeUrl());
    return registration ? registration.pushManager.getSubscription() : null;
  }

  /** Daftarkan service worker lalu tunggu sampai aktif (scope-nya tidak mengontrol halaman ini). */
  async function activeRegistration() {
    var registration = await navigator.serviceWorker.register(SW_URL, { scope: SW_SCOPE });
    var worker = registration.installing || registration.waiting;
    if (!registration.active && worker) {
      await new Promise(function (resolve) {
        if (worker.state === 'activated') return resolve();
        worker.addEventListener('statechange', function () {
          if (worker.state === 'activated') resolve();
        });
      });
    }
    return registration;
  }

  async function info() {
    var result = {
      supported: supported(),
      ios: isIos(),
      standalone: isStandalone(),
      permission: 'Notification' in window ? Notification.permission : 'unsupported',
      subscription: null,
      serverKey: null,
    };
    if (!result.supported) return JSON.stringify(result);
    try {
      var subscription = await currentSubscription();
      if (subscription) {
        result.subscription = subscription.toJSON();
        result.serverKey = serverKeyOf(subscription);
      }
    } catch (e) {
      result.error = String((e && e.message) || e);
    }
    return JSON.stringify(result);
  }

  /**
   * Minta izin notifikasi (bila belum) lalu berlangganan dengan kunci server.
   * Harus dipanggil langsung dari ketukan pengguna: iPhone menolak permintaan
   * izin yang tidak berasal dari ketukan.
   */
  async function subscribe(publicKey) {
    try {
      if (!supported()) return JSON.stringify({ error: 'unsupported' });
      var permission = Notification.permission;
      if (permission === 'default') permission = await Notification.requestPermission();
      if (permission !== 'granted') return JSON.stringify({ error: 'denied' });

      var registration = await activeRegistration();
      var subscription = await registration.pushManager.getSubscription();
      // Langganan lama dengan kunci server berbeda tidak bisa dipakai lagi.
      if (subscription && serverKeyOf(subscription) !== publicKey) {
        await subscription.unsubscribe();
        subscription = null;
      }
      if (!subscription) {
        subscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: fromBase64Url(publicKey),
        });
      }
      return JSON.stringify({ subscription: subscription.toJSON() });
    } catch (e) {
      return errorJson(e);
    }
  }

  async function unsubscribe() {
    try {
      if (!supported()) return JSON.stringify({});
      var subscription = await currentSubscription();
      if (!subscription) return JSON.stringify({});
      var endpoint = subscription.endpoint;
      await subscription.unsubscribe();
      return JSON.stringify({ endpoint: endpoint });
    } catch (e) {
      return errorJson(e);
    }
  }

  window.pawaiPush = { info: info, subscribe: subscribe, unsubscribe: unsubscribe };
})();
