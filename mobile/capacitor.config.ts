import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.wakeed.remittance",
  appName: "وكيد — سند حوالة",
  webDir: "../client",
  server: {
    url: "https://wakeed.lork.cloud",
    cleartext: false,
    androidScheme: "https",
  },
  android: {
    allowMixedContent: false,
  },
};

export default config;
