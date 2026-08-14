import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.wakeed.remittance",
  appName: "وكيد — سند حوالة",
  webDir: "../client",
  server: {
    // Set your production URL before building release APK:
    // url: "https://YOUR_DOMAIN",
    // cleartext: false,
    androidScheme: "https",
  },
  android: {
    allowMixedContent: false,
  },
};

export default config;
