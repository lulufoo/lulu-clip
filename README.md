<h1 align="center">Lulu Clip</h1>

<p align="center"><b>Improve collaboration efficiency: faster clarification, faster context injection.</b></p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License" align="absmiddle"></a>
</p>

---

When working with an agent, the critical context is often outside the current conversation. For some problems and situations, explaining them in words is both inefficient and laborious. Lulu Clip improves collaboration efficiency: it assists problem clarification, and it injects context more efficiently.

## Quick start

```bash
git clone https://github.com/lulufoo/lulu-clip.git ~/.agents/skills/lulu-clip
scripts/install-listen.sh
```

Grant **Screen & System Audio Recording** to **LuluClip**. Then in chat:

```text
/lulu-clip
```

The agent stays in the current chat and arms **⌘E**. Press it and drag a region on the live screen. The region locks into an edit step: draw lines (L) or boxes (B) on top of the live screen, with pixel measurements; Shift snaps horizontal/vertical (square for boxes); ⌘Z undoes. Press Enter or click 完成 to capture the region with your marks; Esc/取消 cancels. LuluClip writes a PNG only on Done (`.png.part`, then rename). While editing, `listen.log` gets `edit begin` and `wait-png.sh` stops its timeout. After capture, ⌘E is released.

LuluClip also lives in the menu bar (viewfinder icon): **⌘⇧E** or 截图 starts a capture any time, without an agent. Done saves the PNG to the out dir and copies it to the clipboard; Esc just closes. 打开截图文件夹 opens the out dir. Grant the permission to **LuluClip** only.

## Skill

Chat entry is `lulu-clip`. The skill only arms the hotkey and reads the PNG.

```text
SKILL.md
bin/lulu-clip
Sources/
```

## Develop

```bash
swift test
scripts/build.sh
scripts/install-listen.sh
```

## License

- Project: [MIT](./LICENSE)
