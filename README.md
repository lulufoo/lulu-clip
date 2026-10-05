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

The agent stays in the current chat and arms **⌘E**. Press it and drag a region. LuluClip writes a PNG. After capture, ⌘E is released. Grant the permission to **LuluClip** only.

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
