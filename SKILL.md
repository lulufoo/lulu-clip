---
name: lulu-clip
description: >-
  Capture a macOS screen region for the current conversation.
  Use when: lulu-clip, screenshot, 截图, 截取, clip a window, capture OpenCode,
  look at a running app UI, 看一下这个软件的界面.
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
2. Say: 请按 ⌘E，拖动鼠标框选.
3. Wait for a new PNG under `$HOME/.cache/lulu-clip`.
4. `Read` that path.

If no new file appears, `rm -f "$HOME/.cache/lulu-clip/arm"` and stop.

Listen enables **⌘E** only while that `arm` file exists. After the key fires, listen deletes `arm`.

## After capture

Describe what you see. Do not paste the image. Do not open Preview.

## Out of scope

Named-window capture, Accessibility tree, clicks, tab switching, Cursor-embedded terminals, non-macOS.
