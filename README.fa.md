<div align="center">

# ALONE VPN

**کلاینت سریع و خوش‌ظاهر VPN برای اندروید: VMess · VLESS · Shadowsocks · Trojan**
با هسته‌های **Xray** و **sing-box**، نوشته‌شده با Flutter.

[![Build](https://github.com/alitanhaii1970-commits/Alone-vpn/actions/workflows/android-apk.yml/badge.svg)](https://github.com/alitanhaii1970-commits/Alone-vpn/actions/workflows/android-apk.yml)
[![Latest release](https://img.shields.io/github/v/release/alitanhaii1970-commits/Alone-vpn?include_prereleases&label=release&color=2ea043)](https://github.com/alitanhaii1970-commits/Alone-vpn/releases)
![Platform](https://img.shields.io/badge/platform-Android-3ddc84?logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)

[English](README.md) · **فارسی**

<br>

<img src="docs/screenshots/connected.png" width="250" alt="متصل">
&nbsp;
<img src="docs/screenshots/home.png" width="250" alt="صفحه‌ی اصلی">
&nbsp;
<img src="docs/screenshots/language.png" width="250" alt="سرورها">

</div>

<div dir="rtl">

---

## دانلود

آخرین APK رو از بخش **[Releases](https://github.com/alitanhaii1970-commits/Alone-vpn/releases/latest)** بگیر.

1. فایل `ALONE-VPN-<نسخه>.apk` رو روی گوشی دانلود کن.
2. بازش کن. اگه اندروید پرسید، نصب از این منبع (مرورگر یا فایل‌منیجر) رو اجازه بده.
3. اگه قبلاً نسخه‌ی **debug** نصب کرده بودی، اول پاکش کن (امضاش فرق داره). نسخه‌های release با یه کلید ثابت امضا می‌شن، پس نسخه‌های بعدی روی هم نصب می‌شن.
4. اختیاری: فایل رو با `.sha256` ضمیمه‌شده مقایسه کن.

> ALONE VPN فقط **کلاینت** هست و سرور ارائه نمی‌ده. لینک کانفیگ یا اشتراک خودت رو باید بیاری.

## امکانات

| | |
|---|---|
| **پروتکل‌ها** | VMess، VLESS، Shadowsocks، Trojan. لینک‌های Hysteria / Hysteria2، TUIC، WireGuard، SOCKS و SSH هم شناخته می‌شن و به موتور داده می‌شن (تست‌نشده). |
| **افزودن سرور** | چسباندن لینک اشتراکی یا آدرس اشتراک (دکمه‌ی **چسباندن** کلیپ‌بورد رو می‌خونه)، یا باز کردن همچین لینکی / اشتراک‌گذاری متن / باز کردن فایل متنی پر از لینک از هر برنامه‌ی دیگه. فایل اشتراک base64 هم کار می‌کنه. سرورها روی دستگاه ذخیره می‌شن. |
| **تونل واقعی** | `VpnService` اندروید با دیالوگ رسمی مجوز. هسته‌های Xray و sing-box به‌صورت کتابخانه‌ی بومی داخل برنامه‌ان. |
| **اشتراک‌ها** | آدرس اشتراک‌ها یادش می‌مونه؛ با یک ضربه به‌روز می‌شن (سرور جدید اضافه و سرورهای حذف‌شده برداشته می‌شن). |
| **پاک‌سازی** | یه دکمه همه‌ی سرورها رو پینگ می‌کنه و پیشنهاد می‌ده اونایی که جواب ندادن حذف بشن (سرورهای UDP هیچ‌وقت «مرده» حساب نمی‌شن؛ اگه هیچ‌کدوم جواب نده احتمالاً اینترنت قطعه و چیزی حذف نمی‌شه). |
| **OpenVPN** | پروفایل‌های ‎.ovpn (با گواهی داخل فایل) به‌عنوان سرور وارد می‌شن و از طریق API رسمی برنامه‌ی رایگان **OpenVPN for Android** اجرا می‌شن — Xray و sing-box نمی‌تونن OpenVPN اجرا کنن. |
| **تست تأخیر** | پروب TCP یا URL برای هر سرور، علاقه‌مندی‌ها و نمودار کوچک تأخیر در صفحه‌ی اصلی. |
| **DNS** | Cloudflare، Google، Quad9، الکترو (گیمینگ) و DNS دلخواه. |
| **قوانین مسیریابی** | روشن/خاموش کردن قوانین مستقیم / مسدود / پروکسی (ایران، شبکه‌ی محلی، تبلیغات، برنامه‌ها، UDP، QUIC). |
| **تفکیک برنامه‌ها** | برای هر برنامه: خاموش، فقط این‌ها، یا همه به‌جز این‌ها. |
| **کیل‌سوییچ** | اختیاری. |
| **مصرف و لاگ** | ترافیک زنده، تاریخچه‌ی اتصال، گزارش اتصال، راهنمای داخل برنامه. |
| **ظاهر** | شش تم (Obsidian، Aqua، Neon، Midnight، Ember، Matcha) در حالت روشن، تیره یا خودکار، انیمیشن فنری و لرزش لمسی. |
| **فارسی و انگلیسی** | پشتیبانی کامل راست‌به‌چپ، ارقام فارسی یا لاتین، فونت‌های Vazirmatn / Geist داخل برنامه (بدون نیاز به اینترنت)، اندازه‌ی متن ۹۰ تا ۱۲۵٪. |
| **حالت صرفه‌جویی باتری** | با یه کلید انیمیشن‌های سنگین خاموش می‌شن. |

## وضعیت — چی تأیید شده

ALONE VPN هنوز **بتا** هست. خلاصه‌ی صادقانه:

- ✅ APK نسخه‌ی release توی CI ساخته و نصب می‌شه.
- ✅ روی امولاتور اندروید ۱۴ توی CI: برنامه بالا میاد، با موتور واقعی وصل می‌شه، ترافیک واقعاً از تونل رد می‌شه (یه سرور Xray/Shadowsocks محلی درخواست‌ها رو می‌بینه)، دانلود ۵ مگابایتی کامل می‌شه و بعد از قطع، تونل برداشته و مسیریابی برمی‌گرده. **۱۵ از ۱۵ بررسی** توی آخرین اجرا پاس شد.
- ✅ ۳۷ تست خودکار (هر صفحه × ۳ اندازه‌ی گوشی × ۲ اندازه‌ی متن × فارسی/انگلیسی، ذخیره‌ی تنظیمات، اشتراک‌ها، پاک‌سازی سرورهای مرده، پروفایل OpenVPN).
- ✅ **OpenVPN** با یه سرور واقعی OpenVPN روی امولاتور چک شد: وارد کردن پروفایل، تحویل به OpenVPN for Android، وضعیت CONNECTED، پینگ از داخل تونل و قطع تمیز (۸ از ۸). لاگ خود سرور هم اتصال کلاینت رو نشون می‌ده.
- ✅ باز کردن لینک و متن اشتراک‌گذاری‌شده از برنامه‌های دیگه و این‌که صفحه‌ی زبان فقط یک بار میاد، توی هر اجرا روی امولاتور چک می‌شه (۲۱ از ۲۱).
- ⚠️ روی گوشی فیزیکی، توی شبکه‌ی فیلترشده، و با سرورهای VMess / VLESS / Trojan / Hysteria هنوز تأیید نشده (تست انتها‌به‌انتها با Shadowsocks انجام شده).
- ⚠️ کیل‌سوییچ و تفکیک برنامه‌ها پیاده شدن ولی تست خودکار ندارن.
- ⚠️ **OpenVPN** از طریق برنامه‌ی جدا نصب‌شده‌ی OpenVPN for Android کار می‌کنه (تحویل به اون)، نه با هسته‌ای داخل ALONE VPN. جزئیات تأییدشده‌ها توی یادداشت انتشار هست.
- ❌ **فایل‌های NPV Tunnel (‎.npv4) پشتیبانی نمی‌شن**: رمزگذاری‌شده‌ان. اگه بخوای یکی رو باز کنی، برنامه همین رو می‌گه.
- ℹ️ فقط اندروید تونل واقعی داره. روی دسکتاپ دکمه‌ی اتصال فقط پیش‌نمایشه.
- ℹ️ «مصرف» ترافیک زنده رو نشون می‌ده؛ آمار روزانه/ماهانه نیست چون موتور این تفکیک رو نداره.

باگ پیدا کردی؟ یه [Issue](https://github.com/alitanhaii1970-commits/Alone-vpn/issues) باز کن و نسخه‌ی اندروید، مدل گوشی و گزارش اتصال داخل برنامه رو بنویس.

## ساخت از روی سورس

همه‌چیز با GitHub Actions ساخته می‌شه ([`android-apk.yml`](.github/workflows/android-apk.yml)):
کتابخانه‌های بومی Xray و sing-box ← `flutter analyze` و تست‌ها ← **APK امضاشده‌ی release** ← تست انتها‌به‌انتها روی امولاتور.
یه تگ مثل `v1.2.0` بزنی، GitHub Release خودکار منتشر می‌شه.

برای ساخت روی سیستم خودت Flutter، Go، Android SDK و NDK لازمه:

</div>

```bash
flutter create .
flutter pub get
python3 scripts/patch_android_for_vpn.py
python3 scripts/patch_v2ray_box_android.py
# دو اسکریپت ساخت کتابخانه‌ی بومی رو از افزونه‌ی v2ray_box کپی کن (workflow رو ببین)، بعد:
bash scripts/build_android_libxray.sh   --project-root "$(pwd)" --libxray-ref v26.1.23 --android-abis arm64-v8a
bash scripts/build_android_libsingbox.sh --project-root "$(pwd)" --singbox-ref v1.14.3  --android-abis arm64-v8a
flutter build apk --release --no-shrink --target-platform android-arm64
```

<div dir="rtl">

> نسخه‌ی libXray عمداً روی `v26.1.23` قفل شده: افزونه‌ی `v2ray_box` از API تک‌تک‌توابع اون استفاده می‌کنه که نسخه‌های جدیدتر عوضش کردن. به همین دلیل Go و `golang.org/x/mobile` هم توی workflow قفل شدن.

امضای نسخه‌ی release دو تا Secret توی ریپو لازم داره: `ALONE_KEYSTORE_B64` (base64 یه keystore از نوع PKCS#12 با alias برابر `alone`) و `ALONE_STORE_PASS`. **از keystore حتماً نسخه‌ی پشتیبان نگه دار**؛ بدونش نمی‌تونی آپدیتی منتشر کنی که روی نسخه‌ی نصب‌شده نصب بشه.

## ساختار پروژه

</div>

```
lib/core/      توکن‌های طراحی، رنگ (OKLCH)، تایپوگرافی، آیکون، ترجمه، تنظیمات
lib/ui/kit/    شیشه، فشار فنری، کارت، چیپ، سوییچ، شیت، نوار ناوبری …
lib/ui/screens اسپلش، معرفی، صفحه‌ی اصلی (دایال اتصال)، سرورها، مصرف، تنظیمات، DNS، تأخیر، لاگ
lib/data/      ذخیره‌ی سرورها، ماشین حالت اتصال، لاگ
lib/services/  تنها پل به موتور بومی (v2ray_box)
scripts/       پچ‌های اندروید، کمک‌های CI، تست امولاتور
test/          تست‌های ویجت و چیدمان
```

<div dir="rtl">

## سپاس

- [Xray-core](https://github.com/XTLS/Xray-core) و [libXray](https://github.com/XTLS/libXray)
- [sing-box](https://github.com/SagerNet/sing-box)
- افزونه‌ی Flutter با نام [v2ray_box](https://github.com/pesaregorg/v2ray_box)
- [Flutter](https://flutter.dev)، فونت‌های [Vazirmatn](https://github.com/rastikerdar/vazirmatn)، [Geist](https://github.com/vercel/geist-font) و Noto Naskh Arabic

</div>
