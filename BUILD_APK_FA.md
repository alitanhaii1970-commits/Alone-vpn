# ساخت APK اندروید ALONE VPN

## روش ابری (پیشنهادی)

فایل `.github/workflows/android-apk.yml` با هر push روی `main`، پس از نصب وابستگی‌ها، هسته‌های native مربوط به Xray و sing-box را می‌سازد، تست‌های Flutter را اجرا می‌کند و APK دیباگ را تولید می‌کند.

1. همهٔ محتویات پوشهٔ `vpnapp` را به ریشهٔ مخزن `alitanhaii1970-commits/Alone-vpn` بفرستید؛ فایل‌ها باید در ریشه باشند و پوشهٔ اضافهٔ `vpnapp/` به‌عنوان پوشهٔ تودرتو باقی نماند.
2. در GitHub وارد تب **Actions** و workflow با نام **Build ALONE VPN APK** شوید و **Run workflow** را بزنید. Push روی `main` هم به‌صورت خودکار آن را اجرا می‌کند.
3. پس از اتمام موفق، صفحهٔ اجرای workflow را باز کنید و از قسمت **Artifacts** فایل `alone-vpn-debug-apk` را دریافت کنید.
4. فایل `app-debug.apk` یک APK قابل‌نصب برای آزمایش شخصی است؛ نسخهٔ Play Store و امضای release محسوب نمی‌شود.

## ساخت روی رایانهٔ لینوکس

نیاز است Flutter stable، Java 17، Go، Python 3، Android SDK و NDK نسخهٔ `28.2.13676358` نصب باشند. سپس در ریشهٔ پروژه:

```bash
flutter create .
flutter pub get
python3 scripts/patch_android_for_vpn.py
python3 scripts/patch_v2ray_box_android.py
PLUGIN_DIR="$(find "$HOME/.pub-cache" -type f -path '*/example/scripts/build_android_libxray.sh' -print -quit | sed 's#/example/scripts/build_android_libxray.sh$##')"
cp "$PLUGIN_DIR/example/scripts/build_android_libxray.sh" scripts/
cp "$PLUGIN_DIR/example/scripts/build_android_libsingbox.sh" scripts/
bash scripts/build_android_libxray.sh --project-root "$PWD" --libxray-ref v26.1.23 --android-abis arm64-v8a,x86_64
bash scripts/build_android_libsingbox.sh --project-root "$PWD" --singbox-ref v1.14.3 --android-abis arm64-v8a,x86_64
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```

APK خروجی در `build/app/outputs/flutter-apk/app-debug.apk` قرار می‌گیرد.

## امنیت و محدودیت

- توکن GitHub را داخل سورس، workflow، آرشیو یا پیام چت قرار ندهید؛ برای push از ورود امن Git Credential Manager یا احراز هویت مرورگری GitHub CLI استفاده کنید.
- این workflow APK آزمایشیِ debug می‌سازد و کلید انتشار خصوصی نمی‌خواهد.
- تا وقتی اجرای workflow سبز نشده و APK روی دستگاه واقعی نصب و آزموده نشده، نمی‌توان اتصال واقعی VPN را تأییدشده دانست.
