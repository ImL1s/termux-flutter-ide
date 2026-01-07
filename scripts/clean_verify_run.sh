#!/bin/bash
PACKAGE_NAME="com.iml1s.termux_flutter_ide"
DEVICE_ID=$(adb devices | grep -v "List" | head -1 | awk '{print $1}')
DIR="/tmp/ide_clean_test"
mkdir -p $DIR

log() { echo "$(date): $1"; }
snap() { 
    local name=$1
    adb -s "$DEVICE_ID" shell screencap -p /data/local/tmp/snap.png
    adb pull /data/local/tmp/snap.png "$DIR/$name.png"
    log "Screenshot saved: $DIR/$name.png"
}
tap() { adb -s "$DEVICE_ID" shell input tap $1 $2; sleep 3; }

log "Force stopping app and clearing logs..."
adb -s "$DEVICE_ID" shell am force-stop $PACKAGE_NAME
adb -s "$DEVICE_ID" logcat -c

log "Starting IDE..."
adb -s "$DEVICE_ID" shell am start -n $PACKAGE_NAME/.MainActivity
sleep 8
snap "01_start"

log "Tapping 'Open Project Folder' button..."
# [259,1387][821,1522] -> 540, 1454
tap 540 1454
snap "02_browser_opened"

log "Selecting whatever directory is present (tapping center of list)..."
# Tapping first item in directory browser (if any)
tap 540 600
sleep 2
snap "03_clicked_folder"

log "Tapping 'Select Folder' (bottom button)..."
# Tapping center bottom area where the select button usually resides in this layout
tap 540 2250 
sleep 5
snap "04_back_to_editor"

log "Tapping PLAY button in Header..."
# [675,86][810,221] -> 742, 153
tap 742 153
sleep 15
snap "05_run_triggered"

log "Fetching Logcat..."
adb logcat -d | grep "TerminalSession: _executeCommand" > "$DIR/run_command_log.txt"
log "Log saved to $DIR/run_command_log.txt"
cat "$DIR/run_command_log.txt"
