#!/usr/bin/env bash
# Runs on the emulator (called by android-emulator-runner). Never fails the job: results go to /tmp files.
set +e
PKG=$(grep -oE 'applicationId *= *"[^"]+"|applicationId +"[^"]+"' android/app/build.gradle* | grep -oE '"[^"]+"' | tr -d '"' | head -1)
echo "package: $PKG" | tee /tmp/e2e_meta.txt
mkdir -p screenshots

echo "== phase 1: release APK launch test" | tee -a /tmp/e2e_meta.txt
adb uninstall "$PKG" >/dev/null 2>&1
adb install -r /tmp/app-x64-release.apk 2>&1 | tee -a /tmp/e2e_meta.txt
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 9
adb exec-out screencap -p > screenshots/r1_release_after_9s.png
echo "release pid: $(adb shell pidof "$PKG")" | tee -a /tmp/e2e_meta.txt
adb logcat -d > /tmp/logcat_release.txt
grep -c "FATAL EXCEPTION" /tmp/logcat_release.txt | sed 's/^/release FATAL count: /' | tee -a /tmp/e2e_meta.txt
sleep 6
adb exec-out screencap -p > screenshots/r2_release_after_15s.png
adb shell dumpsys gfxinfo "$PKG" | grep -E "Total frames|Janky frames|50th|90th|95th|99th" | tee -a /tmp/e2e_meta.txt
adb shell am force-stop "$PKG"
adb uninstall "$PKG" >/dev/null 2>&1

echo "== phase 2: UI walkthrough (flutter drive, debug mode)" | tee -a /tmp/e2e_meta.txt
adb logcat -c
flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/walkthrough_test.dart -d emulator-5554 --debug 2>&1 | tee /tmp/e2e.txt
adb logcat -d > /tmp/logcat_walkthrough.txt
adb exec-out screencap -p > screenshots/zz_final_state.png
echo "script done" | tee -a /tmp/e2e_meta.txt
exit 0
