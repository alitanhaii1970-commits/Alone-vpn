## ALONE VPN — beta

An Android VPN client for VMess / VLESS / Shadowsocks / Trojan with the Xray and sing-box cores.

**Install:** download the APK, allow *Install unknown apps* if asked. If you have an older **debug** build installed, uninstall it first (different signing key). Compare with the attached `.sha256` if you like.

**What was tested:** Android 14 emulator in CI — launch, real VPN connection (Shadowsocks), traffic really tunnelled, 5 MB download, clean disconnect and routing restore (15/15 checks), plus 9 UI/layout tests.

**Not tested yet:** physical phones, filtered networks, VMess / VLESS / Trojan / Hysteria servers, kill switch, split tunneling. Please report problems in Issues with your Android version, phone model and the in-app connection log.

You bring your own server: ALONE VPN is a client and does not provide any.

---

**نصب:** فایل APK رو دانلود کن و اگه اندروید پرسید نصب از این منبع رو اجازه بده. اگه نسخه‌ی **debug** قدیمی نصب داری اول پاکش کن (امضاش فرق داره).

**چی تست شده:** امولاتور اندروید ۱۴ توی CI — اتصال واقعی (Shadowsocks)، عبور واقعی ترافیک، دانلود ۵ مگابایتی، قطع تمیز (۱۵ از ۱۵) و ۹ تست UI.

**هنوز تست نشده:** گوشی فیزیکی، شبکه‌ی فیلترشده، سرورهای VMess / VLESS / Trojan / Hysteria، کیل‌سوییچ و تفکیک برنامه‌ها. مشکلات رو با نسخه‌ی اندروید، مدل گوشی و گزارش اتصال داخل برنامه توی Issues بنویس.
