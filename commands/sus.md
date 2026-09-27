---
description: Mute goygoy — Claude says the meme instead of playing a sound
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/mode.sh:*)"]
disable-model-invocation: true
---

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/mode.sh" text
```

Reply with the output above, verbatim, and nothing else.
