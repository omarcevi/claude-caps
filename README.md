# goygoy 🫡

Turkish meme reactions for Claude Code. Give Claude a task and it answers
**"Başımla beraber abi!"** — out loud, or in its own reply.

## Install

```
/plugin marketplace add ~/Documents/Programming/claude_caps
/plugin install goygoy@claude-caps
```

Then drop the clip at `sounds/basimla-beraber-abi.mp3`. Until it's there,
the phrase is spoken with the built-in Turkish voice (Yelda).

## Use

| Command | What it does |
|---|---|
| `/goygoy:sus` | Mute: Claude starts its reply with the phrase instead |
| `/goygoy:konus` | Sound on (default) |

`GOYGOY_MODE=text` or `GOYGOY_MODE=sound` in the environment overrides the saved mode for that session.

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
A new event (e.g. `Stop`) also needs an entry in `hooks/hooks.json`. Run `/reload-plugins` after changes.

## Test

```
./tests/test_goygoy.sh
```
