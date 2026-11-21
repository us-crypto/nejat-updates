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

# Open the "من" (profile) tab and take a picture of it, if the app is still open.
tap_text() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 && adb pull /sdcard/ui.xml "$OUT/ui.xml" >/dev/null 2>&1 || return 1
  python3 - "$OUT/ui.xml" "$1" > "$OUT/tap.txt" <<'PY'
import re, sys
xml = open(sys.argv[1], encoding="utf-8").read()
for m in re.finditer(r'<node [^>]*>', xml):
    n = m.group(0)
    t = re.search(r' text="([^"]*)"', n); d = re.search(r' content-desc="([^"]*)"', n)
    if sys.argv[2] in ((t.group(1) if t else ""), (d.group(1) if d else "")) or (d and d.group(1).startswith(sys.argv[2] + ",")):
        x1, y1, x2, y2 = map(int, re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n).groups())
        print((x1 + x2) // 2, (y1 + y2) // 2); break
PY
  read -r x y < "$OUT/tap.txt" || return 1
  adb shell input tap "$x" "$y"
}
if [ -n "$(adb shell pidof "$PKG" | tr -d '\r')" ]; then
  tap_text "من" && sleep 8 && adb exec-out screencap -p > "$OUT/screen-profile.png"
  echo "profile tap: $(cat "$OUT/tap.txt" 2>/dev/null)" >> "$OUT/alive.txt"
  pid=$(adb shell pidof "$PKG" | tr -d '\r'); echo "after profile pid=${pid:-none}" >> "$OUT/alive.txt"
fi
adb logcat -b crash -d > "$OUT/crash.txt" 2>&1 || true
adb logcat -d -v time > "$OUT/logcat-full.txt" 2>&1
grep -E "AndroidRuntime|ReactNativeJS|FATAL|Expo|ReactNative|SoLoader|libc |DEBUG  |Unhandled|Exception|Error" "$OUT/logcat-full.txt" | grep -v "^--------- " | head -400 > "$OUT/logcat-important.txt"
cat "$OUT/alive.txt"
