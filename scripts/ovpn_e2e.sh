#!/usr/bin/env bash
# OpenVPN end to end on the emulator: install "OpenVPN for Android", import a profile into ALONE VPN,
# press Connect, approve the dialogs, expect CONNECTED, ping through the tunnel, disconnect.
# Never fails the step: results go to /tmp/ovpn_e2e/report.txt.
set +e
OUT=/tmp/ovpn_e2e; mkdir -p "$OUT/shots"; REPORT="$OUT/report.txt"; : > "$REPORT"
PASS=0; FAIL=0
log()   { echo "[$(date +%H:%M:%S)] $*" | tee -a "$REPORT"; }
check() { if eval "$2"; then log "PASS  $1"; PASS=$((PASS+1)); else log "FAIL  $1"; FAIL=$((FAIL+1)); fi; }
shot()  { timeout 25 adb exec-out screencap -p > "$OUT/shots/$1.png" 2>/dev/null; }
tap()   { timeout 15 adb shell input tap "$1" "$2" >/dev/null 2>&1; sleep 2.5; }
PKG=com.example.alone_vpn   # the generated Android project is not checked out in this job
log "package: $PKG"
adb shell svc power stayon true >/dev/null 2>&1; adb shell settings put system screen_off_timeout 1800000 >/dev/null 2>&1
adb shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1; adb shell wm dismiss-keyguard >/dev/null 2>&1
adb shell settings put global hide_error_dialogs 1 >/dev/null 2>&1

# the dialog buttons: find a clickable node whose text matches, print its centre
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

# ---- 1. OpenVPN for Android (from F-Droid)
VC=$(curl -fsSL https://f-droid.org/api/v1/packages/de.blinkt.openvpn 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['suggestedVersionCode'])" 2>/dev/null)
log "OpenVPN for Android versionCode: ${VC:-unknown}"
[ -n "$VC" ] && curl -fsSL -o /tmp/ics.apk "https://f-droid.org/repo/de.blinkt.openvpn_${VC}.apk"
check "OpenVPN for Android downloaded and installed" "[ -s /tmp/ics.apk ] && adb install -r /tmp/ics.apk >/dev/null 2>&1"
adb shell appops set de.blinkt.openvpn ACTIVATE_VPN allow >/dev/null 2>&1

# ---- 2. ALONE VPN: fresh install, choose a language, restart (onboarding is then done)
adb uninstall "$PKG" >/dev/null 2>&1
check "ALONE VPN release APK installs" "adb install -r apks/alone-x64.apk >/dev/null 2>&1"
adb shell appops set "$PKG" ACTIVATE_VPN allow >/dev/null 2>&1
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 10
tap 540 1440; sleep 3
adb shell am force-stop "$PKG"; sleep 2
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 10
shot 00_home

# ---- 3. import the profile as shared text
adb logcat -c
adb shell "am start -a android.intent.action.SEND -t text/plain -p $PKG --es android.intent.extra.TEXT '$(cat /tmp/ovpn/client.ovpn)'" >/dev/null 2>&1
sleep 7; shot 01_after_import
check "the .ovpn profile is imported as a server" "adb logcat -d | grep -q 'ALONE_INTENT ovpn=added'"

# ---- 4. Connect (the dial is at the centre of the upper screen)
adb logcat -c
tap 540 660
for i in $(seq 1 30); do
  sleep 3
  if adb logcat -d | grep -q 'ALONE_OVPN status=CONNECTED'; then break; fi
  # approve OpenVPN for Android's "allow this app" dialog and, if shown, the Android VPN consent
  if xy=$(ui_find 'I trust this application\.?'); then log "ticking the trust checkbox at $xy"; shot "trust_$i"; tap $xy; fi
  if xy=$(ui_find 'OK|Allow|ALLOW|Yes'); then log "tapping dialog button at $xy"; shot "dialog_$i"; tap $xy; fi
done
shot 02_after_connect
adb logcat -d | grep -E "ALONE_OVPN" | cut -c1-200 >> "$REPORT"
check "the bridge reached OpenVPN for Android (start requested)" "adb logcat -d | grep -q 'ALONE_OVPN start requested'"
check "OpenVPN reports CONNECTED" "adb logcat -d | grep -q 'ALONE_OVPN status=CONNECTED'"
if adb logcat -d | grep -q 'ALONE_OVPN status=CONNECTED'; then
  check "traffic passes through the OpenVPN tunnel (ping the server's tunnel address)" "adb shell ping -c 3 -W 4 10.8.0.1 2>&1 | grep -q ' 0% packet loss'"
  sleep 2; shot 03_connected
  adb logcat -c
  tap 540 660; sleep 8; shot 04_after_disconnect
  check "disconnect is reported" "adb logcat -d | grep -E 'ALONE_OVPN status=(NOPROCESS|DISCONNECTED|EXITING)' | grep -q ."
fi
adb logcat -d | grep -i -E "openvpn|blinkt" | tail -60 | cut -c1-220 > "$OUT/logcat_openvpn.txt"
log "RESULT: $PASS passed, $FAIL failed"
exit 0
