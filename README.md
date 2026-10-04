<h1 align="center">Lulu Clip</h1>

<p align="center"><b>Clip a macOS screen region for the agent. Press ⌘E, then drag.</b></p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License" align="absmiddle"></a>
</p>

---

The agent stays in the current chat. It arms **⌘E**. You press it and drag. LuluClip writes a PNG. Grant **Screen & System Audio Recording** to **LuluClip** only.

## Quick start

```bash
git clone https://github.com/lulufoo/lulu-clip.git ~/.agents/skills/lulu-clip
scripts/install-listen.sh
```

Grant **Screen & System Audio Recording** to **LuluClip**. Then in chat:

```text
/lulu-clip
```

Press **⌘E** and drag. After capture, ⌘E is released.

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
