(function (global) {
  async function resolveCapacitorDeviceId() {
    try {
      if (!global.Capacitor?.isNativePlatform?.()) return null;
      const mod = await import("@capacitor/device");
      const info = await mod.Device.getId();
      return info?.identifier || null;
    } catch (_) {
      return null;
    }
  }

  async function bindForegroundHeartbeat() {
    try {
      if (!global.Capacitor?.isNativePlatform?.()) return;
      const mod = await import("@capacitor/app");
      mod.App.addListener("appStateChange", function (state) {
        if (state.isActive && global.WakeedPlatform?.heartbeat) {
          global.WakeedPlatform.heartbeat();
        }
      });
    } catch (_) {}
  }

  global.WakeedCapacitorBridge = {
    resolveCapacitorDeviceId: resolveCapacitorDeviceId,
    bindForegroundHeartbeat: bindForegroundHeartbeat,
  };
})(window);
