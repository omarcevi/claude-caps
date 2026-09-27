# claude-caps — Turkish meme sounds for Claude Code

**Date:** 2026-09-27
**Status:** Approved design, pending spec review

## Goal

A joke Claude Code plugin that reacts to Claude Code events with Turkish social-media memes.
v1 ships exactly one meme: when the user hands Claude a task, it answers
**"Başımla beraber abi! 🫡"**. The design must make adding more memes a data-only change.

**Success looks like:** every prompt you submit triggers the meme (audio or Claude saying it),
Claude starts working with no noticeable delay, and a broken meme setup never breaks Claude Code.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Trigger for "task accepted" | `UserPromptSubmit` hook (fires on every submitted prompt) |
| Silent-mode behavior | Claude itself says the phrase (context injection), not a terminal banner |
| Audio source | User drops the clip into `sounds/`; macOS TTS (voice **Yelda**, `tr_TR`) is the fallback when the file is missing |
| Packaging | Claude Code plugin named `caps`, installable from this folder via a local marketplace |
| Default mode | `sound` |
| Modes | Exclusive: `sound` plays audio only; `text` makes Claude say it only |

## Layout

```
claude_caps/
├── .claude-plugin/
│   ├── plugin.json         # { "name": "caps", ... }
│   └── marketplace.json    # local marketplace "claude-caps", one plugin, source "./"
├── hooks/hooks.json        # UserPromptSubmit → bash "${CLAUDE_PLUGIN_ROOT}/scripts/caps.sh" UserPromptSubmit
├── commands/sound.md       # /caps:sound on | off | status
├── memes.json              # registry: hook event → array of memes
├── sounds/                 # audio clips (basimla-beraber-abi.mp3 supplied by the user)
├── scripts/caps.sh         # the engine (hook entry point)
├── scripts/mode.sh         # reads/writes the mode file (used by the slash command)
└── tests/test_caps.sh      # bash test suite
```

## Components

### `memes.json` — the registry

```json
{
  "UserPromptSubmit": [
    { "phrase": "Başımla beraber abi! 🫡", "sound": "basimla-beraber-abi.mp3" }
  ]
}
```

- Keys are Claude Code hook event names.
- Each value is an array; when it has more than one entry the engine picks one uniformly at random.
- `sound` is a filename relative to `sounds/`. It may be omitted, in which case sound mode always uses TTS.

### `scripts/caps.sh <EventName>` — the engine

1. Drain stdin (the hook's JSON payload; unused in v1).
2. Resolve the mode: `$CLAUDE_CAPS_MODE` if set to `sound`/`text`, else the content of
   `${XDG_CONFIG_HOME:-$HOME/.config}/claude-caps/mode`, else `sound`. Unknown values fall back to `sound`.
3. Pick a meme for `<EventName>` from `memes.json` with `jq`. No meme → exit 0, no output.
4. **sound mode**
   - If `sounds/<sound>` exists: `afplay <file> >/dev/null 2>&1 &`
   - Else: `say -v Yelda "<phrase>" >/dev/null 2>&1 &`
   - Print nothing, exit 0.
5. **text mode** — print exactly one JSON object and exit 0:
   ```json
   {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit",
     "additionalContext":"Start your reply with exactly \"Başımla beraber abi! 🫡\" on its own line, then continue normally."}}
   ```
   The JSON is built with `jq` so quoting/Unicode in phrases is always escaped correctly.

The audio child's stdout/stderr **must** be redirected: Claude Code waits for the hook's stdout pipe to close,
and a backgrounded player that inherits it would stall Claude for the clip's full length.

### `scripts/mode.sh [on|off|status]` + `commands/sound.md`

- `on` → writes `sound`; `off` → writes `text`; `status`/no arg → prints the current mode.
  Creates the config directory if needed. Prints a one-line confirmation, e.g. `caps: sound ON 🔊`.
- `commands/sound.md` runs it through a ```` ```! ```` block with `$ARGUMENTS`, with
  `allowed-tools` restricted to that one script (same pattern as the installed `ralph-loop` plugin).

### `hooks/hooks.json`

One `UserPromptSubmit` entry, no matcher, `"timeout": 5`.

## Error handling

The plugin is a joke; it must never interfere with real work. Every failure path in `caps.sh` exits 0 with
no stdout: missing `jq`, missing `afplay`/`say`, missing or malformed `memes.json`, event with no memes,
unreadable mode file. Stderr is silenced so nothing leaks into the transcript.

## Testing

`tests/test_caps.sh` (plain bash, no framework). Fake `afplay` and `say` executables are placed first on
`PATH`; they append their arguments to a log file. Cases:

1. sound mode + clip present → `afplay` called with the clip path; no stdout.
2. sound mode + clip missing → `say -v Yelda` called with the phrase; no stdout.
3. text mode → stdout is valid JSON; `.hookSpecificOutput.additionalContext` contains the phrase.
4. Non-blocking: fake player sleeps 3s; the hook must return in under 1s.
5. Event with no memes → exit 0, no stdout, no player call.
6. Malformed `memes.json` → exit 0, no stdout.
7. `mode.sh off` then `status` → reports `text`; `on` → `sound`; env var overrides the file.

Then a live check: `claude --plugin-dir .` and submit a prompt in each mode.

## Install (user-facing)

```
/plugin marketplace add ~/Documents/Programming/claude_caps
/plugin install caps@claude-caps
```
Drop the clip at `sounds/basimla-beraber-abi.mp3`. Toggle with `/caps:sound off` / `/caps:sound on`.
After editing hooks or the registry, run `/reload-plugins` (or restart the session).

## Out of scope for v1

- More memes and events (e.g. `Stop` → "task done" meme). Note: text mode relies on `additionalContext`,
  which `Stop` does not support — that event will need a different silent-mode path when added.
- Preventing overlapping playback on rapid prompts.
- Linux/Windows audio players.
