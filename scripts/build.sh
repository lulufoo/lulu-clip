#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift build -c release --package-path "$ROOT"
rm -rf "$ROOT/bin/LuluClipListen.app" "$ROOT/bin/lulu-clip"
mkdir -p "$ROOT/bin/LuluClip.app/Contents/MacOS"
rm -f "$ROOT/bin/LuluClip.app/Contents/MacOS/lulu-clip"
cp "$ROOT/.build/release/lulu-clip" "$ROOT/bin/LuluClip.app/Contents/MacOS/LuluClip"
cat > "$ROOT/bin/LuluClip.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>LuluClip</string>
  <key>CFBundleExecutable</key>
  <string>LuluClip</string>
  <key>CFBundleIdentifier</key>
  <string>com.lulu.clip.listen</string>
  <key>CFBundleName</key>
  <string>LuluClip</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>LuluClip captures a screen region for the current chat.</string>
</dict>
</plist>
EOF
codesign --force --sign - --identifier com.lulu.clip.listen \
  --requirements '=designated => identifier "com.lulu.clip.listen"' \
  --deep "$ROOT/bin/LuluClip.app"
codesign -d --requirements - "$ROOT/bin/LuluClip.app"
ln -sfn "LuluClip.app/Contents/MacOS/LuluClip" "$ROOT/bin/lulu-clip"
echo "$ROOT/bin/lulu-clip"
