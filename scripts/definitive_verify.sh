#!/bin/bash
PACKAGE_NAME="com.iml1s.termux_flutter_ide"
DEVICE_ID=$(adb devices | grep -v "List" | head -1 | awk '{print $1}')

log() { echo "$(date): $1"; }
tap() { adb -s "$DEVICE_ID" shell input tap $1 $2; sleep 3; }

log "Stopping app and clearing logs..."
adb -s "$DEVICE_ID" shell am force-stop $PACKAGE_NAME
adb -s "$DEVICE_ID" logcat -c

log "Starting IDE..."
adb -s "$DEVICE_ID" shell am start -n $PACKAGE_NAME/.MainActivity
sleep 10

log "Step 1: Tapping center 'Open Project Folder'..."
tap 540 1450 # Opens drawer

log "Step 2: Tapping 'Open Folder' in drawer..."
tap 427 1236 # Opens directory browser

log "Step 3: Tapping a folder item and then Select..."
tap 540 800 # Click likely folder item
sleep 1
tap 540 2250 # Select Folder button at bottom
sleep 5

log "Step 4: Tapping top header Run icon..."
tap 742 153 # Header Run button
sleep 5

log "Step 5: Tapping PLAY button inside Runner BottomSheet..."
# Assuming bottom sheet is at 80% height, top toolbar is around 1200-1300 Y
# Based on user image, toolbar is near the top of the sheet.
# Let's try to tap the green Play icon in the Runner toolbar.
# Coordinate from user screenshot guess: near 700 1350
tap 700 1350
sleep 15

log "Capturing screenshots and logs..."
adb shell screencap -p /data/local/tmp/proof.png
adb pull /data/local/tmp/proof.png /tmp/proof.png
adb logcat -d | grep "FlutterRunnerService\|TerminalSession" > /tmp/proof_logs.txt

log "Verification complete."
cat /tmp/proof_logs.txt
