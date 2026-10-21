## ALONE VPN — beta

**What's new in 1.3.0**
- **Open links and files from other apps:** tapping a vless:// vmess:// ss:// trojan:// … link, using *Share → ALONE VPN* on text, or opening a text file full of links now imports the servers (checked on an Android 14 emulator: link while the app runs, link that starts the app, shared text). Base64 subscription files work too, and the add-config sheet has a **Paste** button.
- **OpenVPN (.ovpn) and NPV Tunnel (.npv4) files are not supported** — the Xray and sing-box engines don't run OpenVPN and .npv4 files are encrypted. The app now says so clearly instead of a generic error.
- A cleaner look: Geist typeface for the English UI, calmer tonal buttons instead of heavy dark ones, softer card edges and background, nearly solid bottom bar, sheets and dialogs so nothing shows through them.
- The add-config text no longer promises features that did not exist (QR scanning).

**Earlier: 1.2.2**
- **Fixed the real cause of the language screen appearing on every launch:** on Android nothing was ever saved (the storage plugin crashed at runtime). Settings, language and saved servers are now kept in a file in the app's private folder. Checked on an Android 14 emulator: choose a language, close the app, open it again — it goes straight to the app.
- Smoother background animation, quicker page transitions and a short fade when switching tabs.
- Dialogs and sheets dim the screen instead of turning it black; the theme picker no longer has an empty band or a tilted tile; DNS list spacing fixed.
- The floating status pill is hidden on the Home screen; the connection time is shown under the status instead.
- The version shown in the app is now correct.
- Signed with the same key as before, so it installs over 1.2.0 / 1.2.1.

**Earlier: 1.2.1**
- The "Choose your language" screen now appears only once, on the very first launch (quitting half-way through onboarding no longer brings it back).
- Bottom navigation fits small phones and large system text.
- Settings are saved even if the first load was slow; the notification-permission step can no longer hang.
- Signed with the same key as 1.2.0, so it installs over it.

An Android VPN client for VMess / VLESS / Shadowsocks / Trojan with the Xray and sing-box cores.

**Install:** download the APK, allow *Install unknown apps* if asked. If you have an older **debug** build installed, uninstall it first (different signing key). Compare with the attached `.sha256` if you like.

**What was tested:** Android 14 emulator in CI — launch, real VPN connection (Shadowsocks), traffic really tunnelled, 5 MB download, clean disconnect and routing restore (15/15 checks), plus 25 automated tests (every tab and screen × 3 phone sizes × 2 text sizes × English/Persian, and settings persistence).

**Not tested yet:** physical phones, filtered networks, VMess / VLESS / Trojan / Hysteria servers, kill switch, split tunneling. Please report problems in Issues with your Android version, phone model and the in-app connection log.

You bring your own server: ALONE VPN is a client and does not provide any.

---

**تازه‌های ۱.۳.۰**
- **باز کردن لینک و فایل از برنامه‌های دیگه:** زدن روی یه لینک vless:// vmess:// ss:// trojan:// …، «اشتراک‌گذاری» متن به ALONE VPN، یا باز کردن یه فایل متنی پر از لینک، سرورها رو وارد می‌کنه (روی امولاتور اندروید ۱۴ تأیید شد: لینک وقتی برنامه بازه، لینکی که برنامه رو راه می‌ندازه، و متن اشتراک‌گذاری‌شده). فایل اشتراک base64 هم کار می‌کنه و توی شیت افزودن کانفیگ دکمه‌ی **چسباندن** هست.
- **فایل OpenVPN (‎.ovpn) و NPV Tunnel (‎.npv4) پشتیبانی نمی‌شه** — هسته‌های Xray و sing-box OpenVPN اجرا نمی‌کنن و فایل‌های .npv4 رمزگذاری‌شده‌ان. برنامه الان به‌جای خطای کلی، همین رو واضح می‌گه.
- ظاهر تمیزتر: فونت Geist برای رابط انگلیسی، دکمه‌های ثانویه‌ی سبک به‌جای دکمه‌های تیره‌ی سنگین، لبه‌ها و پس‌زمینه‌ی آرام‌تر، و نوار پایین، شیت‌ها و دیالوگ‌های تقریباً مات تا چیزی از پشتشون دیده نشه.
- متن افزودن کانفیگ دیگه قابلیتی که وجود نداشت (اسکن QR) رو وعده نمی‌ده.

**قبلی: ۱.۲.۲**
- **علت واقعی ظاهر شدن صفحه‌ی زبان در هر بار اجرا درست شد:** روی اندروید هیچ‌چیز ذخیره نمی‌شد (پلاگین ذخیره‌سازی موقع اجرا کرش می‌کرد). تنظیمات، زبان و سرورهای ذخیره‌شده حالا توی یه فایل توی پوشه‌ی خصوصی برنامه نگه‌داری می‌شن. روی امولاتور اندروید ۱۴ تأیید شد: زبان رو انتخاب می‌کنی، برنامه رو می‌بندی و دوباره باز می‌کنی؛ مستقیم میره توی برنامه.
- انیمیشن پس‌زمینه روان‌تر، جابه‌جایی صفحه‌ها سریع‌تر و موقع عوض کردن تب یه محو شدن کوتاه.
- پشت شیت‌ها و دیالوگ‌ها به‌جای سیاه شدن کم‌رنگ می‌شه؛ انتخاب تم دیگه فاصله‌ی خالی و کاشی کج نداره؛ فاصله‌ی ردیف‌های DNS درست شد.
- نوار شناور وضعیت روی صفحه‌ی اصلی پنهان شد و زمان اتصال زیر وضعیت نشون داده می‌شه.
- نسخه‌ی نمایش‌داده‌شده توی برنامه درسته.
- با همون کلید قبلی امضا شده و روی ۱.۲.۰ و ۱.۲.۱ نصب می‌شه.

**قبلی: ۱.۲.۱**
- صفحه‌ی «زبان خود را انتخاب کنید» فقط یک بار، موقع اولین اجرا میاد (بستن برنامه وسط معرفی دیگه اون رو برنمی‌گردونه).
- نوار پایین روی گوشی‌های کوچیک و متن بزرگ سیستم جا می‌شه.
- تنظیمات حتی اگه بارگذاری اول کند باشه ذخیره می‌شن و مرحله‌ی مجوز نوتیفیکیشن دیگه گیر نمی‌کنه.
- با همون کلید ۱.۲.۰ امضا شده، پس روش نصب می‌شه.

**نصب:** فایل APK رو دانلود کن و اگه اندروید پرسید نصب از این منبع رو اجازه بده. اگه نسخه‌ی **debug** قدیمی نصب داری اول پاکش کن (امضاش فرق داره).

**چی تست شده:** امولاتور اندروید ۱۴ توی CI — اتصال واقعی (Shadowsocks)، عبور واقعی ترافیک، دانلود ۵ مگابایتی، قطع تمیز (۱۵ از ۱۵) و ۲۵ تست خودکار (هر تب و صفحه × ۳ اندازه‌ی گوشی × ۲ اندازه‌ی متن × فارسی/انگلیسی، و ذخیره‌ی تنظیمات).

**هنوز تست نشده:** گوشی فیزیکی، شبکه‌ی فیلترشده، سرورهای VMess / VLESS / Trojan / Hysteria، کیل‌سوییچ و تفکیک برنامه‌ها. مشکلات رو با نسخه‌ی اندروید، مدل گوشی و گزارش اتصال داخل برنامه توی Issues بنویس.
