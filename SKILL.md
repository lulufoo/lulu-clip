---
name: lulu-clip
description: >-
  Capture a macOS screen region for the current conversation.
  Use when: lulu-clip, screenshot, capture a region, clip a window, capture OpenCode,
  look at a running app UI.
---

# lulu-clip

Arm ⌘E so the user can drag-select a region. Read the PNG the LuluClip listen process writes.

## Bind

`$SKILL_DIR` = `~/.agents/skills/lulu-clip`

Grant **Screen & System Audio Recording** to **LuluClip** only.

If listen is down, run `$SKILL_DIR/scripts/install-listen.sh`.

## Capture

You do not launch capture. The user enters it with **⌘E**.

1. `touch "$HOME/.cache/lulu-clip/arm"`
2. Say: Press ⌘E, then drag to select a region.
3. `$SKILL_DIR/scripts/wait-png.sh` — polls the cache about once a second. Prints the new PNG path and exits 0. If this attempt is cancelled, exits 3. Block until it exits. Do not vacant-sleep. Do not AwaitShell with no command.
4. `Read` that path.

If the script exits 2 (`NO_NEW_FILE`), `rm -f "$HOME/.cache/lulu-clip/arm"` and stop.
If the script exits 3 (`CANCELLED`), stop.

Listen enables **⌘E** only while that `arm` file exists. After the key fires, listen deletes `arm`.

## After capture

Describe what you see. Do not paste the image. Do not open Preview.

## Out of scope

Named-window capture, Accessibility tree, clicks, tab switching, Cursor-embedded terminals, non-macOS.
