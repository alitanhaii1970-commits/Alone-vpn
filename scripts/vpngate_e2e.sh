#!/usr/bin/env bash
# Smart mode end to end on the emulator, against the REAL VPN Gate network: the app fetches the real list,
# picks a relay, brings up a real OpenVPN tunnel (through "OpenVPN for Android"), compares the public IP
# before/after, then tests exclusion, disconnect, reconnect and a switch to another country.
# Never fails the step: results go to /tmp/vg_e2e/report.txt. No IP address is written to any log.
set +e
OUT=/tmp/vg_e2e; mkdir -p "$OUT/shots"; REPORT="$OUT/report.txt"; : > "$REPORT"
PASS=0; FAIL=0
log()   { echo "[$(date +%H:%M:%S)] $*" | tee -a "$REPORT"; }
check() { if eval "$2"; then log "PASS  $1"; PASS=$((PASS+1)); else log "FAIL  $1"; FAIL=$((FAIL+1)); fi; }
shot()  { timeout 25 adb exec-out screencap -p > "$OUT/shots/$1.png" 2>/dev/null; }
tap()   { timeout 15 adb shell input tap "$1" "$2" >/dev/null 2>&1; sleep 2.5; }
PKG=com.example.alone_vpn
adb shell svc power stayon true >/dev/null 2>&1; adb shell settings put system screen_off_timeout 1800000 >/dev/null 2>&1
adb shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1; adb shell wm dismiss-keyguard >/dev/null 2>&1
adb shell settings put global hide_error_dialogs 1 >/dev/null 2>&1

ui_find() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb pull /sdcard/ui.xml "$OUT/ui.xml" >/dev/null 2>&1
  python3 - "$1" "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
pat = re.compile(sys.argv[1], re.I)
try:
    root = ET.parse(sys.argv[2]).getroot()
except Exception:
    sys.exit(1)
for n in root.iter("node"):
    if pat.fullmatch((n.get("text") or "").strip()) and n.get("clickable") == "true" and n.get("enabled") != "false":
        m = re.findall(r"\d+", n.get("bounds") or "")
        if len(m) == 4:
            print((int(m[0]) + int(m[2])) // 2, (int(m[1]) + int(m[3])) // 2)
            sys.exit(0)
sys.exit(1)
PY
}
has_tun() { adb shell ip -o link 2>/dev/null | grep -Eq '[0-9]+: tun[0-9]+'; }

# 1. OpenVPN for Android (the engine ALONE VPN hands the profile to)
VC=$(curl -fsSL https://f-droid.org/api/v1/packages/de.blinkt.openvpn 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['suggestedVersionCode'])" 2>/dev/null)
log "OpenVPN for Android versionCode: ${VC:-unknown}"
[ -n "$VC" ] && curl -fsSL -o /tmp/ics.apk "https://f-droid.org/repo/de.blinkt.openvpn_${VC}.apk"
check "OpenVPN for Android downloaded and installed" "[ -s /tmp/ics.apk ] && adb install -r /tmp/ics.apk >/dev/null 2>&1"
adb shell appops set de.blinkt.openvpn ACTIVATE_VPN allow >/dev/null 2>&1

# 2. the Smart test build of ALONE VPN (its self-test starts by itself)
adb uninstall "$PKG" >/dev/null 2>&1
check "Smart test APK installs" "adb install -r apks/alone-x64-smarttest.apk >/dev/null 2>&1"
adb shell appops set "$PKG" ACTIVATE_VPN allow >/dev/null 2>&1
check "no tunnel exists before the test connects" "! has_tun"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 12; shot 00_start

# 3. wait for the self-test, approving OpenVPN for Android's trust dialog when it appears
INSPECTED=0
for i in $(seq 1 300); do
  sleep 5
  if adb logcat -d | grep -q 'SELFTEST_SMART: DONE'; then break; fi
  if xy=$(ui_find 'I trust this application\.?'); then
    log "ticking the trust checkbox"; shot "trust_$i"; tap $xy
    if ok=$(ui_find 'OK'); then tap $ok; fi
  fi
  if [ "$INSPECTED" = 0 ] && adb logcat -d | grep -q 'SELFTEST_SMART: HOLD'; then
    INSPECTED=1; shot 01_connected
    { echo "--- ip link (tun)"; adb shell ip -o link | grep -E 'tun[0-9]+'; echo "--- routes through tun"; adb shell ip route show table all | grep -E 'tun[0-9]+' | head -8;
      echo "--- ping 8.8.8.8 through the tunnel"; adb shell ping -c 3 -W 4 8.8.8.8 2>&1 | tail -3;
      echo "--- DNS servers configured on networks (configuration only, NOT a leak test)"; adb shell dumpsys connectivity | grep -i -E 'DnsAddresses|dnsServers' | sed -E 's/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/x.x.x.x/g' | head -6; } > "$OUT/inspect.txt" 2>&1
    if has_tun; then TUN_DURING=1; else TUN_DURING=0; fi
  fi
done
shot 02_end
adb logcat -d | grep 'SELFTEST_SMART' | sed -E 's/^.*SELFTEST_SMART: //' > "$OUT/selftest_lines.txt"
cat "$OUT/selftest_lines.txt" >> "$REPORT"

L() { grep -q -E "$1" "$OUT/selftest_lines.txt"; }
check "the OpenVPN for Android app is installed (engine present)" "L 'OPENVPN_APP installed=true'"
check "real VPN Gate list fetched, a relay was chosen and the tunnel connected" "L '^CONNECT result=success'"
check "the public IP changed after connecting (verified by the app)" "L '^CONNECT .*ipChanged=true'"
check "a tun interface existed while connected" "[ \"$TUN_DURING\" = 1 ]"
check "mutual exclusion: starting the manual engine stopped the Smart tunnel first" "L '^EXCLUSION .*smart=disconnected'"
check "no engine was left holding the tunnel after the exclusion test" "L '^EXCLUSION .*occupying=\\[\\]'"
check "disconnect is reported" "L '^DISCONNECT state=disconnected'"
check "reconnect works and the public IP changed again" "L '^RECONNECT result=success.*ipChanged=true'"
check "switching country connects to a relay in another country" "L '^SWITCH result=success' && L '^SWITCH countryChanged=true'"
check "the public IP differs after the switch" "L '^SWITCH countryChanged=.*exitChanged=true'"
check "the Smart engine ends disconnected with no engine holding the tunnel" "L '^FINAL smart=disconnected occupying=\\[\\]'"
check "the tunnel is gone at the end" "! has_tun"
check "the self-test finished successfully" "L '^DONE ok=true'"
adb logcat -d | grep -i -E "openvpn|blinkt" | tail -40 | cut -c1-200 | sed -E 's/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/x.x.x.x/g' >> "$OUT/inspect.txt"
log "RESULT: $PASS passed, $FAIL failed"
exit 0
