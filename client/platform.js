(function (global) {
  const SESSION_KEY = "wakeedPlatform.session";
  const DEVICE_KEY = "wakeedPlatform.deviceId";
  const HEARTBEAT_MS = Number(global.PLATFORM_HEARTBEAT_MS || 45000);

  const platformState = {
    sessionToken: "",
    deviceId: "",
    deviceName: "",
    licenseKey: "",
    server: "server1.wakeed.app",
    buildNumber: "3996",
    wakeedToken: "",
    ownerKey: "",
    username: "",
    userDisplayName: "",
    subscriptions: [],
    blocked: false,
    blockMessage: "",
  };

  let heartbeatTimer = null;
  let onBlockCallback = null;

  function storageGet(key) {
    try {
      return localStorage.getItem(key) || "";
    } catch (_) {
      return "";
    }
  }

  function storageSet(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (_) {}
  }

  function storageRemove(key) {
    try {
      localStorage.removeItem(key);
    } catch (_) {}
  }

  function getDeviceId() {
    if (platformState.deviceId) return platformState.deviceId;
    let id = storageGet(DEVICE_KEY);
    if (!id) {
      id = "d-" + Date.now() + "-" + Math.random().toString(16).slice(2, 10);
      storageSet(DEVICE_KEY, id);
    }
    platformState.deviceId = id;
    return id;
  }

  function getDeviceName() {
    if (platformState.deviceName) return platformState.deviceName;
    const ua = navigator.userAgent || "";
    platformState.deviceName = ua.includes("Android")
      ? "Android"
      : ua.includes("iPhone")
        ? "iPhone"
        : "Mobile Web";
    return platformState.deviceName;
  }

  function loadSessionFromStorage() {
    try {
      const raw = storageGet(SESSION_KEY);
      if (!raw) return false;
      const data = JSON.parse(raw);
      platformState.sessionToken = data.sessionToken || "";
      platformState.licenseKey = data.licenseKey || "";
      return Boolean(platformState.sessionToken);
    } catch (_) {
      return false;
    }
  }

  function saveSessionToStorage() {
    storageSet(
      SESSION_KEY,
      JSON.stringify({
        sessionToken: platformState.sessionToken,
        licenseKey: platformState.licenseKey,
      })
    );
  }

  function clearSessionStorage() {
    storageRemove(SESSION_KEY);
    platformState.sessionToken = "";
    platformState.licenseKey = "";
  }

  function platformHeaders() {
    return {
      "Content-Type": "application/json",
      Authorization: "Bearer " + platformState.sessionToken,
      "X-Session-Token": platformState.sessionToken,
      "X-Device-Id": getDeviceId(),
    };
  }

  async function platformFetch(path, options) {
    options = options || {};
    const res = await fetch(path, {
      method: options.method || "GET",
      headers: Object.assign({}, platformHeaders(), options.headers || {}),
      body: options.body,
    });
    const json = await res.json().catch(function () {
      return {};
    });
    if (res.status === 403 || res.status === 401) {
      const msg = json.message || "الترخيص غير صالح.";
      blockApp(msg, json.code);
      throw new Error(msg);
    }
    if (!res.ok || json.ok === false) {
      throw new Error(json.message || "HTTP " + res.status);
    }
    return json.data !== undefined ? json : json;
  }

  function blockApp(message, code) {
    platformState.blocked = true;
    platformState.blockMessage = message;
    stopHeartbeat();
    if (onBlockCallback) onBlockCallback(message, code || "");
  }

  function unblockApp() {
    platformState.blocked = false;
    platformState.blockMessage = "";
  }

  function onBlock(cb) {
    onBlockCallback = cb;
  }

  async function activateLicense(licenseKey) {
    const res = await fetch("/api/license/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        licenseKey: String(licenseKey || "")
          .trim()
          .toUpperCase(),
        deviceId: getDeviceId(),
        deviceName: getDeviceName(),
      }),
    });
    const json = await res.json();
    if (!res.ok || json.ok === false) {
      throw new Error(json.message || "فشل تفعيل الترخيص.");
    }
    platformState.sessionToken = json.data.sessionToken;
    platformState.licenseKey = json.data.licenseKey;
    saveSessionToStorage();
    unblockApp();
    startHeartbeat();
    return json.data;
  }

  async function heartbeat() {
    if (!platformState.sessionToken) return false;
    try {
      const res = await fetch("/api/license/heartbeat", {
        method: "POST",
        headers: platformHeaders(),
      });
      const json = await res.json();
      if (!res.ok || json.ok === false) {
        blockApp(json.message || "الترخيص غير صالح.", json.code);
        return false;
      }
      return true;
    } catch (_) {
      blockApp("لا يوجد اتصال بالسيرفر. التطبيق متوقف حتى عودة الاتصال.", "offline");
      return false;
    }
  }

  function startHeartbeat() {
    stopHeartbeat();
    heartbeat();
    heartbeatTimer = setInterval(function () {
      heartbeat();
    }, HEARTBEAT_MS);
  }

  function stopHeartbeat() {
    if (heartbeatTimer) clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }

  async function initPlatform() {
    getDeviceId();
    if (global.WakeedCapacitorBridge?.resolveCapacitorDeviceId) {
      try {
        const capId = await global.WakeedCapacitorBridge.resolveCapacitorDeviceId();
        if (capId) {
          platformState.deviceId = capId;
          storageSet(DEVICE_KEY, capId);
        }
      } catch (_) {}
    }
    if (global.WakeedCapacitorBridge?.bindForegroundHeartbeat) {
      global.WakeedCapacitorBridge.bindForegroundHeartbeat().catch(function () {});
    }
    if (!loadSessionFromStorage()) return false;
    const ok = await heartbeat();
    startHeartbeat();
    return true;
  }

  async function logoutLicense() {
    stopHeartbeat();
    clearSessionStorage();
    platformState.wakeedToken = "";
  }

  global.WakeedPlatform = {
    platformState: platformState,
    getDeviceId: getDeviceId,
    getDeviceName: getDeviceName,
    platformHeaders: platformHeaders,
    platformFetch: platformFetch,
    blockApp: blockApp,
    unblockApp: unblockApp,
    onBlock: onBlock,
    activateLicense: activateLicense,
    heartbeat: heartbeat,
    startHeartbeat: startHeartbeat,
    stopHeartbeat: stopHeartbeat,
    initPlatform: initPlatform,
    logoutLicense: logoutLicense,
    clearSessionStorage: clearSessionStorage,
  };
})(window);
