## ALONE VPN — beta

**What's new in 1.2.1**
- The "Choose your language" screen now appears only once, on the very first launch (quitting half-way through onboarding no longer brings it back).
- Bottom navigation fits small phones and large system text.
- Settings are saved even if the first load was slow; the notification-permission step can no longer hang.
- Signed with the same key as 1.2.0, so it installs over it.

An Android VPN client for VMess / VLESS / Shadowsocks / Trojan with the Xray and sing-box cores.

**Install:** download the APK, allow *Install unknown apps* if asked. If you have an older **debug** build installed, uninstall it first (different signing key). Compare with the attached `.sha256` if you like.

**What was tested:** Android 14 emulator in CI — launch, real VPN connection (Shadowsocks), traffic really tunnelled, 5 MB download, clean disconnect and routing restore (15/15 checks), plus 22 UI/layout tests (every tab and screen × 3 phone sizes × 2 text sizes × English/Persian).

**Not tested yet:** physical phones, filtered networks, VMess / VLESS / Trojan / Hysteria servers, kill switch, split tunneling. Please report problems in Issues with your Android version, phone model and the in-app connection log.

You bring your own server: ALONE VPN is a client and does not provide any.

---

**تازه‌های ۱.۲.۱**
- صفحه‌ی «زبان خود را انتخاب کنید» فقط یک بار، موقع اولین اجرا میاد (بستن برنامه وسط معرفی دیگه اون رو برنمی‌گردونه).
- نوار پایین روی گوشی‌های کوچیک و متن بزرگ سیستم جا می‌شه.
- تنظیمات حتی اگه بارگذاری اول کند باشه ذخیره می‌شن و مرحله‌ی مجوز نوتیفیکیشن دیگه گیر نمی‌کنه.
- با همون کلید ۱.۲.۰ امضا شده، پس روش نصب می‌شه.

**نصب:** فایل APK رو دانلود کن و اگه اندروید پرسید نصب از این منبع رو اجازه بده. اگه نسخه‌ی **debug** قدیمی نصب داری اول پاکش کن (امضاش فرق داره).

**چی تست شده:** امولاتور اندروید ۱۴ توی CI — اتصال واقعی (Shadowsocks)، عبور واقعی ترافیک، دانلود ۵ مگابایتی، قطع تمیز (۱۵ از ۱۵) و ۲۲ تست UI (هر تب و صفحه × ۳ اندازه‌ی گوشی × ۲ اندازه‌ی متن × فارسی/انگلیسی).

**هنوز تست نشده:** گوشی فیزیکی، شبکه‌ی فیلترشده، سرورهای VMess / VLESS / Trojan / Hysteria، کیل‌سوییچ و تفکیک برنامه‌ها. مشکلات رو با نسخه‌ی اندروید، مدل گوشی و گزارش اتصال داخل برنامه توی Issues بنویس.
