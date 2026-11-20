#!/usr/bin/env bash
# Installs the APK on the emulator, opens it like a person would and records
# whether it stays open. Writes everything to phone-test/ for the report.
set -u
APK="$1"; PKG="ir.nejat.app"; OUT="phone-test"
mkdir -p "$OUT"
adb wait-for-device
adb shell getprop ro.build.version.release > "$OUT/android-version.txt"
adb shell getprop ro.product.cpu.abilist >> "$OUT/android-version.txt"
adb install -r -g "$APK" > "$OUT/install.txt" 2>&1; echo "install exit $?" >> "$OUT/install.txt"
adb logcat -c; adb logcat -b crash -c 2>/dev/null || true
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > "$OUT/launch.txt" 2>&1
for t in 5 10 20 35 50; do
  sleep $(( t == 5 ? 5 : (t == 10 ? 5 : (t == 20 ? 10 : 15)) ))
  pid=$(adb shell pidof "$PKG" | tr -d '\r')
  echo "${t}s pid=${pid:-none}" >> "$OUT/alive.txt"
  [ "$t" = 20 ] && adb exec-out screencap -p > "$OUT/screen-20s.png"
done
adb exec-out screencap -p > "$OUT/screen-50s.png"
adb logcat -b crash -d > "$OUT/crash.txt" 2>&1 || true
adb logcat -d -v time > "$OUT/logcat-full.txt" 2>&1
grep -E "AndroidRuntime|ReactNativeJS|FATAL|Expo|ReactNative|SoLoader|libc |DEBUG  |Unhandled|Exception|Error" "$OUT/logcat-full.txt" | grep -v "^--------- " | head -400 > "$OUT/logcat-important.txt"
cat "$OUT/alive.txt"
