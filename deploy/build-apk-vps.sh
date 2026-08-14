#!/usr/bin/env bash
# Build Capacitor Android APK on VPS (WebView → https://wakeed.lork.cloud)
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/wakeed-platform}"
ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export ANDROID_HOME
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

cd "$APP_DIR/mobile"
npm install
if [ ! -d android ]; then
  npx cap add android
fi
npx cap sync android

if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  apt-get update
  apt-get install -y openjdk-17-jdk wget unzip
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  tmp=$(mktemp -d)
  wget -q -O "$tmp/cmdtools.zip" https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q "$tmp/cmdtools.zip" -d "$tmp"
  mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp"
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
fi

cd android
chmod +x gradlew
./gradlew assembleDebug -x lint

APK="app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK" ]; then
  echo "APK build failed" >&2
  exit 1
fi

cp "$APK" "$APP_DIR/releases/wakeed-app.apk"
chmod 644 "$APP_DIR/releases/wakeed-app.apk"
echo "OK: $APP_DIR/releases/wakeed-app.apk ($(du -h "$APP_DIR/releases/wakeed-app.apk" | cut -f1))"
