# goygoy 🫡

Turkish meme reactions for Claude Code. Give Claude a task and it answers
**"Başımla beraber abi!"** — out loud, or in its own reply.

## Install

1. Put the clip at `sounds/basimla-beraber-abi.mp3` **before installing**. Installing copies
   the plugin into `~/.claude/plugins/cache/`, so files added later only arrive through an
   update (below). Without a clip, the phrase is spoken with the Turkish voice (Yelda).
2. In Claude Code:

   ```
   /plugin marketplace add ~/Documents/Programming/claude_caps
   /plugin install goygoy@claude-caps
   ```

   If the meme doesn't fire right away, restart Claude Code.

## Update after changing memes or clips

The installed copy only refreshes when the version changes:

1. Bump `"version"` in `.claude-plugin/plugin.json` (e.g. `0.1.0` → `0.1.1`).
2. Run:

   ```
   /plugin marketplace update claude-caps
   /plugin update goygoy@claude-caps
   ```

3. Restart Claude Code.

## Use

| Command | What it does |
|---|---|
| `/goygoy:sus` | Mute: Claude starts its reply with the phrase instead |
| `/goygoy:konus` | Sound on (default) |

`GOYGOY_MODE=text` or `GOYGOY_MODE=sound` in the environment overrides the saved mode for that session.

Headless runs (`claude -p`, Agent SDK) stay silent so scripts get clean output.
Set `GOYGOY_HEADLESS=1` to include them.

## Add a meme

Add an entry to `memes.json` under a hook event and put the clip in `sounds/`:

```json
{
  "UserPromptSubmit": [
    { "phrase": "Başımla beraber abi! 🫡", "sound": "basimla-beraber-abi.mp3" },
    { "phrase": "Another one for the same moment", "sound": "another.mp3" }
  ]
}
```

Several memes on one event are picked at random. `sound` is optional (TTS is used without it).
A new event (e.g. `Stop`) also needs an entry in `hooks/hooks.json`. Then follow
[Update after changing memes or clips](#update-after-changing-memes-or-clips).

## Test

```
./tests/test_goygoy.sh
```
