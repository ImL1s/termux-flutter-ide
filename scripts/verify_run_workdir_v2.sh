#!/bin/bash
PACKAGE_NAME="com.iml1s.termux_flutter_ide"
DEVICE_ID=$(adb devices | grep -v "List" | head -1 | awk '{print $1}')

log() { echo "$(date): $1"; }
tap() { adb -s "$DEVICE_ID" shell input tap $1 $2; sleep 2; }

log "Clearing logcat..."
adb -s "$DEVICE_ID" logcat -c

log "Launching IDE..."
adb -s "$DEVICE_ID" shell am force-stop $PACKAGE_NAME
adb -s "$DEVICE_ID" shell am start -n $PACKAGE_NAME/.MainActivity
sleep 8

log "Opening Drawer..."
tap 80 150 # Hamburger button

log "Navigating to Open Folder in drawer..."
# Find 'Open Folder' in drawer
adb -s "$DEVICE_ID" shell uiautomator dump /data/local/tmp/ui_drawer.xml
adb pull /data/local/tmp/ui_drawer.xml /tmp/ui_drawer.xml
BOUNDS=$(grep "Open Folder" /tmp/ui_drawer.xml | grep -o 'bounds="\[[^]]*\]\[[^]]*\]"' | head -1)
if [ -n "$BOUNDS" ]; then
    COORDS=$(echo $BOUNDS | sed 's/bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]"/\1 \2 \3 \4/')
    read X1 Y1 X2 Y2 <<< $COORDS
    tap $(( (X1 + X2) / 2 )) $(( (Y1 + Y2) / 2 ))
else
    tap 280 970 # Fallback for Open Folder
fi
sleep 3

log "Selecting testapp..."
# Select project (fallback to current dir if not found)
tap 540 2200 # Select button coordinate
sleep 5

log "Opening Drawer again to click Run Project..."
tap 80 150
sleep 2

log "Clicking 'Run Project' in drawer..."
adb -s "$DEVICE_ID" shell uiautomator dump /data/local/tmp/ui_drawer_run.xml
adb pull /data/local/tmp/ui_drawer_run.xml /tmp/ui_drawer_run.xml
BOUNDS=$(grep "Run Project" /tmp/ui_drawer_run.xml | grep -o 'bounds="\[[^]]*\]\[[^]]*\]"' | head -1)
if [ -n "$BOUNDS" ]; then
    COORDS=$(echo $BOUNDS | sed 's/bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]"/\1 \2 \3 \4/')
    read X1 Y1 X2 Y2 <<< $COORDS
    tap $(( (X1 + X2) / 2 )) $(( (Y1 + Y2) / 2 ))
else
    tap 280 1280 # Fallback for Run Project
fi
sleep 5

log "Clicking PLAY button in FlutterRunnerWidget..."
# The Play button is in the toolbar of the bottom sheet.
# Let's dump UI to find it.
adb -s "$DEVICE_ID" shell uiautomator dump /data/local/tmp/ui_runner.xml
adb pull /data/local/tmp/ui_runner.xml /tmp/ui_runner.xml
# The Play button usually doesn't have text, but maybe 'Run' tooltip or icon resource.
# Coordinate 720 1200 is a rough guess for center of bottom sheet toolbar Play button if it's there.
# Let's try to tap where it was in the user screenshot.
tap 700 1250 

log "Waiting for output..."
sleep 20

log "Capturing final result..."
adb shell screencap -p /data/local/tmp/final_run_result.png
adb pull /data/local/tmp/final_run_result.png /tmp/final_run_result.png
log "Final result saved to /tmp/final_run_result.png"

adb logcat -d > /tmp/final_logs.txt
grep -A 10 "FlutterRunnerService: Starting run" /tmp/final_logs.txt > /tmp/filtered_logs.txt
