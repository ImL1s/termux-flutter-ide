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
sleep 6

# Ensure drawer is closed (tap right side of screen)
log "Ensuring drawer is closed..."
tap 1000 1200

log "Tapping 'Open Project Folder'..."
tap 540 1450 # Center of the big button

log "Navigating to /data/data/com.termux/files/home/testapp..."
adb -s "$DEVICE_ID" shell uiautomator dump /data/local/tmp/ui_browser.xml
adb pull /data/local/tmp/ui_browser.xml /tmp/ui_browser.xml

# Look for 'testapp' node
BOUNDS=$(grep "testapp" /tmp/ui_browser.xml | grep -o 'bounds="\[[^]]*\]\[[^]]*\]"' | head -1)
if [ -n "$BOUNDS" ]; then
    log "Found 'testapp' at $BOUNDS"
    COORDS=$(echo $BOUNDS | sed 's/bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]"/\1 \2 \3 \4/')
    read X1 Y1 X2 Y2 <<< $COORDS
    X=$(( (X1 + X2) / 2 ))
    Y=$(( (Y1 + Y2) / 2 ))
    tap $X $Y
    sleep 2
    
    log "Tapping 'Select Folder' fallback coordinate 540 2200..."
    tap 540 2200 
else
    log "Could not find 'testapp' in current list. Tapping fallback 540 2200 to select current dir."
    tap 540 2200
fi

sleep 4

log "Tapping 'Run' button (the play arrow in header)..."
# Coordinate from previous dump was [675,86][810,221] -> 742, 153
tap 742 153

log "Waiting for output in Debug Console..."
sleep 15
adb shell screencap -p /data/local/tmp/run_result_v2.png
adb pull /data/local/tmp/run_result_v2.png /tmp/run_result_v2.png
log "Result saved to /tmp/run_result_v2.png"

log "Dumping logs for verify..."
adb logcat -d | grep -A 5 "FlutterRunnerService: Starting run" > /tmp/run_logs_v2.txt
