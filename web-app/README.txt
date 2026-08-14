واجهة Flutter للويب. يخدمها السيرفر من `/` عند وجود index.html هنا.

إعادة البناء:
  cd flutter
  flutter build web --release --base-href /
  rm -rf ../web-app && mkdir -p ../web-app
  cp -a build/web/. ../web-app/
  find ../web-app -name '*.map' -delete
  find ../web-app -name '*.symbols' -delete

النسخة القديمة من الواجهة تبقى في /legacy/
