#!/usr/bin/env bash
# End-to-end test on an Android emulator. Always exits 0 so artifacts get published; read report.txt.
set -u
PKG=com.example.alone_vpn
OUT=/tmp/emu; mkdir -p "$OUT/shots"; : > "$OUT/report.txt"
PASS=0; FAIL=0
log()  { echo "[$(date +%T)] $*" | tee -a "$OUT/report.txt"; }
check(){ if eval "$2"; then log "PASS  $1"; PASS=$((PASS+1)); else log "FAIL  $1"; FAIL=$((FAIL+1)); fi; }
shot() { adb exec-out screencap -p > "$OUT/shots/$1.png" 2>/dev/null; }
launch(){ adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }
waitlog(){ # pattern timeout
  for _ in $(seq 1 "$2"); do adb logcat -d 2>/dev/null | grep -q "$1" && return 0; sleep 1; done; return 1; }

log "device: Android $(adb shell getprop ro.build.version.release | tr -d '\r') / SDK $(adb shell getprop ro.build.version.sdk | tr -d '\r') / $(adb shell getprop ro.product.cpu.abi | tr -d '\r')"

# ---------- A. plain release build, fresh install ----------
check "release APK installs" "adb install -r apks/alone-x64.apk >/dev/null 2>&1"
adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
adb logcat -c; launch
sleep 3;  shot 01_launch_3s
sleep 6;  shot 02_launch_9s
check "app process is alive after 9s" "adb shell pidof $PKG | grep -q ."
check "no FATAL EXCEPTION on cold start" "! adb logcat -d | grep -q 'FATAL EXCEPTION'"
check "no native library load error" "! adb logcat -d | grep -qi 'UnsatisfiedLinkError\|dlopen failed'"
adb logcat -d | grep -i "flutter" | head -40 > "$OUT/flutter_startup.txt"
adb shell dumpsys meminfo "$PKG" 2>/dev/null | grep -E "TOTAL PSS|TOTAL  " | head -2 | tee -a "$OUT/report.txt"
adb shell am force-stop "$PKG"

# ---------- B. self-test build: real VPN through the engine ----------
check "self-test APK installs (same signing key)" "adb install -r apks/alone-x64-selftest.apk >/dev/null 2>&1"
adb shell pm clear "$PKG" >/dev/null 2>&1
adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
adb shell appops set "$PKG" ACTIVATE_VPN allow >/dev/null 2>&1
adb logcat -c; launch
sleep 6;  shot 03_home_idle
check "self-test reaches CONNECTING" "waitlog 'SELFTEST: CONNECTING' 60"
sleep 2;  shot 04_connecting
if waitlog 'SELFTEST: CONNECTED' 120; then
  log "PASS  VPN connected through the real engine"; PASS=$((PASS+1))
  sleep 3; shot 05_connected
  check "tun interface exists" "adb shell ip addr | grep -q 'tun'"
  # traffic must go through the proxy: HTTP request from the shell uid (not excluded from the VPN)
  REQ="printf 'GET / HTTP/1.0\\r\\nHost: example.com\\r\\n\\r\\n' | nc -w 10 example.com 80 | head -1"
  RESP=$(adb shell "$REQ" 2>/dev/null | tr -d '\r')
  log "HTTP via VPN -> '$RESP'"
  check "HTTP request works through the VPN" "echo '$RESP' | grep -q 'HTTP/1'"
  check "the proxy server saw the request (traffic really tunnelled)" "grep -q 'example.com' /tmp/xray-access.log"
  # rough throughput through the tunnel (5 MB download)
  T0=$(date +%s.%N)
  BYTES=$(adb shell "printf 'GET /__down?bytes=5000000 HTTP/1.0\\r\\nHost: speed.cloudflare.com\\r\\n\\r\\n' | nc -w 25 speed.cloudflare.com 80 | wc -c" 2>/dev/null | tr -d '\r ')
  T1=$(date +%s.%N)
  MBPS=$(python3 -c "print(round(${BYTES:-0}*8/1e6/max(0.1,$T1-$T0),1))" 2>/dev/null || echo 0)
  log "throughput via VPN: ${BYTES:-0} bytes in $(python3 -c "print(round($T1-$T0,1))")s = ${MBPS} Mbit/s (emulator + shared CI runner: indicative only)"
  check "download through the VPN completes (>=4 MB)" "[ \"${BYTES:-0}\" -ge 4000000 ]"
  adb shell dumpsys meminfo "$PKG" 2>/dev/null | grep -E "TOTAL PSS|TOTAL  " | head -2 | tee -a "$OUT/report.txt"
  check "no FATAL EXCEPTION while connected" "! adb logcat -d | grep -q 'FATAL EXCEPTION'"
  check "self-test disconnects cleanly" "waitlog 'SELFTEST: DISCONNECTED state=CS.off' 120"
  sleep 3; shot 06_disconnected
  check "tun interface removed after disconnect" "! adb shell ip addr | grep -q 'tun'"
  check "direct internet works again" "adb shell \"printf 'GET / HTTP/1.0\\r\\nHost: example.com\\r\\n\\r\\n' | nc -w 10 example.com 80 | head -1\" | grep -q 'HTTP/1'"
else
  log "FAIL  VPN did not connect: $(adb logcat -d | grep 'SELFTEST' | tail -3 | tr '\n' ' ')"; FAIL=$((FAIL+1))
  shot 05_not_connected
fi
adb logcat -d > "$OUT/logcat_full.txt" 2>/dev/null
adb logcat -d | grep -E "SELFTEST|FATAL EXCEPTION|AndroidRuntime|ALONE|v2ray|libbox|xray" | tail -150 > "$OUT/logcat_filtered.txt"
log "RESULT: $PASS passed, $FAIL failed"
exit 0
