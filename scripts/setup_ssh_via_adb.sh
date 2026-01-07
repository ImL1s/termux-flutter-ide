#!/bin/bash
# 通過 ADB 直接設置 Termux SSH

DEVICE_ID="RFCNC0WNT9H"

echo "🔧 Setting up Termux SSH via ADB..."

# Base64 encode the setup command to avoid shell escaping issues
SETUP_CMD='pkg install -y openssh 2>/dev/null || apt-get install -y openssh 2>/dev/null; SSHD_CONFIG="$PREFIX/etc/ssh/sshd_config"; if [ -f "$SSHD_CONFIG" ]; then sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication yes/" "$SSHD_CONFIG" 2>/dev/null || true; grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"; fi; printf "termux\ntermux\n" | passwd 2>/dev/null || true; ssh-keygen -A 2>/dev/null || true; pkill sshd 2>/dev/null; sleep 1; sshd && (sleep 1; ss -tlnp 2>/dev/null | grep -q ":8022" && echo "SSHD_STARTED=SUCCESS" || echo "SSHD_STARTED=FAILED")'

ENCODED_CMD=$(echo -n "$SETUP_CMD" | base64)

echo "📤 Sending RUN_COMMAND intent to Termux..."

adb -s "$DEVICE_ID" shell am start \
  --user 0 \
  -n com.termux/.app.TermuxActivity \
  -a com.termux.RUN_COMMAND \
  --es com.termux.RUN_COMMAND_PATH "/data/data/com.termux/files/usr/bin/sh" \
  --esa com.termux.RUN_COMMAND_ARGUMENTS "-c,$ENCODED_CMD" \
  --ez com.termux.RUN_COMMAND_BACKGROUND "true"

echo "✅ Setup command sent!"
echo "⏳ Waiting 10 seconds for setup to complete..."
sleep 10

echo ""
echo "🔍 Verifying setup..."

# Check if sshd is running
SSHD_CHECK=$(adb -s "$DEVICE_ID" shell run-as com.termux sh -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PREFIX/bin/applets:$PATH
pgrep sshd
' 2>&1)

if [ -n "$SSHD_CHECK" ] && [ "$SSHD_CHECK" != "unsupported shell: \"-zsh\"" ]; then
  echo "✅ sshd is running (PID: $SSHD_CHECK)"
else
  echo "❌ sshd is not running"
fi

echo ""
echo "🎉 Setup complete! Try running:"
echo "   dart run scripts/test_ssh_pure.dart"
