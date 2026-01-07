#!/data/data/com.termux/files/usr/bin/bash
echo "=== SSH SHELL DIAGNOSTIC ==="
echo "USER: $USER"
echo "HOME: $HOME"
echo "PATH: $PATH"
echo "SHELL: $SHELL"
echo "PWD: $(pwd)"
echo "--- COMMAND CHECKS ---"
for cmd in pkg bash curl git tar ls; do
  which $cmd || echo "$cmd NOT FOUND"
done
echo "--- TERMUX PREFIX ---"
ls -d /data/data/com.termux/files/usr/bin
echo "============================"
