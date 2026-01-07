#!/bin/bash
# Verify Open Folder Feature
# Automates testing of the "Open Folder" dialog

set -e

DEVICE_ID="${DEVICE_ID:-RFCNC0WNT9H}"
PACKAGE_NAME="com.iml1s.termux_flutter_ide"
SCREENSHOT_DIR="/tmp/ide_verify_open_folder"
LOG_FILE="/tmp/verify_open_folder.log"

mkdir -p "$SCREENSHOT_DIR"
echo "$(date): Starting Open Folder Verification" > "$LOG_FILE"

log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

take_screenshot() {
    local name=$1
    adb -s "$DEVICE_ID" exec-out screencap -p > "${SCREENSHOT_DIR}/${name}.png"
    log "Screenshot saved: ${SCREENSHOT_DIR}/${name}.png"
}

tap() {
    local x=$1
    local y=$2
    local label=$3
    log "Tapping $label ($x, $y)..."
    adb -s "$DEVICE_ID" shell input tap $x $y
}

# 1. Wake up device
log "Waking up device..."
adb -s "$DEVICE_ID" shell input keyevent KEYCODE_WAKEUP
adb -s "$DEVICE_ID" shell input keyevent 82
sleep 2

# 2. Build and Install
log "Building APK..."
fvm flutter build apk --debug

log "Installing APK..."
adb -s "$DEVICE_ID" install -r build/app/outputs/flutter-apk/app-debug.apk

# 3. Launch App
log "Launching IDE..."
adb -s "$DEVICE_ID" shell "am force-stop $PACKAGE_NAME"
sleep 1
adb -s "$DEVICE_ID" shell "monkey -p $PACKAGE_NAME -c android.intent.category.LAUNCHER 1"
sleep 5

take_screenshot "01_launched"

# 3. Open Drawer (via Center Button or Swipe)
log "Tapping Center Button to open drawer..."
tap 540 1200 "Center Button"
sleep 1

# 4. Tap 'Open Folder' in Drawer
# Coordinates from test_ide_ui.sh for 'Open Folder' in drawer
log "Tapping 'Open Folder' in drawer..."
tap 280 967 "Open Folder"
sleep 2

# 5. Verify Dialog Appears
log "Searching for 'Select Project Folder' dialog..."

# Dump UI hierarchy
adb -s "$DEVICE_ID" shell uiautomator dump /data/local/tmp/ui.xml
adb -s "$DEVICE_ID" pull /data/local/tmp/ui.xml "${SCREENSHOT_DIR}/ui_dump.xml"

# Format: <node index="2" text="Open Folder" ... bounds="[357,1128][723,1260]" ... />
BOUNDS=$(grep "Open Folder" "${SCREENSHOT_DIR}/ui_dump.xml" | grep -o 'bounds="\[[^]]*\]\[[^]]*\]"' | head -1)

if [ -n "$BOUNDS" ]; then
    log "Found button bounds: $BOUNDS"
    # Parse center
    # [x1,y1][x2,y2]
    COORDS=$(echo $BOUNDS | sed 's/bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]"/\1 \2 \3 \4/')
    read x1 y1 x2 y2 <<< $COORDS
    
    CENTER_X=$(( (x1 + x2) / 2 ))
    CENTER_Y=$(( (y1 + y2) / 2 ))
    
    log "Tapping center: $CENTER_X $CENTER_Y"
    adb -s "$DEVICE_ID" shell input tap $CENTER_X $CENTER_Y
else
    log "Button not found via XML dump. Trying fallback coordinates (540 1200)"
    adb -s "$DEVICE_ID" shell input tap 540 1200
fi

sleep 2
take_screenshot "02_after_click"

# 3. Verify Dialog appears
# Look for "Select Project Folder" or similar text
adb -s "$DEVICE_ID" shell uiautomator dump /data/local/tmp/ui_dialog.xml
adb -s "$DEVICE_ID" pull /data/local/tmp/ui_dialog.xml "${SCREENSHOT_DIR}/ui_dialog.xml"

if grep -q "Select Project Folder" "${SCREENSHOT_DIR}/ui_dialog.xml"; then
    log "SUCCESS: 'Select Project Folder' dialog detected!"
    echo "VERIFICATION PASSED"
else
    log "FAIL: Dialog not detected."
    # Check for error snackbar
    if grep -q "Error" "${SCREENSHOT_DIR}/ui_dialog.xml"; then
        log "Error message detected in UI."
    fi
    echo "VERIFICATION FAILED"
fi
