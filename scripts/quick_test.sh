#!/bin/bash

# Quick UI Test - Minimal version for rapid testing
# Usage: ./scripts/quick_test.sh

DEVICE_ID="${DEVICE_ID:-RFCNC0WNT9H}"
PACKAGE="com.iml1s.termux_flutter_ide"

echo "🚀 Quick IDE Test Starting..."

# Launch IDE
echo "📱 Launching IDE..."
adb -s "$DEVICE_ID" shell am force-stop "$PACKAGE" 2>/dev/null
adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 2>/dev/null
sleep 3

# Take screenshot
echo "📸 Capturing screenshot..."
adb -s "$DEVICE_ID" exec-out screencap -p > /tmp/ide_quick_test.png 2>/dev/null

# Check if running
if adb -s "$DEVICE_ID" shell "ps | grep $PACKAGE" 2>/dev/null | grep -q "$PACKAGE"; then
    echo "✅ IDE is running"
    echo "📸 Screenshot saved: /tmp/ide_quick_test.png"
    open /tmp/ide_quick_test.png 2>/dev/null || echo "View screenshot at: /tmp/ide_quick_test.png"
else
    echo "❌ IDE failed to launch"
    exit 1
fi

echo "✨ Quick test completed!"
