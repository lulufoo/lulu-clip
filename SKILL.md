---
name: lulu-clip
description: >-
  Capture a macOS screen region for the current conversation.
  Use when: lulu-clip, screenshot, capture a region, capture OpenCode,
  look at a running app UI.
---

# lulu-clip

The user selects a region with ⌘E. Done when that PNG is described.

## Setup

Install path and listen readiness.

1. `$SKILL_DIR` is `~/.agents/skills/lulu-clip`.
2. Grant **Screen & System Audio Recording** to **LuluClip** only.
3. If listen is down, run `$SKILL_DIR/scripts/install-listen.sh`.

## Capture

One region. Do not launch the picker. Do not `touch` `arm`.

1. Say: Press ⌘E, then drag to select a region.
2. Run `$SKILL_DIR/scripts/wait-png.sh` only. Block until it exits. Do not vacant-sleep. Do not AwaitShell with no command.
3. `Read` the path it prints.

## Failure

1. Exit 2 (`NO_NEW_FILE`) or 3 (`CANCELLED`): stop.

## After capture

1. Describe what you see.
2. Do not paste the image.
3. Do not open Preview.

## Out of scope

1. Named-window capture, Accessibility tree, clicks, tab switching, Cursor-embedded terminals, or non-macOS.
