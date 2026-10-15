# ALONE VPN

کپی دیزاین `alone_vpn_v12.html` در فلاتر: همان توکن‌های رنگ (OKLCH، شش تم × دو حالت)،
همان مقیاس تایپوگرافی، همان منحنی‌های فنر (جدول‌های `linear()` خود فایل)، همان آیکون‌های SVG،
همان متن‌های فارسی و انگلیسی (۳۱۶ کلید از جدول `I18N` فایل)، و همان صفحه‌ها.

## اجرا (همیشه این ترتیب)
```
flutter create .
flutter pub get
python3 scripts/patch_android_for_vpn.py
python3 scripts/patch_v2ray_box_android.py
PLUGIN_DIR=$(find "$HOME/.pub-cache/git" -maxdepth 2 -type d -iname '*v2ray_box*' | head -1)
mkdir -p scripts
cp "$PLUGIN_DIR/example/scripts/build_android_libxray.sh" scripts/
cp "$PLUGIN_DIR/example/scripts/build_android_libsingbox.sh" scripts/
bash scripts/build_android_libxray.sh --project-root "$(pwd)" --libxray-ref v26.1.23 --android-abis arm64-v8a,x86_64
bash scripts/build_android_libsingbox.sh --project-root "$(pwd)" --singbox-ref v1.14.3 --android-abis arm64-v8a,x86_64
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```
اسکریپت دوم روی نسخهٔ پین‌شدهٔ افزونه، برگشت مجوز اندروید ۱۳+ و لغو اتصال در زمان بازبودن دیالوگ مجوز VPN را مدیریت می‌کند. ساخت ابری در `codemagic.yaml` همین زنجیره را اجرا می‌کند.

## ساختار
- `lib/core/` — توکن‌ها (`tokens.dart`)، رنگ (`oklch.dart`، `palette.dart`)، تایپ (`typography.dart`)، آیکون (`icons.dart`)، ترجمه (`strings.dart` تولیدشده از فایل، `strings_extra.dart` برای ۵۰ کلیدی که در فایل نبود)، تنظیمات ماندگار (`settings.dart`).
- `lib/ui/kit/` — اجزای دیزاین: شیشه، فشار با فنر و ریپل، کارت، چیپ، دکمه، سگمنت، سوییچ، چک‌باکس، رادیو، اسلایدر، فیلد، پیل وضعیت، نوار ناوبری، اسنک‌بار، شیت و دیالوگ.
- `lib/ui/screens/` — اسپلش، انتخاب زبان، سه صفحه‌ی آنبوردینگ، شل با چهار تب، صفحه‌ی اصلی (دایال، مراحل اتصال، تله‌متری، کاشی‌ها)، سرورها، مصرف، تنظیمات، تأخیر، DNS، گزارش، راهنما.
- `lib/services/engine.dart` — تنها نقطه‌ی تماس با موتور واقعی (`v2ray_box`: `VpnService` + Xray/sing-box).
- `lib/data/stores.dart` — سرورها، ماشین حالت اتصال (جستجوی DNS، TCP، TLS، تانل)، لاگ، اسنک‌بار.

## آنچه واقعی است و آنچه نیست
**واقعی:** ورود و ترجیح‌های ذخیره‌شونده، مجوز VPN هنگام اتصال واقعی از طریق دیالوگ رسمی اندروید، واردکردن لینک/اشتراک، پینگ TCP، اتصال/قطع، مصرف زنده، و تنظیمات DNS/قواعد/تفکیک برنامه‌ها روی اندروید.

**نیست یا محدود:**
- فقط اندروید تانل واقعی دارد. روی لینوکس/ویندوز دکمه‌ی اتصال فقط پیش‌نمایش است و لاگ همین را می‌گوید.
- «روز / ماه» در آمار نیست؛ موتور این تفکیک را ندارد و عدد ساختگی هم نمی‌سازیم.
- فهرست برنامه‌های نصب‌شده برای تفکیک از موتور بومی اندروید خوانده می‌شود؛ برای فهرست کامل به مجوز `QUERY_ALL_PACKAGES` و اجرای build patch نیاز است.
- فونت‌ها فایل‌های متغیر (variable) هستند؛ وزن‌ها با `FontVariation` اعمال می‌شوند. اگر روی دستگاهی وزن‌ها تفاوت داشت، گزارش بده.
- برای APK واقعی Flutter/Android SDK، Go و Android NDK لازم است. workflow کدمجیک هر دو کتابخانه‌ی بومی Xray و sing-box را می‌سازد، `flutter analyze` و `flutter test` را اجرا می‌کند و سپس APK را تولید می‌کند. تا زمان سبزشدن بیلد و نصب روی دستگاه واقعی، اتصال واقعی VPN تأییدشده محسوب نمی‌شود.

## منبع دیزاین
تمام مقادیر از `alone_vpn_v12.html` خوانده شده: `:root` و تم‌ها، فرمول اشتقاق رنگ (`palette.dart` همان فرمول‌های CSS را دارد)، جدول‌های `--ease-spring-*` و `--ease-anticipate`، سایه‌ها و درخشش‌ها (`--elev-*`، `--glow-*`)، مقیاس تایپ (`--t-*`)، فاصله‌ها (`--sp-*`)، شکل‌ها (`--shape-*`)، و ۳۸ آیکون اسپرایت. آیکون‌های `assets/icons/*.svg` مستقیم از همان اسپرایت ساخته شده‌اند. آیکون برنامه (`android_res/`) همان علامت اثرانگشت روی گرادیان است.

## ساخت APK اندروید
برای دستورهای کامل ساخت APK و روش ابری GitHub Actions، فایل [BUILD_APK_FA.md](BUILD_APK_FA.md) را ببینید. پس از بازکردن آرشیو در ویندوز، فایل `PUSH_TO_GITHUB_WINDOWS.bat` می‌تواند پروژه را از مسیر Git Credential Manager به مخزن شخصی بفرستد؛ توکن را داخل چت وارد نکنید. workflow پس از push، APK آزمایشی را به‌عنوان Artifact ارائه می‌کند.
