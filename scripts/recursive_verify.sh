#!/bin/bash
PACKAGE_NAME="com.iml1s.termux_flutter_ide"
DEVICE_ID=$(adb devices | grep -v "List" | head -1 | awk '{print $1}')
TMP_XML="/data/local/tmp/current_ui.xml"
LOCAL_XML="/tmp/current_ui.xml"

log() { echo "$(date): $1"; }

tap_node() {
    local text=$1
    log "Searching for '$text'..."
    adb -s "$DEVICE_ID" shell uiautomator dump $TMP_XML > /dev/null
    adb -s "$DEVICE_ID" pull $TMP_XML $LOCAL_XML > /dev/null
    
    # Try content-desc first, then text
    BOUNDS=$(grep -o "content-desc=\"[^\"]*${text}[^\"]*\" [^>]*bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"" $LOCAL_XML | head -1 | grep -o "bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"")
    if [ -z "$BOUNDS" ]; then
        BOUNDS=$(grep -o "text=\"[^\"]*${text}[^\"]*\" [^>]*bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"" $LOCAL_XML | head -1 | grep -o "bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"")
    fi

    if [ -n "$BOUNDS" ]; then
        COORDS=$(echo $BOUNDS | sed 's/bounds=\"\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]\"/\1 \2 \3 \4/')
        read X1 Y1 X2 Y2 <<< $COORDS
        X=$(( (X1 + X2) / 2 ))
        Y=$(( (Y1 + Y2) / 2 ))
        log "Found '$text' at $X $Y. Tapping..."
        adb -s "$DEVICE_ID" shell input tap $X $Y
        sleep 3
        return 0
    else
        log "FAILED to find '$text'"
        return 1
    fi
}

log "Force stopping app and clearing logs..."
adb -s "$DEVICE_ID" shell am force-stop $PACKAGE_NAME
adb -s "$DEVICE_ID" logcat -c

log "Starting IDE..."
adb -s "$DEVICE_ID" shell am start -n $PACKAGE_NAME/.MainActivity
sleep 10

# Step 1: Open project folder
# Many times the 'Open Project Folder' is a button in the middle
if ! tap_node "Open Project Folder"; then
    log "Fallback: opening drawer first..."
    adb -s "$DEVICE_ID" shell input tap 80 154 # Hamburger
    sleep 2
    tap_node "Open Folder"
fi

# Step 2: Select a folder in the browser
log "In directory browser. Looking for 'Select This Folder'..."
# Tapping a random spot where folders might be to ensure directory provider updates
adb -s "$DEVICE_ID" shell input tap 540 800
sleep 1
tap_node "Select This Folder"

# Step 3: Run project
log "Back in editor. Tapping Run button in header..."
# Header Run button often has content-desc "Run" or similar, or just coordinates
if ! tap_node "Run Project"; then
    log "Fallback: Header Play icon..."
    adb -s "$DEVICE_ID" shell input tap 742 153
fi

sleep 3

# Step 4: Click the BIG play button in the runner widget
log "Looking for Play triangle in Debug Console..."
# In FlutterRunnerWidget, we have Icons.play_arrow
# It might not have text, but let's try to find 'Run' tooltip
if ! tap_node "Run"; then
    log "Could not find 'Run' text. Tapping center-top area of BottomSheet..."
    # BottomSheet is likely from 480 to 2400. Toolbar is at the top.
    adb -s "$DEVICE_ID" shell input tap 700 550
fi

log "Waiting for log production..."
sleep 15

log "CAPTURING FINAL LOGS..."
adb logcat -d | grep "TerminalSession: _executeCommand" | tail -n 5 > /tmp/final_proof_logs.txt
log "Logs saved. Result:"
cat /tmp/final_proof_logs.txt
