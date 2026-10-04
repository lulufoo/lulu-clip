#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/bin/LuluClip.app/Contents/MacOS/LuluClip"
if [[ ! -x $BIN ]]; then
  "$ROOT/scripts/build.sh"
fi
LABEL="com.lulu.clip.listen"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.cache/lulu-clip"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-W</string>
    <string>-a</string>
    <string>${ROOT}/bin/LuluClip.app</string>
    <string>--args</string>
    <string>listen</string>
    <string>--out</string>
    <string>${HOME}/.cache/lulu-clip</string>
  </array>
  <key>AssociatedBundleIdentifiers</key>
  <array>
    <string>com.lulu.clip.listen</string>
  </array>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardOutPath</key>
  <string>${HOME}/.cache/lulu-clip/listen.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/.cache/lulu-clip/listen.stderr.log</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
pkill -f 'LuluClip listen' 2>/dev/null || true
pkill -f 'lulu-clip listen' 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "hotkey cmd+e  →  $HOME/.cache/lulu-clip"
